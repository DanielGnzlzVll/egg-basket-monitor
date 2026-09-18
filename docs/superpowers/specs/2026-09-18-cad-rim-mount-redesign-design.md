# Rediseño de cabeza del sensor: mordaza+gancho unificados, bisagra simple, cotas reales

**Fecha:** 2026-09-18
**Estado:** aprobado, pendiente de plan de implementación

## Problema

Tres cosas no funcionan bien en el diseño 3D actual (`docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`):

1. **`clamp` (mordaza del sensor) y `hook` (gancho de la caja) son dos piezas
   independientes** que en la práctica hay que instalar en el mismo punto del
   borde, una agarrando desde dentro y otra desde fuera. Nada en el CAD las
   alinea entre sí: es el instalador quien tiene que acertar la posición a ojo.
2. **La articulación Hirth es más compleja de lo que este proyecto necesita.**
   90 posiciones talladas como un polyhedro para una ventana que solo usa 4.
3. **Las cotas del PCB en `params.scad` no coinciden con el sensor real
   comprado** (TOF200C): `pcb_l` y `pcb_hole_spacing` están mal.

La `box`/`lid` de la caja de electrónica **ya están impresas y quedan
congeladas**: ningún cambio de este documento puede tocar su geometría ni la
posición de sus agujeros.

## Alcance

Dentro:

- Fusionar `clamp` + `hook` en una sola pieza (`mount`) que se aprieta al
  borde en un único punto y sostiene tanto el brazo del sensor como la caja
  ya impresa.
- Reemplazar la bisagra Hirth por un pivote de fricción (tornillo M3 + tuerca,
  sin detentes).
- Corregir `pcb_l` y `pcb_hole_spacing` a las cotas reales del TOF200C.
- Actualizar `cad/build.py`, `docs/bom.md` y la tabla de piezas del spec de
  2026-09-04 para reflejar el nuevo inventario de piezas y tornillería.

Fuera:

- Cualquier cambio a `box`/`lid` (`electronics_box.scad`).
- Cambios al firmware, a Grafana o a la lógica de calibración: `geometry.scad`
  sigue siendo la fuente de verdad del ángulo válido, solo cambia cómo se
  materializa ese ángulo en la pieza impresa.

## Decisiones de diseño

### Pieza combinada `mount`, un solo punto de apriete al borde

Hoy `clamp` y `hook` comparten el perfil en U de `lib/rim_hook.scad` pero son
dos sólidos, dos tornillos de apriete y dos posiciones que deben coincidir por
convención, no por construcción. Se fusionan en una sola pieza `mount` con:

- **El apriete al borde**, una sola vez (antes eran dos tornillos
  independientes, uno por pieza).
- **Un brazo hacia dentro** que termina en una oreja con agujero pasante M3:
  aquí se atornilla el `pod` (ver más abajo). Reemplaza a `clamp` + `plate`.
- **Un brazo hacia fuera** que reproduce *exactamente* la interfaz de
  montaje que ya existe en la `box` impresa: mismas posiciones de agujero,
  mismo diámetro de tornillo. La caja no se entera de que antes colgaba de una
  pieza separada.

Efecto práctico: para levantar la canasta y lavarla se afloja **un tornillo**,
no dos. Y como los dos brazos salen del mismo punto de apriete, el balance de
momento que describía el spec original (la caja hacia fuera compensando el
brazo del sensor hacia dentro) queda garantizado por construcción en vez de
depender de que el instalador ponga las dos piezas en el mismo sitio.

Restricción dura: las cotas de la interfaz hacia la caja (posición de los dos
agujeros, diámetro de tornillo, profundidad de rosca) se toman **tal cual**
de `electronics_box.scad` — no se recalculan, se copian, porque la caja no se
puede reimprimir.

### Bisagra de fricción, sin detentes

Se elimina `lib/hirth.scad` completo (no queda ningún otro consumidor) y el
módulo `plate()` de `sensor_head.scad`. La corona dentada se reemplaza por:

- Una oreja plana en el brazo interior del `mount` (mencionada arriba).
- Una oreja equivalente en el extremo del `pod`, donde antes iba el disco
  Hirth.
- Un tornillo M3 pasante por las dos orejas, con una arandela entre las caras
  de contacto para repartir la presión, y una tuerca (el `knob` actual,
  reutilizado sin cambios de forma) que se aprieta a mano.

Se mantiene tornillo y no filamento como eje: con un tornillo, la fricción se
regula apretando o aflojando, y sigue siendo tornillería métrica normal del
proyecto (ningún ítem nuevo en la lista de compras). El eje de filamento
quedaría fijo sin forma de ajustar cuánto agarra.

**Riesgo aceptado explícitamente por decisión del usuario:** sin detentes, el
ángulo puede correrse con vibración o al apretar de forma distinta cada vez
que se desmonta, y la calibración en Grafana (`d_vacia`/`d_llena`) deja de ser
tan repetible como con el Hirth. Mitigación de bajo costo: se documenta en
`docs/calibration.md` recalibrar cada vez que se toca el pivote, y se
recomienda una arandela de presión (tipo grower) si el usuario tiene una en su
kit de tornillería, para que el apriete no ceda solo con el tiempo.

