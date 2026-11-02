#!/usr/bin/env python3
"""Prototipo del protocolo del pipeline de 3 bots (Orquestador, Runero, Sniper).

No es el codigo final: valida el diseno (almacen con cupos atomicos, cola al-menos-una-vez con ids
idempotentes, transferencias en dos fases, pausas de VM al azar) contra los invariantes del documento.

Uso: python3 sim.py [--runs N] [--seed S] [--faults 0|1]
"""
import argparse
import random
from collections import Counter, defaultdict

FAMILIES = ["Angelic", "Armored", "Deathbringer", "Enlighted", "Life Essence", "Valor", "Tank", "Health Boost"]
PIECES = ["Helmet", "Chestplate", "Leggings", "Boots"]
FRAGS_PER_RUNE = 3          # botellas (fragmentos) de una familia para llegar a una runa al 100%
MAX_TICKS = 40_000


class Store:
    """Almacen externo. Cada metodo es una transaccion: en la version real, una funcion RPC en Postgres."""

    def __init__(self, rng, faults):
        self.rng, self.faults = rng, faults
        self.need = Counter()          # linea del BOM -> requerido
        self.applied = Counter()
        self.claims = {}               # id -> dict(line, qty, bought)
        self.bought = Counter()        # linea -> comprado (para el invariante)
        self.spend = 0
        self.budget = 0
        self.queue = []                # mensajes: dict(id, to, type, payload, vis)
        self.done_ids = defaultdict(set)
        self.index = defaultdict(Counter)   # cofre -> contenido segun el almacen
        self.intents = {}              # id -> (bot, src, dst, item, qty)
        self.next_id = 0
        self.rune_orders = {}          # id -> dict(fam, qty, made)

    def nid(self):
        self.next_id += 1
        return self.next_id

    # --- cupos de compra -------------------------------------------------------------------------
    def in_flight(self, line):
        c = sum(cl["qty"] - cl["bought"] for cl in self.claims.values() if cl["line"] == line)
        r = sum(o["qty"] - o["made"] for o in self.rune_orders.values() if o["fam"] == line)
        return c + r

    def deficit(self, line, stocked):
        return self.need[line] - self.applied[line] - stocked - self.in_flight(line)

    def open_claim(self, line, qty):
        cid = self.nid()
        self.claims[cid] = dict(line=line, qty=qty, bought=0)
        return cid

    def take_purchase(self, line, price):
        """Atomico: reserva 1 unidad de un cupo abierto de la linea. None si no hay cupo o plata."""
        if self.spend + price > self.budget:
            return None
        for cid, cl in self.claims.items():
            if cl["line"] == line and cl["bought"] < cl["qty"]:
                cl["bought"] += 1
                self.bought[line] += 1
                self.spend += price
                return cid
        return None

    # --- cola de mensajes --------------------------------------------------------------------------
    def send(self, to, typ, payload, now):
        m = dict(id=self.nid(), to=to, type=typ, payload=payload, vis=now)
        self.queue.append(m)
        if self.faults and self.rng.random() < 0.05:      # duplicado en la red
            self.queue.append(dict(m))

    def claim_msgs(self, to, now):
        out = []
        for m in self.queue:
            if m["to"] == to and m["vis"] <= now:
                m["vis"] = now + 60                        # en proceso: vuelve si no hay ack
                out.append(m)
        return out

    def ack(self, to, m):
        if self.faults and self.rng.random() < 0.05:       # ack perdido -> redelivery
            return
        self.queue = [q for q in self.queue if q is not m]

    # --- transferencias en dos fases -------------------------------------------------------------
    def intent(self, bot, src, dst, item, qty):
        iid = self.nid()
        self.intents[iid] = (bot, src, dst, item, qty)
        return iid

    def commit(self, iid, truth):
        bot, src, dst, item, qty = self.intents.pop(iid)
        for loc in (src, dst):
            self.index[loc] = Counter(truth[loc])


class World:
    """La verdad del server: cofres e inventarios."""

    def __init__(self):
        self.c = defaultdict(Counter)

    def move(self, src, dst, item, qty):
        assert self.c[src][item] >= qty, (src, item, qty)
        self.c[src][item] -= qty
        self.c[dst][item] += qty


