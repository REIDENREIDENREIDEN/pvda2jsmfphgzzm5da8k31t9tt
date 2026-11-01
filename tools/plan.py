"""Lista y reparte escenarios del banco.
  plan.py list terreno|flujo                      -> un nombre por linea
  plan.py select BENCH "all|n1 n2 x*"             -> nombres elegidos, separados por espacio
  plan.py matrix BENCH "all|n1 n2 x*" SHARDS      -> JSON de matrix {"include":[{"id":"00","items":"..."}]}
  plan.py cmd terreno TAG JAR                     -> linea de shell para una corrida (como plan-tK.sh)
Terreno: tabla R de bench/terreno/genplan.py (semilla r2t-TAG). Flujo: bench/emu-flujo/esc/*.sh.
"""
import fnmatch, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'bench', 'terreno'))
import genplan  # noqa: E402


def names(bench):
    if bench == 'terreno':
        return [r[0] for r in genplan.R]
    if bench == 'flujo':
        d = os.path.join(ROOT, 'bench', 'emu-flujo', 'esc')
        return sorted(f[:-3] for f in os.listdir(d) if f.endswith('.sh'))
    sys.exit('bench desconocido: %s' % bench)


# Corrida rapida e2e (~12 min, un escenario por job): /wild, faction (con nombre tomado), claim, warp al centro,
# chunk busters y verificacion, en terrenos y fallas representativos.
QUICK = {
    'terreno': 'd01 a01 a07 w-lava w-lagos p-d01 v-cuevas b-jungla',
    'flujo': 'a01-base a03-agua a07-nieve-ping b09-cae-en-claim b11-enemigo-borde c02-nombre-tomado2 '
             'c11-tomado-castellano e03-busters49 f02-ping250 g07-crash-claim g08-crash-verify h01-ci-confirmacion',
}


def select(bench, spec):
    allv = names(bench)
    if spec.strip() == 'quick':
        spec = QUICK[bench]
    toks = spec.replace(',', ' ').split()
    if not toks or toks == ['all']:
        return allv
    out = []
    for t in toks:
        hit = [n for n in allv if fnmatch.fnmatchcase(n, t)]
        if not hit:
            sys.exit('escenario desconocido para %s: %s' % (bench, t))
        out += [n for n in hit if n not in out]
    return out


def cmd_terreno(tag, jar):
    for t, lt, gen, mods, extra in genplan.R:
        if t == tag:
            sed = ';'.join(genplan.S[m] for m in mods)
            return ("SEED=r2t-%s LEVEL_TYPE=%s GEN='%s' EMU_SED='%s' POST=90 MIN=16 %s bash /home/user/emu/run.sh %s %s"
                    % (t, lt, gen, sed, extra, jar, t))
    sys.exit('tag desconocido: %s' % tag)


def main():
    a = sys.argv[1:]
    if a[0] == 'list':
        print('\n'.join(names(a[1])))
    elif a[0] == 'select':
        print(' '.join(select(a[1], a[2])))
    elif a[0] == 'matrix':
        items = select(a[1], a[2])
        n = max(1, min(int(a[3]), 20, len(items)))
        sh = [[] for _ in range(n)]
        for i, it in enumerate(items):
            sh[i % n].append(it)
        print(json.dumps({'include': [{'id': '%02d' % k, 'items': ' '.join(s)} for k, s in enumerate(sh)]}, separators=(',', ':')))
    elif a[0] == 'cmd' and a[1] == 'terreno':
        print(cmd_terreno(a[2], a[3]))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
