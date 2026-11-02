# Prototipo del protocolo del pipeline de 3 bots

Simulación chica (Python, sin Minecraft) para validar el diseño del pipeline Orquestador / Runero / Sniper:
almacén con cupos de compra atómicos, cola de mensajes al-menos-una-vez con ids idempotentes, transferencias
en dos fases y pausas de VM al azar (incluso entre mover un ítem y anotarlo).

```
python3 sim.py --runs 1000 --faults 0   # sin fallos
python3 sim.py --runs 1000 --faults 1   # pausas, mensajes duplicados, acks perdidos
```

Invariantes que chequea en cada tick: nunca se compra de más para una línea del objetivo, nunca se pasa el
presupuesto; al final el set está completo y el índice coincide con la verdad del server.

Hallazgo: la primera versión volvía a comprar piezas que el Sniper ya tenía en el inventario y no había entregado,
porque el cálculo del faltante solo miraba los cofres. El faltante ahora cuenta el stock en cualquier lugar del
índice, incluidos los inventarios de los otros bots.

No es código para producción: la implementación real va en Kotlin dentro del cliente (ver el documento de diseño).