class Bot:
    def __init__(self, name, store, world, rng, faults):
        self.name, self.s, self.w, self.rng, self.faults = name, store, world, rng, faults
        self.paused_until = 0
        self.pending = None            # (iid, src, dst, item, qty, fase) transferencia a medias
        self.inv = f"inv:{name}"
        self.blocked = 0

    def maybe_pause(self, now):
        if self.faults and self.rng.random() < 0.002:
            self.paused_until = now + self.rng.randint(50, 3000)
            return True
        return False

    def transfer(self, now, src, dst, item, qty):
        """Mueve en dos fases; puede cortarse (pausa) entre el movimiento y el commit."""
        iid = self.s.intent(self.name, src, dst, item, qty)
        self.w.move(src, dst, item, qty)
        if self.maybe_pause(now):
            self.pending = iid
            return
        self.s.commit(iid, self.w.c)

    def resume(self):
        # reconciliacion: toda intencion propia sin commit se resuelve mirando la verdad
        for iid, it in list(self.s.intents.items()):
            if it[0] == self.name:
                self.s.commit(iid, self.w.c)
        self.pending = None

    def step(self, now):
        if now < self.paused_until:
            return
        if self.pending is not None:
            self.resume()
        for m in self.s.claim_msgs(self.name, now):
            if m["id"] not in self.s.done_ids[self.name]:
                self.handle(m, now)
                self.s.done_ids[self.name].add(m["id"])
            self.s.ack(self.name, m)
        self.work(now)
        self.maybe_pause(now)

    def handle(self, m, now):
        pass

    def work(self, now):
        pass


class Orquestador(Bot):
    def stocked(self, line):
        # Lo que ya existe en CUALQUIER lugar segun el almacen, incluido el bolsillo de otro bot (sin esto,
        # lo comprado que el Sniper todavia no entrego no cuenta y se vuelve a comprar: lo encontro la sim).
        # Lo propio se mira en vivo; el resto, por el indice.
        idx = sum(c[line] for loc, c in self.s.index.items() if loc != self.inv)
        return idx + self.w.c[self.inv][line]

    def work(self, now):
        s = self.s
        # aplicar lo que haya: traer de los cofres de entrega y aplicar
        for loc in ("RUNES_OUT", "DELIVERY"):
            for item, q in list(s.index[loc].items()):
                real = self.w.c[loc][item]
                if q and real:
                    take = min(q, real, s.need[item] - s.applied[item])
                    if take > 0:
                        self.transfer(now, loc, self.inv, item, take)
                        return
        for item, q in list(self.w.c[self.inv].items()):
            if q and s.applied[item] < s.need[item]:
                self.w.c[self.inv][item] -= 1
                s.applied[item] += 1
                s.index[self.inv] = Counter(self.w.c[self.inv])   # aplicar tambien se anota
                return
        # abrir cupos / pedidos por lo que falta
        for line in s.need:
            d = s.deficit(line, self.stocked(line))
            if d <= 0:
                continue
            if line in PIECES:
                s.open_claim(line, d)
                s.send("sniper", "BUY_REQUEST", dict(line=line, qty=d), now)
            else:
                oid = s.nid()
                s.rune_orders[oid] = dict(fam=line, qty=d, made=0)
                s.send("runero", "RUNE_REQUEST", dict(order=oid), now)


class Runero(Bot):
    def __init__(self, *a):
        super().__init__(*a)
        self.orders = []
        self.asked_bottles = 0

    def handle(self, m, now):
        if m["type"] == "RUNE_REQUEST":
            self.orders.append(m["payload"]["order"])
        elif m["type"] == "DELIVERED":
            self.asked_bottles = max(0, self.asked_bottles - m["payload"]["qty"])

    def work(self, now):
        s, w = self.s, self.w
        open_orders = [o for o in self.orders if s.rune_orders[o]["made"] < s.rune_orders[o]["qty"]]
        if not open_orders:
            return
        # runa terminada en el inventario -> dejar en RUNES_OUT y marcar avance
        for o in open_orders:
            fam = s.rune_orders[o]["fam"]
            if w.c[self.inv][fam] > 0:
                self.transfer(now, self.inv, "RUNES_OUT", fam, 1)
                s.rune_orders[o]["made"] += 1
                s.send("orquestador", "RUNES_READY", dict(fam=fam), now)
                return
            if w.c[self.inv]["frag:" + fam] >= FRAGS_PER_RUNE:          # blend
                w.c[self.inv]["frag:" + fam] -= FRAGS_PER_RUNE
                w.c[self.inv][fam] += 1
                return
        if w.c[self.inv]["Bottle"] > 0:                                     # abrir botella
            w.c[self.inv]["Bottle"] -= 1
            w.c[self.inv]["frag:" + self.rng.choice(FAMILIES)] += 1
            return
        if w.c["BOTTLES"]["Bottle"] > 0:
            self.transfer(now, "BOTTLES", self.inv, "Bottle", min(8, w.c["BOTTLES"]["Bottle"]))
            return
        # sin botellas: pedirlas una sola vez por tanda (bloqueado, no trabado)
        self.blocked += 1
        if self.asked_bottles == 0:
            self.asked_bottles = 16
            line = "Bottle"
            s.need[line] += 16                       # el pedido de botellas es una linea mas del BOM
            s.open_claim(line, 16)
            s.send("sniper", "NEED_BOTTLES", dict(qty=16), now)
            s.send("orquestador", "RUNE_PROGRESS", dict(state="BLOCKED", waiting_on="bottles"), now)


