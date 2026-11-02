# Version Remote Sandbox (cifrada)

`src.bin` es el codigo de la rama `autosetup` del repo privado, cifrado con una clave que solo se deriva del jar
original (que a su vez solo se descifra con el secret JAR_KEY). Al subir o cambiar `sandbox/src.bin` corre
`.github/workflows/sandbox.yml`: compila y corre los bancos de `sandbox/e2e.env`. El jar compilado pasa entre jobs cifrado.
