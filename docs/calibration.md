# Calibración del ángulo del sensor

El VL53L1X mide en diagonal a través de la canasta (ver
`docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`, sección "El
cono del emisor decide dónde se monta"). El ángulo correcto no es una
preferencia: la geometría de tu canasta específica fija una ventana de solo
8-20° desde la vertical, con cuatro posiciones de detente Hirth disponibles
en la pieza impresa (`cad/sensor_head.scad`).

Este documento cubre el modo de calibración del firmware, que sirve para
**elegir cuál de esos detentes usar**, no para cambiar el rango por software.

## Cuándo usarlo

- Primera vez que armás la cabeza del sensor sobre la canasta real.
- Después de imprimir una nueva `plate`/`pod` con distinto `hirth_r_out` o
  `detent_step` en `cad/params.scad`.
- Si las lecturas en Grafana muestran `stddev` alto de forma sostenida (ver
  más abajo qué significa eso).

## Cómo entrar

Ver `docs/setup-tutorial.md`, sección 5: sostener BOOT entre 3 y 8 segundos
al arrancar (power-on, reset, o reconectando la batería). El LED confirma con
dos parpadeos verdes.

## Qué hace

Durante 60 segundos, el firmware imprime por serial (115200 baudios) una
lectura cruda del VL53L1X a 2 Hz, sin mediana ni filtrado:

```
distancia_mm=412 status=0
distancia_mm=409 status=0
distancia_mm=1988 status=4
...
```

`status` es el `RangeStatus` crudo de la librería Pololu VL53L1X (`0` =
válido; otros valores indican señal débil, señal cruzada o fuera de rango —
ver el datasheet del VL53L1X para la tabla completa).

## Cómo elegir el detente

1. Con la canasta **vacía**, aflojá el `knob`, girá el `pod` a un detente, y
   apretá.
2. Entrá a modo calibración y mirá los valores durante unos segundos.
3. Repetí para los cuatro detentes (8°, 12°, 16°, 20° según
   `cad/params.scad`) y anotá la distancia típica de cada uno.
4. Buscás el detente donde:
   - La lectura es **estable** (los valores no saltan más de unos pocos mm
     entre sí).
   - `status=0` en la gran mayoría de las lecturas.
   - La distancia con la canasta vacía y con la canasta llena da un rango
     amplio (más recorrido = más resolución para estimar nivel).
5. El detente nominal de diseño es 16°, con 450 mm vacía / 345 mm llena
   (~104 mm de recorrido). Si tu canasta real da números muy distintos,
   revisá que las medidas en `cad/params.scad` coincidan con la canasta que
   tenés.

## Qué significa `stddev` alto en producción

Una vez calibrado y en operación normal, cada envío a Grafana incluye
`stddev` (desviación estándar de las 20 lecturas de ese ciclo) y `valid`
(cuántas de esas 20 fueron válidas). Si `stddev` sube de forma sostenida en
el dashboard:

- El ángulo se corrió (un huevo golpeó el pod, se aflojó el knob, etc.).
- Volvé a este modo de calibración para verificar y, si hace falta, ajustar
  el detente sin reimprimir nada.

Esto es intencional por diseño: `stddev` y `valid` son la señal de que el
ángulo está mal *antes* de que los datos de nivel se vuelvan basura, no un
detalle de diagnóstico secundario.
