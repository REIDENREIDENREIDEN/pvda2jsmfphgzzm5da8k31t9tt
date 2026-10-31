"""Junta las lineas RES de todos los shards.
Uso: merge.py DIR [--expect "esc1 esc2 ..."]
Busca DIR/**/results.txt, escribe DIR/results-all.txt y DIR/summary.md e imprime el resumen (Markdown).
"""
import os, re, sys


def main():
    a = sys.argv[1:]
    root = a[0]
    expect = a[a.index('--expect') + 1].split() if '--expect' in a else []
    res = {}
    for dp, _, fs in os.walk(root):
        for f in fs:
            if f != 'results.txt':
                continue
            for l in open(os.path.join(dp, f), encoding='utf-8', errors='replace'):
                if l.startswith('RES '):
                    res[l.split()[1]] = l.rstrip('\n')
    names = expect + sorted(n for n in res if n not in expect)
    rows, done, pasa, err, flujo = [], 0, 0, 0, False
    for n in names:
        l = res.get(n)
        if l is None:
            rows.append((n, 'SIN-DATOS', '', '', ''))
            err += 1
            continue
        kv = dict(re.findall(r'(\w+)=([^ |]*)', l.split('|')[0]))
        if 'ERROR' in kv:
            rows.append((n, 'ERROR=' + kv['ERROR'], '', '', ''))
            err += 1
            continue
        flujo = flujo or 'pasa' in kv
        done += kv.get('done') == '1'
        pasa += kv.get('pasa') == '1'
        tail = l.split('|', 1)[1].strip() if '|' in l else ''
        rows.append((n, 'done=%s' % kv.get('done', '?') + (' pasa=%s' % kv['pasa'] if 'pasa' in kv else ''),
                     kv.get('dur', ''), kv.get('tprep', kv.get('prep', '')), tail[:220].replace('|', '/')))
    tot = len(names)
    head = '## Banco: %d corridas, done=1 en %d' % (tot, done) + (', PASA %d' % pasa if flujo else '') + ', errores/sin datos %d' % err
    md = [head, '', '| escenario | estado | dur s | prep s | detalle |', '|---|---|---|---|---|']
    md += ['| %s | %s | %s | %s | %s |' % r for r in rows]
    open(os.path.join(root, 'results-all.txt'), 'w', encoding='utf-8').write('\n'.join(res[n] for n in names if n in res) + '\n')
    open(os.path.join(root, 'summary.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    sys.stdout.reconfigure(encoding='utf-8')
    print('\n'.join(md))


if __name__ == '__main__':
    main()
