"""Aplica un overlay (zip ya descifrado) sobre el jar: reemplaza los paquetes que trae y, si trae VERSION, la de mcmod.info.
  overlayjar.py JAR OVERLAY.zip
Las entradas del jar bajo un directorio que el overlay trae se borran antes (asi no quedan clases sinteticas viejas)."""
import re, sys, zipfile, os
jar, ov = sys.argv[1], sys.argv[2]
zo = zipfile.ZipFile(ov)
new = {n: zo.read(n) for n in zo.namelist() if not n.endswith('/')}
ver = new.pop('VERSION', b'').decode().strip()
dirs = {os.path.dirname(n) + '/' for n in new}
zi = zipfile.ZipFile(jar)
items = [(it, zi.read(it.filename)) for it in zi.infolist()]
zi.close()
tmp = jar + '.tmp'
z = zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED)
for it, d in items:
    if it.filename.endswith('.class') and os.path.dirname(it.filename) + '/' in dirs:
        continue
    if ver and it.filename == 'mcmod.info':
        d = re.sub(rb'("version"\s*:\s*")[^"]*(")', rb'\g<1>' + ver.encode() + rb'\g<2>', d, count=1)
    z.writestr(it, d)
for n in sorted(new):
    z.writestr(n, new[n])
z.close()
os.replace(tmp, jar)
print('overlay aplicado: %d clases%s' % (len(new), (', version ' + ver) if ver else ''))