class Sniper(Bot):
    def __init__(self, *a):
        super().__init__(*a)
        self.urgent = False
        self.last_drop = 0

    def handle(self, m, now):
        if m["type"] == "NEED_BOTTLES":
            self.urgent = True

    def work(self, now):
        s, w = self.s, self.w
        # el AH: aparece un listing al azar en cada tick
        if self.rng.random() < 0.3:
            item = self.rng.choice(PIECES + ["Bottle"] * 3 + ["junk"])
            price = self.rng.randint(1, 10)
            if item != "junk" and s.take_purchase(item, price) is not None:
                w.c["AH"][item] += 1
                w.move("AH", self.inv, item, 1)
                s.index[self.inv] = Counter(w.c[self.inv])
                if item == "Bottle":
                    s.applied[item] += 1             # para la contabilidad: la botella entra al stock
        carry = sum(w.c[self.inv].values())
        bottles = w.c[self.inv]["Bottle"]
        if (self.urgent and bottles >= 8) or carry >= 30 or (carry and now - self.last_drop > 1200):
            for item, q in list(w.c[self.inv].items()):
                if q:
                    dst = "BOTTLES" if item == "Bottle" else "DELIVERY"
                    self.transfer(now, self.inv, dst, item, q)
                    if item == "Bottle":
                        s.send("runero", "DELIVERED", dict(qty=q, chest=dst), now)
                        self.urgent = False
            self.last_drop = now


def run(seed, faults):
    rng = random.Random(seed)
    s, w = Store(rng, faults), World()
    s.budget = 10_000
    target = Counter({p: 1 for p in PIECES})
    for fam in rng.sample(FAMILIES, 5):
        target[fam] = rng.randint(1, 4)
    s.need.update(target)
    w.c["BOTTLES"]["Bottle"] = rng.randint(0, 10)
    bots = [Orquestador("orquestador", s, w, rng, faults), Runero("runero", s, w, rng, faults),
            Sniper("sniper", s, w, rng, faults)]
    for t in range(MAX_TICKS):
        for b in rng.sample(bots, 3):
            b.step(t)
        # invariantes en cada tick
        for line in s.need:
            if line != "Bottle":
                assert s.bought[line] <= target[line], f"compra de mas: {line}"
        assert s.spend <= s.budget
        if all(s.applied[l] >= target[l] for l in target):
            break
    done = all(s.applied[l] >= target[l] for l in target)
    for b in bots:
        b.resume()
    stale = [loc for loc in w.c if loc != "AH" and +Counter(s.index[loc]) != +w.c[loc] and s.index[loc]]
    over = {l: s.applied[l] - target[l] for l in target if s.applied[l] > target[l]}
    return dict(done=done, ticks=t, over=over, stale=stale, spend=s.spend,
                blocked=bots[1].blocked, bottles=s.bought["Bottle"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--faults", type=int, default=1)
    a = ap.parse_args()
    res = [run(a.seed * 1_000_003 + i, a.faults) for i in range(a.runs)]
    fails = [r for r in res if not r["done"] or r["over"] or r["stale"]]
    ticks = sorted(r["ticks"] for r in res)
    print(f"corridas={len(res)} fallas={len(fails)} faults={a.faults}")
    print(f"ticks hasta terminar: p50={ticks[len(ticks)//2]} p95={ticks[int(len(ticks)*.95)]} max={ticks[-1]}")
    print(f"gasto medio={sum(r['spend'] for r in res)/len(res):.0f} botellas medias={sum(r['bottles'] for r in res)/len(res):.1f}")
    for r in fails[:5]:
        print("FALLA", r)


if __name__ == "__main__":
    main()
