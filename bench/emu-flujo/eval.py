# (VM) Veredicto de una corrida del banco flujo. Uso: python3 eval.py OUT_DIR  (lee escenario.txt, logs y checks)
# Imprime "VEREDICTO PASA|FALLA <motivos>" y una linea "METRICAS {json}".
import json, re, sys, os

O = sys.argv[1]


def rd(n):
    p = os.path.join(O, n)
    return open(p, encoding='utf-8', errors='replace').read() if os.path.isfile(p) else ''


esc = rd('escenario.txt')
expect = re.search(r'^EXPECT=(.*)$', esc, re.M).group(1).strip()
chk = esc.split('CHK:\n', 1)[1].strip().splitlines() if 'CHK:\n' in esc else []
srv = [l for l in rd('server.log').splitlines() if 'EMU ' in l or 'issued server command' in l]
emu = [l.split('EMU ', 1)[1] for l in srv if 'EMU ' in l]
al = rd('autosetup.log').splitlines()


def cnt(rx):
    r = re.compile(rx)
    return sum(1 for l in emu if r.search(l))


m = {}
m['wild_cmd'] = cnt(r'^CMD TestBot /wild')
m['wild_tp'] = cnt(r'^WILD tp ')
m['wild_cd'] = cnt(r'^WILD cooldown ')
m['enemigos'] = cnt(r'^ENEMY ')
m['buster_ok'] = cnt(r'^BUSTER puesto ')
m['buster_rep'] = cnt(r'^BUSTER repetido ')
m['buster_cd'] = cnt(r'^BUSTER cooldown ')
m['buster_terr'] = cnt(r'^BUSTER territorio ')
m['consumidos'] = m['buster_ok'] + m['buster_rep']
# r2-flujo: re-busteo JUSTIFICADO = buster puesto en un chunk que el emulador ya habia terminado de limpiar (quedaron
# restos: piedra que rehace agua+lava, enredaderas que rebrotan). No es un buster gastado de mas por el flujo.
_limpios, m['rebust_justificado'] = set(), 0
for _l in emu:
    _mm = re.match(r'^BUSTER (puesto|limpio) (?:TestBot )?chunk (-?\d+,-?\d+)', _l)
    if not _mm: continue
    if _mm.group(1) == 'limpio': _limpios.add(_mm.group(2))
    elif _mm.group(2) in _limpios: m['rebust_justificado'] += 1
m['prohibidos'] = cnt(r'^PROHIBIDO ')
m['show_cmd'] = cnt(r'^CMD TestBot /f show')
m['create_cmd'] = cnt(r'^CMD TestBot /f create')
m['create_ok'] = cnt(r'^CREATE TestBot \S+$')
m['claim_cmd'] = cnt(r'^CMD TestBot /f claim')
m['claim_ok'] = cnt(r'^CLAIM ')
m['setwarp_cmd'] = cnt(r'^CMD TestBot /f setwarp')
m['fly_cmd'] = cnt(r'^CMD TestBot /fly')
m['ci_cmd'] = cnt(r'^CMD TestBot /ci')
m['printer_cmd'] = cnt(r'^CMD TestBot /printer')
m['muertes'] = cnt(r'^MUERTE ')
pr = [l for l in emu if re.match(r'^PRINTER TestBot (true|false)', l)]
m['printer_final'] = bool(pr) and pr[-1].startswith('PRINTER TestBot true')
idx_last_buster = max([i for i, l in enumerate(emu) if l.startswith('BUSTER puesto') or l.startswith('BUSTER repetido')] or [-1])
idx_first_ci = min([i for i, l in enumerate(emu) if l.startswith('CMD TestBot /ci')] or [10 ** 9])
m['ci_despues_de_busters'] = idx_first_ci > idx_last_buster
m['errores'] = sum(1 for l in al if ' ERROR ' in l)
m['stops'] = sum(1 for l in al if ' STOP ' in l)
out = [l for l in al if ' DONE ' in l or ' FAIL ' in l]
m['resultado'] = out[-1].split(' ', 1)[1] if out else ('STOP' if m['stops'] else 'NADA')
m['duracion_s'] = int(rd('duracion.txt').strip() or 0)


