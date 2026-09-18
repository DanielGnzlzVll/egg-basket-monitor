# Calibración del ángulo del sensor

El VL53L1X mide en diagonal a través de la canasta (ver
`docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`, sección "El
cono del emisor decide dónde se monta"). El ángulo correcto no es una
preferencia: la geometría de tu canasta específica fija una ventana válida
(la calcula `lib/geometry.scad` al compilar; con las cotas actuales del
repo es 7.8°-22° desde la vertical).

Desde el rediseño de 2026-09-18
(`docs/superpowers/specs/2026-09-18-cad-rim-mount-redesign-design.md`), la
bisagra del `pod` es de **fricción pura, sin detentes**: se afloja el
`knob`, se gira el `pod` a mano a cualquier ángulo dentro del rango válido,
y se aprieta. Esto hace que este modo de calibración sea más importante que
antes, no menos: no hay una posición "de fábrica" a la que volver, así que
es la única forma de confirmar que el ángulo elegido a ojo es realmente
bueno.

## Cuándo usarlo

- Primera vez que armás la cabeza del sensor sobre la canasta real.
- Cada vez que se afloja el pivote de fricción por cualquier motivo (limpiar
  la canasta, un golpe, etc.): al no haber detentes, el ángulo no vuelve solo
  a su posición anterior.
- Después de imprimir un `pod`/`mount` con distinto `pod_arm`, `pod_reach` o
  `pivot_drop` en `cad/params.scad`.
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

## Cómo elegir el ángulo

1. Con la canasta **vacía**, aflojá el `knob` lo justo para poder girar el
   `pod` a mano (sin que se caiga solo), no lo saques del todo.
2. Entrá a modo calibración y mirá los valores mientras movés el `pod`
   lentamente dentro del rango válido que imprime `python cad/build.py`
   (`Rango util de la bisagra de friccion: ...` en el reporte de
   `lib/geometry.scad`).
3. Apretá el `knob` a mano en el punto donde:
   - La lectura es **estable** (los valores no saltan más de unos pocos mm
     entre sí).
   - `status=0` en la gran mayoría de las lecturas.
   - La distancia con la canasta vacía y con la canasta llena da un rango
     amplio (más recorrido = más resolución para estimar nivel).
4. Repetí el paso 2 una vez apretado, para confirmar que apretar el `knob`
   no corrió el ángulo (la fricción a veces desplaza un par de grados al
   tensar).
5. El ángulo nominal de diseño es ~15° (centro del rango válido), con
   ~466 mm vacía / ~362 mm llena (~103 mm de recorrido) — ver el reporte de
   `python cad/build.py` para las cifras exactas con tus cotas. Si tu
   canasta real da números muy distintos, revisá que las medidas en
   `cad/params.scad` coincidan con la canasta que tenés.

## Qué significa `stddev` alto en producción

Una vez calibrado y en operación normal, cada envío a Grafana incluye
`stddev` (desviación estándar de las 20 lecturas de ese ciclo) y `valid`
(cuántas de esas 20 fueron válidas). Si `stddev` sube de forma sostenida en
el dashboard:

- El ángulo se corrió (un huevo golpeó el pod, se aflojó el knob, etc.) — más
  probable ahora que la bisagra es de fricción y no tiene topes fijos.
- Volvé a este modo de calibración para verificar y, si hace falta, ajustar
  el ángulo sin reimprimir nada.

Esto es intencional por diseño: `stddev` y `valid` son la señal de que el
ángulo está mal *antes* de que los datos de nivel se vuelvan basura, no un
detalle de diagnóstico secundario.
