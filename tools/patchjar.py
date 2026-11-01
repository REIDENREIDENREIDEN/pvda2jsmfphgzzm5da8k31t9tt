"""Aplica un parche de textos a clases de un jar (sin publicar el jar ni sus clases).
Uso: patchjar.py JAR PARCHE.json
PARCHE.json: {"version": "0.6.2", "strings": [{"class": "a/b/C.class", "old": "...", "new": "..."}]}
Reemplaza constantes CONSTANT_Utf8 exactas del constant pool (las referencias son por indice, asi que cambiar el
largo de una entrada no rompe la clase) y, si hay "version", la de mcmod.info.
"""
import json, struct, sys, zipfile, shutil, os, tempfile


def mutf8(s):
    out = bytearray()
    for ch in s:
        c = ord(ch)
        if 0 < c < 0x80:
            out.append(c)
        elif c < 0x800:
            out += bytes([0xC0 | (c >> 6), 0x80 | (c & 0x3F)])
        else:
            out += bytes([0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F)])
    return bytes(out)


def patch_class(data, old, new):
    o, n = mutf8(old), mutf8(new)
    count = struct.unpack('>H', data[8:10])[0]
    i, k = 10, 1
    out = bytearray(data[:10])
    hits = 0
    while k < count:
        tag = data[i]
        if tag == 1:
            ln = struct.unpack('>H', data[i + 1:i + 3])[0]
            body = data[i + 3:i + 3 + ln]
            if body == o:
                body = n; hits += 1
            out += bytes([1]) + struct.pack('>H', len(body)) + body
            i += 3 + ln
        else:
            size = {3: 5, 4: 5, 5: 9, 6: 9, 7: 3, 8: 3, 9: 5, 10: 5, 11: 5, 12: 5, 15: 4, 16: 3, 17: 5, 18: 5, 19: 3, 20: 3}[tag]
            out += data[i:i + size]
            i += size
            if tag in (5, 6):
                k += 1
        k += 1
    if hits != 1:
        sys.exit('texto no encontrado (o repetido) en la clase: %r' % old[:60])
    return bytes(out + data[i:])


def main():
    jar, pf = sys.argv[1:3]
    p = json.load(open(pf, encoding='utf-8'))
    z = zipfile.ZipFile(jar)
    files = {i.filename: (i, z.read(i.filename)) for i in z.infolist()}
    z.close()
    for s in p.get('strings', []):
        info, data = files[s['class']]
        files[s['class']] = (info, patch_class(data, s['old'], s['new']))
    if p.get('version') and 'mcmod.info' in files:
        info, data = files['mcmod.info']
        t = data.decode('utf-8')
        import re
        t = re.sub(r'("version"\s*:\s*")[^"]*(")', r'\g<1>' + p['version'] + r'\g<2>', t, count=1)
        files['mcmod.info'] = (info, t.encode('utf-8'))
    fd, tmp = tempfile.mkstemp(suffix='.jar', dir=os.path.dirname(os.path.abspath(jar)))
    os.close(fd)
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as w:
        for name, (info, data) in files.items():
            w.writestr(info, data)
    shutil.move(tmp, jar)
    print('parche %s aplicado (%d textos)' % (p.get('version', '?'), len(p.get('strings', []))))


if __name__ == '__main__':
    main()