def secs(l):
    h, mi, s = l[:12].split(':')
    return int(h) * 3600 + int(mi) * 60 + float(s)


start = [l for l in al if '==== preparar' in l]
if start and out:
    d = secs(out[-1]) - secs(start[0])
    m['prep_s'] = round(d + 86400 if d < 0 else d, 1)
corner = [l for l in al if 'En la esquina del printer:' in l]
hc = rd('check-hueco.txt')
if hc:
    g = lambda rx, t=str: (lambda mm: t(mm.group(1)) if mm else None)(re.search(rx, hc))
    m['hueco_solidos'] = g(r'solidos=(\d+)', int)
    m['claim'] = g(r'claim9x9=(\d+)/81', int)
    m['warp_centrado'] = g(r'warpCentrado=(\w+)') == 'true'
    m['warp_y'] = g(r'warp=[-\d.]+,([-\d.]+),', float)
    m['minX'] = g(r'minX=(-?\d+)', int)
    m['minZ'] = g(r'minZ=(-?\d+)', int)
    if corner and m['minX'] is not None:
        x, y, z = [float(v) for v in re.search(r'printer: (-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)', corner[-1]).groups()]
        m['esquina_rel'] = [round(x - m['minX'], 2), round(y, 2), round(z - m['minZ'], 2)]
fc = rd('check.txt')
mm = re.search(r'busters=(\d+) printer=(\w+)', fc)
if mm:
    m['busters_final'] = int(mm.group(1))

bad = []
if expect == 'DONE':
    if not m['resultado'].startswith('DONE'):
        bad.append('no termino: ' + m['resultado'][:200])
    else:
        if m['create_ok'] != 1: bad.append('create_ok=%d' % m['create_ok'])
        if m['consumidos'] != 49 + m['rebust_justificado']: bad.append('busters consumidos=%d (rebust justificados=%d)' % (m['consumidos'], m['rebust_justificado']))
        if m['buster_rep']: bad.append('busters repetidos=%d' % m['buster_rep'])
        if m.get('hueco_solidos') != 0: bad.append('hueco solidos=%s' % m.get('hueco_solidos'))
        if m.get('claim') != 81: bad.append('claim=%s/81' % m.get('claim'))
        if not m.get('warp_centrado'): bad.append('warp no centrado')
        wy = m.get('warp_y')
        if wy is None or not (260 <= wy < 260.5): bad.append('warp y=%s' % wy)
        er = m.get('esquina_rel')
        if not er or abs(er[0] - 1.5) > 0.3 or abs(er[2] - 3.5) > 0.3 or er[1] > 1.2: bad.append('esquina=%s' % er)
        if m['ci_cmd'] < 2 or not m['ci_despues_de_busters']: bad.append('ci=%d antes=%s' % (m['ci_cmd'], not m['ci_despues_de_busters']))
        if not m['printer_final']: bad.append('printer apagado al final')
elif expect.startswith('FAIL:'):
    rx = expect[5:]
    if not m['resultado'].startswith('FAIL'):
        bad.append('se esperaba FAIL /%s/ y fue: %s' % (rx, m['resultado'][:200]))
    elif not re.search(rx, m['resultado'], re.I):
        bad.append('FAIL con otro motivo: ' + m['resultado'][:200])
if m['prohibidos']: bad.append('comandos prohibidos=%d' % m['prohibidos'])
if m['errores']: bad.append('errores internos=%d' % m['errores'])
for c in chk:
    c = c.strip()
    if not c: continue
    try:
        if not eval(c, {}, {'m': m}): bad.append('chk: ' + c)
    except Exception as e:
        bad.append('chk error %s: %s' % (c, e))
print('VEREDICTO', 'PASA' if not bad else 'FALLA', '; '.join(bad))
print('RESULTADO', m['resultado'][:300])
print('METRICAS', json.dumps(m, ensure_ascii=False))
