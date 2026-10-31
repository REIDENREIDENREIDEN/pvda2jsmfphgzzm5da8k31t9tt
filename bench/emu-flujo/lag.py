# (VM) Proxy TCP con demora para simular ping: escucha en 25565 (donde entra el cliente) y reenvia a Paper en 25566.
# Uso: python3 lag.py DEMORA_MS JITTER_MS   (demora por sentido: ping ~ 2 x DEMORA; el orden de los bytes se respeta)
# Corte de red: `touch /tmp/lag-cut` cierra todas las conexiones abiertas (el cliente ve "connection lost").
import asyncio, os, random, sys, time

DELAY = float(sys.argv[1]) / 1000.0 if len(sys.argv) > 1 else 0.0
JIT = float(sys.argv[2]) / 1000.0 if len(sys.argv) > 2 else 0.0
CUT = '/tmp/lag-cut'
conns = set()


async def pump(reader, writer):
    q = asyncio.Queue()
    last = [0.0]

    async def rd():
        while True:
            data = await reader.read(65536)
            if not data:
                await q.put(None)
                return
            due = max(last[0], time.monotonic() + DELAY + random.uniform(-JIT, JIT))
            last[0] = due
            await q.put((due, data))

    async def wr():
        while True:
            item = await q.get()
            if item is None:
                break
            due, data = item
            wait = due - time.monotonic()
            if wait > 0:
                await asyncio.sleep(wait)
            writer.write(data)
            await writer.drain()
        writer.close()

    await asyncio.gather(rd(), wr(), return_exceptions=True)
    try:
        writer.close()
    except Exception:
        pass


async def handle(cr, cw):
    try:
        sr, sw = await asyncio.open_connection('127.0.0.1', int(os.environ.get('EMU_PORT', '25566')))
    except Exception:
        cw.close()
        return
    pair = (cw, sw)
    conns.add(pair)
    print('conexion', cw.get_extra_info('peername'), flush=True)
    await asyncio.gather(pump(cr, sw), pump(sr, cw), return_exceptions=True)
    conns.discard(pair)
    print('fin conexion', flush=True)


async def cutter():
    while True:
        await asyncio.sleep(0.2)
        if os.path.exists(CUT):
            os.remove(CUT)
            print('CORTE de red:', len(conns), 'conexiones', flush=True)
            for a, b in list(conns):
                for w in (a, b):
                    try:
                        w.transport.abort()
                    except Exception:
                        pass


async def main():
    srv = await asyncio.start_server(handle, '0.0.0.0', 25565)
    print('lag proxy', DELAY * 1000, '+-', JIT * 1000, 'ms por sentido', flush=True)
    asyncio.ensure_future(cutter())
    async with srv:
        await srv.serve_forever()


asyncio.run(main())