`pod_arm` (hoy `hirth_r_out + pcb_w / 2 + 6`, en `params.scad`) se recalcula
en función del tamaño de la nueva oreja en vez del radio del Hirth.
`geometry.scad` no cambia: sigue validando el rango de ángulos a partir del
`pod_arm` que le llegue, sea cual sea su origen.

### Cotas reales del TOF200C

En `params.scad`, sección `[Modulo VL53L1X]`:

| Parámetro | Antes | Ahora | Fuente |
|---|---|---|---|
| `pcb_l` | 25.0 | **20.0** | ancho total del PCB en la foto |
| `pcb_hole_spacing` | 20.0 | **14.4** | separación real entre centros de agujero |
| `pcb_w` | 11.0 | sin cambio | ya coincide con el alto real del PCB |
| `pcb_hole_d` | 2.3 | sin cambio | agujero real mide Ø2, 2.3 ya da holgura para M2 |
| `window_d` | 7.5 | sin cambio | ya es el máximo que deja `pcb_support >= 2` con `pcb_w=11`; la ranura óptica real (9.6×5 ovalada) es más ancha de lo que el margen del PCB permite, así que se prioriza que el PCB apoye bien |

Los `assert` existentes en `sensor_head.scad` (separación de agujeros vs.
ventana, agujeros dentro del PCB) se vuelven a evaluar solos con los números
nuevos; si algo deja de cuadrar, la compilación aborta y lo dice.

### Reestructuración de archivos

- **Nuevo `cad/rim_mount.scad`**: genera `mount` (`part="mount"`). Incluye
  `lib/rim_hook.scad` para el perfil de apriete al borde.
- **`sensor_head.scad`**: pierde `clamp`, `plate` y el `use <lib/hirth.scad>`.
  Se queda con `pod` (con oreja de fricción en vez de disco Hirth) y `knob`
  (sin cambios de forma).
- **`electronics_box.scad`**: pierde el módulo `hook`. `box` y `lid` no
  cambian ni una cota. Las constantes que definen la interfaz de montaje hacia
  el gancho (posición de los dos agujeros de la espina, diámetro de tornillo)
  se promueven a `params.scad` para que `rim_mount.scad` las lea de ahí en
  vez de duplicarlas o de tener que importar todo `electronics_box.scad`
  (que tiene sus propios `echo`/`assert` de nivel superior).
- **`lib/hirth.scad`**: se borra. Sin usos tras el cambio.
- **`cad/build.py`**: el diccionario `MODELS` pasa a:
  ```
  "sensor_head.scad":    ["pod", "knob"],
  "electronics_box.scad": ["box", "lid"],
  "rim_mount.scad":      ["mount"],
  ```
- **`docs/bom.md`**: la tabla de tornillería pierde la fila "Placa → mordaza"
  (ya no hay placa) y las dos filas de apriete de gancho se funden en una
  ("Apriete del mount al borde", 1 tornillo en vez de 2). La tabla de piezas
  impresas pasa de 7 a 5: `mount`, `pod`, `knob`, `box`, `lid`.
- **Spec de 2026-09-04**: se le añade una nota apuntando a este documento en
  la sección "Diseño 3D", en vez de reescribir su contenido (ese spec sigue
  siendo válido para todo lo que no cambia: sensado, montaje general,
  firmware, Grafana).

## Piezas: antes → después

| Antes (7 piezas) | Después (5 piezas) |
|---|---|
| `clamp` | fusionada en `mount` |
| `hook` | fusionada en `mount` |
| `plate` | eliminada (bisagra de fricción no la necesita) |
| `pod` | `pod` (oreja de fricción en vez de disco Hirth) |
| `knob` | `knob` (sin cambios) |
| `box` | `box` (sin cambios) |
| `lid` | `lid` (sin cambios) |

## Validación

`python cad/build.py` sigue siendo la herramienta de verificación: exporta
las 5 piezas, corre los `echo` de geometría y tornillería, y falla con código
de salida distinto de cero si algún `assert` salta (huecos del PCB, ventana
óptica, tornillos del gancho fuera de sitio). Se añade una comprobación nueva
específica de este cambio: que la interfaz `mount`→`box` reproduzca los
agujeros de la espina dentro de una tolerancia de 0, no aproximada — un
`assert` que compare las constantes copiadas contra las originales de
`electronics_box.scad` para que un futuro cambio en uno de los dos archivos
no los desincronice en silencio.

## Riesgos abiertos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Fricción pura sin detentes puede aflojarse con vibración o uso | El ángulo se corre y la calibración deja de ser repetible | Arandela de presión si está disponible; recalibrar en Grafana tras cada desmonte; documentado en `docs/calibration.md` |
| La ventana óptica real del TOF200C (ranura ovalada 9.6×5 mm) es más ancha que lo que permite `window_d` con `pcb_w=11` | Posible vignetting si la óptica activa del chip no está centrada en la zona que sí cubre `window_d=7.5` | Medir con el módulo en mano antes de imprimir el `pod` definitivo: si el área óptica activa cae dentro de los 7.5 mm centrales, no hay problema real |
