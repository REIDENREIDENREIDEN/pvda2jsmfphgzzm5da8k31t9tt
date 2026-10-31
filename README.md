# Bancos E2E en GitHub Actions

Corre los bancos `terreno` y `flujo` en runners `ubuntu-latest`: cliente Minecraft 1.8.9 + Forge real sin pantalla
(Xvfb + Mesa llvmpipe) contra un servidor Paper 1.8.8 local con un plugin emulador (`bench/emu*/plugin`).
Hasta 20 jobs en paralelo. Cuenta offline (`-u TestBot`, `online-mode=false`): sin cuentas Microsoft.
El jar bajo prueba **no** esta en el repo: cada job baja `m.bin` (el jar cifrado) de un release y lo descifra con el
secret `JAR_KEY`. Es el unico secret.

## Contenido

| ruta | que es |
|---|---|
| `.github/workflows/bench.yml` | workflow manual: `plan` (reparte escenarios) -> `prep` (baja dependencias a la cache) -> `shard` x N -> `merge` (resumen) |
| `setup.sh` | instala todo en una Ubuntu limpia y arma el layout `/home/user/...` que esperan los scripts (enlace a `BASE`) |
| `bench/` | copias de los scripts de banco: `banco/` (cli.sh, drv.sh), `emu/` (terreno: run.sh, srv.sh, plugin), `emu-flujo/` (flujo.sh, srv.sh, lag.py, eval.py, esc/, plugin), `hielo/` (plugin del printer), `terreno/genplan.py` (tabla de terrenos), `run-shard.sh` |
| `tools/plan.py` | lista/elige escenarios y arma la matrix |
| `tools/merge.py` | junta las lineas `RES` de todos los shards en `summary.md` + `results-all.txt` |
| `tools/dispatch.py` | lanza corridas y baja resultados con `gh` |

Lo que baja `setup.sh` (todo de fuentes oficiales, con sha256 donde aplica): Temurin 8 (si el runner no lo trae),
portablemc 5.0.6 (PyPI), Forge 1.8.9-11.15.1.2318 + librerias + assets (Mojang/Forge), Paper 1.8.8-445 (paperclip de PaperMC,
genera `patched_1.8.8.jar`), Schematica 1.7.7.143 + LunatriusCore 1.1.2.32 (CDN de CurseForge). `prep` guarda
`~/work-root/.cache` y `~/work-root/mc` con `actions/cache`; los shards los restauran.

## Crear el repo y subir

El nombre del repo solo admite letras ASCII, digitos, `.`, `-` y `_`. Si se copia de otro lado, revisar que no
traiga caracteres Unicode invisibles (espacios de ancho cero, etc.): GitHub los reemplaza o rechaza.

```bash
cd gha
git init -b main && git add . && git commit -m "bench"
git remote add origin https://github.com/OWNER/REPO.git     # o: gh repo create OWNER/REPO --public --source . --push
git push -u origin main
```

`.gitattributes` fuerza LF en los scripts (si no, un push desde Windows puede romper los `.sh`).

## Publicar el jar

1. Secret del repo: Settings > Secrets and variables > Actions > `JAR_KEY` (o `gh secret set JAR_KEY -R OWNER/REPO`).
2. Cifrar y subir como asset `m.bin` del release (lo crea si no existe):

```bash
JAR_KEY='...' python tools/dispatch.py jar ruta/al/mod.jar --tag jar-0.6.1
# equivale a: openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -in mod.jar -out m.bin -pass file:k ; gh release upload jar-0.6.1 m.bin
```

El job lo baja con `gh release download TAG -p m.bin` (`GITHUB_TOKEN`, `contents: read`), escribe la clave en un archivo
temporal, descifra a `m.jar`, borra la clave y verifica el sha256 (input `jar_sha256`, por defecto el de 0.6.1:
`1e133afe...7d47`). La clave nunca se imprime (Actions ademas enmascara los secrets). El input `jar` tambien acepta
una URL `https://...` o una ruta dentro del repo (jar sin cifrar).

## Lanzar

`tools/dispatch.py` usa por defecto el repo `REIDENREIDENREIDEN/pvda2jsmfphgzzm5da8k31t9tt` (cambiar con `--repo OWNER/REPO`
o la variable `BENCH_REPO`). Desde la pestana Actions (workflow `bench`, "Run workflow") o:

```bash
python tools/dispatch.py run --bench terreno --scenarios all --shards 20
python tools/dispatch.py run --bench flujo --scenarios "a0* g07-crash-claim" --shards 5 --jar jar-0.6.1
python tools/dispatch.py list
python tools/dispatch.py watch RUN_ID
```

Escenarios: `terreno` = tags de `bench/terreno/genplan.py` (45, semilla `r2t-TAG`); `flujo` = archivos de
`bench/emu-flujo/esc/` sin `.sh` (113). `all` o lista separada por espacios, con comodines (`d0*`, `*-s2`).
Se reparten en ronda entre `min(shards, 20, escenarios)` jobs; cada job corre los suyos uno detras de otro.

## Recolectar

```bash
python tools/dispatch.py fetch RUN_ID          # baja runs/RUN_ID/res-*/ y escribe runs/RUN_ID/summary.md
```

Cada shard sube `res-BANCO-NN` (14 dias): `out/results.txt` (lineas RES), una carpeta por escenario
(server.log, autosetup.log, checks, veredicto, capturas .png) y `setup.log`. El log completo del cliente
(`cliente.log`, lista de mods) y `chat.txt` no se suben (son publicos y `eval.py`/`merge.py` no los usan). El job `merge` sube
`summary-BANCO` y escribe la tabla en el resumen de la corrida.

Lineas RES:
- terreno (de `emu/run.sh`): `RES TAG done=1 dur=... tprep=... wild=... busters=... ... | resultado: ... | alPrinter: ... | final: ...`
- flujo (de `eval.py`): `RES ESC pasa=1 done=1 prep=... dur=... wild=... busters=... | VEREDICTO ... | RESULTADO ...`
- falla del banco: `RES TAG ERROR=...` (servidor, cliente que no entro, timeout).

## Correr fuera de Actions (VM Ubuntu 22.04/24.04 con sudo)

```bash
bash setup.sh                                   # BASE=~/work-root por defecto; /home/user -> BASE
bash bench/run-shard.sh terreno ~/work-root/m.jar "d01"
bash bench/run-shard.sh flujo ~/work-root/m.jar "a01-base"
```

## Limites y avisos

- Repo publico: minutos gratis en runners estandar (4 vCPU, 16 GB, ~14 GB de disco).
- Hasta 20 jobs simultaneos por cuenta (plan Free; los demas quedan en cola). `max-parallel: 20`.
- 6 h maximo por job (aca `timeout-minutes: 350`); 35 dias por corrida del workflow.
- Logs de Actions y artifacts de un repo publico son publicos: no poner secretos, nombres de cuentas reales,
  servidores ni coordenadas en escenarios o configs; el jar va cifrado (`m.bin`). Solo usa el secret `JAR_KEY`
  (los secrets no llegan a workflows lanzados desde forks).
- `actions/cache`: 10 GB por repo; la clave depende del hash de `setup.sh`.
- Tiempos: setup ~1-2 min por job con cache (apt + Java + restaurar cache); corrida terreno ~8-10 min
  (preparacion ~6 min + 90 s de cane + arranque), flujo ~6-9 min.
