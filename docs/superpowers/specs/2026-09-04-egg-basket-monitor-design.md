# Egg Basket Monitor — Diseño

**Fecha:** 2026-09-04
**Estado:** aprobado, pendiente de plan de implementación

## Problema

Los huevos se acaban sin aviso. Para cuando se nota, ya no hay, y la compra se
pospone otro día. El objetivo es recibir una notificación en Telegram cuando el
nivel de la canasta baje de un umbral, con suficiente antelación para comprar
antes de quedarse en cero.

Requisito secundario, y casi tan importante: el sistema debe avisar cuando *él
mismo* deja de funcionar. Una batería agotada produce exactamente el mismo
silencio que una canasta llena.

## Alcance

Dentro:

- Sensor de nivel montado en la canasta, alimentado por batería.
- Envío periódico a Grafana Cloud sin infraestructura intermedia.
- Dashboard y dos reglas de alerta con notificación a Telegram.
- Piezas imprimibles paramétricas para el sensor y la electrónica.

Fuera:

- PCB a medida. Todo se resuelve con módulos comerciales y cables Dupont.
- Conteo exacto de huevos. Se estima nivel de llenado, no unidades.
- Integración con Home Assistant, listas de compra o pedidos automáticos.
- Multi-canasta. Un solo dispositivo, aunque el esquema de métricas lleva un
  label `device` que lo permitiría después.

## Decisiones de diseño

### Sensado: ToF de zona única

Se evaluaron cuatro alternativas:

| Opción | Descartada porque |
|---|---|
| Barrera IR × 5 niveles | 10 piezas a alinear en una canasta curva, ~10 GPIO, y el haz se cuela entre huevos produciendo falsos vacíos. |
| Sensores de luz ambiente × 5 | Dependen de la iluminación de la cocina, la hora del día y la posición de la canasta. |
| Celda de carga (HX711) | Da conteo real, pero obliga a que la canasta se apoye en una plataforma y sufre deriva del cero a largo plazo. |
| **ToF (elegida)** | Un sensor, un bus, montaje simple, medición independiente de la luz ambiente. |

Dentro de ToF se eligió **VL53L1X** (zona única) sobre VL53L5CX/L8CX (8×8
multizona). El multizona sería técnicamente superior para el montaje diagonal
—devuelve un mapa de profundidad de 64 zonas con 65° de FoV, inmune a los huecos
entre huevos— pero cuesta 3-5× más y es más difícil de conseguir. Se acepta
conscientemente el riesgo de lecturas ruidosas.

**Mitigaciones del ruido, dado que el VL53L1X es un rayo único en diagonal:**

1. 20 lecturas por despertar, se reporta la mediana y la desviación estándar.
   La desviación es un dato de diagnóstico de primera clase: si es alta, el
   ángulo está mal.
2. ROI del receptor reducido para estrechar el cono. El emisor siempre dispara
   27° y eso no es configurable; solo el receptor admite ROI, hasta un mínimo
   de 15° con 4×4 SPADs.
3. Articulación con detentes cada 4° en la pieza impresa, para corregir el
   ángulo sin reimprimir. El ángulo es el parámetro que más probablemente falle
   a la primera. El rango realmente utilizable lo fija la geometría de la
   canasta, no una preferencia: ver la sección siguiente.

### El cono del emisor decide dónde se monta y a cuánto se apunta

Con las medidas reales de la canasta —**300 mm de ancho × 150 mm de fondo ×
500 mm de alto**, borde de ~10 mm— el apuntado deja de ser libre. La canasta es
un pozo profundo y estrecho, y el emisor del VL53L1X dispara un cono fijo de 27°
que no se puede estrechar. Si el cono toca una pared antes de llegar al fondo, la
pared devuelve más señal que los huevos y el sensor mide la pared.

Dos consecuencias, ambas calculadas en `cad/lib/geometry.scad` a partir de las
tres medidas:

- **La mordaza va en mitad de un lado corto**, apuntando a través de los 300 mm.
  Apuntando a través de los 150 mm no hay **ningún** ángulo válido.
- **El rango útil es 8-20°** desde la vertical, cuatro posiciones de detente.
  Por debajo, el borde cercano del ROI ve la pared de montaje; por encima, el
  borde lejano alcanza la pared de enfrente.

El cálculo parte de la posición **real** del sensor, no del borde de la canasta:
el pod cuelga de un brazo que lo mete ~68 mm hacia dentro y ~70 mm hacia abajo.
Eso lo aleja de la pared de montaje, que ayuda, pero lo acerca a la de enfrente,
que es lo que de verdad recorta el rango por arriba. Hacer el cálculo desde el
borde da un máximo de 23,5° que en la práctica no existe.

En el detente nominal de 16° el sensor lee **450 mm con la canasta vacía y
345 mm llena**, unos 104 mm de recorrido útil. Ambas cifras caen dentro del modo
**short** del VL53L1X, que es el más inmune a la luz ambiente: un resultado
afortunado que conviene no perder al tocar cotas.

`geometry.scad` **aborta la compilación** si no queda ningún ángulo válido, o si
queda solo uno (una articulación con una sola posición no regula nada). Cambiar
las medidas de la canasta a algo imposible falla en voz alta en vez de producir
una pieza inútil.

### Montaje: cabeza en el borde, midiendo en diagonal

El sensor se sujeta al borde de la canasta y apunta en diagonal hacia el fondo
opuesto, no verticalmente desde arriba. Esto deja libre la boca de la canasta,
que es por donde se ponen y sacan los huevos.

El sistema se parte en dos cuerpos unidos por un latiguillo Dupont de 20 cm:

- **Cabeza del sensor** (~35 g): mordaza + placa + pod articulado + VL53L1X.
  Cuelga del borde hacia **dentro**.
- **Caja de electrónica** (~90 g con la celda): MCU, 18650, TP4056. Cuelga del
  borde hacia **fuera**, con su propio gancho.

**Corrección respecto a la primera versión de este spec.** Antes decía que la
electrónica no podía ir en el borde porque un 18650 con su cuna pesa ~70 g y
volcaría una canasta liviana. Ese razonamiento medía el peso, que es la
magnitud equivocada: lo que vuelca una canasta es el **momento**, y el momento
depende de dónde cuelga la masa. Colgada por fuera, pegada a la pared, la caja
tiene un brazo de ~12 mm; la cabeza del sensor tiene 45 mm hacia el otro lado.
Los dos momentos son del mismo orden y de signo contrario, así que la caja no
solo no empeora el equilibrio: lo mejora. Un cuerpo suelto en la mesa, además,
obligaba a un latiguillo tenso que es justo lo que tira de la canasta.

Se mantienen los dos motivos por los que la caja no va **dentro**: la celda de
litio no queda suspendida sobre la comida, y la canasta se puede levantar y
lavar soltando dos ganchos. La cara inferior de la caja es plana a propósito,
así que también se sostiene de pie en la mesa si se prefiere.

### La calibración vive en Grafana, no en el firmware

El firmware envía **milímetros crudos**. El mapeo distancia → nivel de huevos se
hace en la query del dashboard con dos variables, `d_vacia` y `d_llena`:

```
nivel_pct = (d_vacia - d) / (d_vacia - d_llena) * 100
```

Recalibrar es editar una variable en el navegador. La alternativa —umbrales en
el firmware— exigiría desmontar la canasta y reflashear cada vez, que es
exactamente lo que va a pasar varias veces durante las primeras semanas.

### Telemetría: POST Influx directo a Grafana Cloud

Grafana Cloud acepta Influx line protocol por HTTP: se toma el endpoint de
Prometheus remote-write y se cambia la ruta a `/api/v1/push/influx/write`
(en algunas regiones el host también cambia `prometheus` por `influx`).
Autenticación Basic con el instance ID como usuario y un token de Access Policy
como contraseña; cuerpo `text/plain`.

Es un POST de una línea de texto. Se descartaron:

- **Prometheus remote_write directo**: requiere protobuf + snappy en el ESP32.
  Mucho código y RAM para el mismo resultado.
- **MQTT → Alloy → Cloud**: exige un equipo siempre encendido en casa.

### Cadencia: 1 envío por hora

El requisito original era 1-2 veces al día. Se sube a una vez por hora porque:

1. **Grafana Cloud es Mimir/Prometheus y una muestra caduca a los 5 minutos.**
   Con 2 muestras al día los paneles y alertas verían "No Data" casi siempre.
   Se resuelve igualmente envolviendo las queries en `last_over_time(...[36h])`,
   pero con datos horarios los dashboards son legibles de verdad.
2. Permite ver *cuándo* se consumen los huevos, no solo cuántos quedan.
3. El costo en batería es aceptable (ver presupuesto energético).

El intervalo es una constante del firmware, fácil de cambiar.

## Hardware

### Plataforma: ESP32-C3 SuperMini

Elegida porque el usuario ya tiene varias unidades y una celda 18650. Las
alternativas evaluadas (FireBeetle 2 ESP32-E con deep sleep de 13 µA y carga
LiPo integrada; FireBeetle 2 ESP32-C6) se descartaron por no aportar nada que
justifique comprar hardware nuevo.

Consecuencias de esta elección, todas resueltas abajo: no tiene cargador de
litio, no tiene divisor de batería, y su deep sleep de fábrica es 30-50× peor
que el de una placa pensada para batería.

### Lista de compras

Ya disponible (costo 0): ESP32-C3 SuperMini, celda 18650, resorte de bolígrafo,
lámina de latón o clip metálico, cable USB-C, filamento PETG.

| # | Componente | Búsqueda en AliExpress | USD |
|---|---|---|---|
| 1 | Módulo VL53L1X, versión 3.3 V pequeña | `VL53L1X module GY-53L1` | 3-6 |
| 2 | TP4056 **con protección**, USB-C | `TP4056 USB-C protection DW01` | 0.60 |
| 3 | Resistencias 1 MΩ 1% (×2) | `1M ohm 1% resistor` | 0.20 |
| 4 | Miniprotoboard 170 puntos | `170 tie points mini breadboard` | 0.50 |
| 5 | Dupont hembra-hembra 10 cm (pack 40) | `dupont female female 10cm` | 1-2 |
| 6 | Imanes neodimio 6×3 mm (pack 20) | `neodymium magnet 6x3mm` | 2 |
| 7 | Tornillos M3×8 y M2×6 autorroscantes | `M2 M3 self tapping screws plastic` | 2 |
| | **Total** | | **~9-13** |

**Nota sobre el ítem 1:** hay que pedir explícitamente la versión pequeña de
3.3 V. Si el módulo trae un regulador AMS1117 (Iq ~5 mA), consume por sí solo
50× más que todo el resto del circuito en reposo y la batería dura semanas en
vez de meses. Plan B si llega el módulo equivocado: un load switch con MOSFET-P
(~USD 1) para cortarle la alimentación entera durante el sueño.

### Conexionado

Se evitan los pines I²C por defecto del C3 SuperMini: GPIO8 lleva el LED RGB y
es strapping pin, y GPIO9 es el botón BOOT. El ESP32-C3 tiene matriz GPIO libre,
así que I²C se remapea.

| Señal | Pin C3 | Va a |
|---|---|---|
| SDA | GPIO4 | VL53L1X SDA |
| SCL | GPIO5 | VL53L1X SCL |
| XSHUT | GPIO6 | VL53L1X XSHUT (bajo = standby ~5 µA) |
| ADC batería | GPIO3 | Nodo medio del divisor 1M/1M |
| Botón calibración | GPIO9 | Botón BOOT de la placa (pull-up interno) |
| 3V3 / GND | — | VL53L1X VCC / GND |

Cadena de alimentación:

```
18650 → TP4056 (B+/B-)
TP4056 (OUT+/OUT-) → pin 5V del C3 SuperMini → LDO onboard → 3V3
                   → divisor 1M/1M → GPIO3
```

**Riesgo abierto que hay que medir, no asumir:** alimentar el pin 5V con
3.7-4.2 V solo funciona si la placa lleva un LDO de baja caída (ME6211,
SGM2212, ~200 mV de dropout). Si lleva un AMS1117 (1.1 V de dropout), el
sistema muere por debajo de 4.4 V, es decir con la celda casi llena. Se verifica
empíricamente con fuente variable bajando la tensión hasta el brownout. Si
resulta ser AMS1117, la salida es alimentar el pin 3V3 desde un módulo HT7333
(Iq 4 µA) y **no** conectar USB y batería a la vez.

### Presupuesto energético

Con 18650 de 3000 mAh (2400 mAh utilizables), enviando cada hora:

| Concepto | mAh/día |
|---|---|
| Deep sleep del C3 SuperMini de fábrica (~500 µA) | 12.0 |
| 24 despiertos × ~6 s @ ~80 mA | 3.2 |
| VL53L1X en standby con XSHUT bajo | 0.12 |
| TP4056 en reposo + divisor de batería | 1.3 |
| **Total** | **~16.6** |

Eso son ~500 mAh/mes, más ~75 mAh/mes de autodescarga del 18650 → **~4 meses
entre cargas**.

**Optimización opcional:** el ~90% del consumo en deep sleep del C3 SuperMini es
el LED rojo de power. Raspándolo o desoldándolo, el sueño baja a ~100 µA y la
autonomía sube a **~8.5 meses**. Es un paso documentado en el README, no un
requisito.

Bajar a 2 envíos al día ahorra menos de lo que parece (el sueño domina): pasa de
4 a ~5 meses. No compensa perder la resolución temporal.

### Seguridad de la celda de litio

El 18650 es una celda desnuda sin PCM y va a estar en una cocina, descargándose
lentamente durante meses. El momento de mayor riesgo de una celda de litio es
recargarla después de una sobredescarga.

Tres capas, ninguna cara:

1. **TP4056 en su variante con protección** (DW01A + FS8205A): corte por
   sobredescarga (~2.5 V), sobrecarga y cortocircuito.
2. **Corte por software a 3.3 V**: leyendo GPIO3, el firmware entra en deep
   sleep indefinido mucho antes de que el DW01 tenga que actuar.
3. **Cuna impresa con contactos a presión**, sin soldar nunca sobre la celda.

Reglas a documentar en el README: rechazar cualquier celda por debajo de 2.5 V,
nunca cargar una celda hinchada o golpeada, y hacer la primera carga con el
aparato a la vista.

## Diseño 3D

Se usa **OpenSCAD** en lugar de Fusion 360: es texto plano, versionable y
diffeable en un repo público, y se puede editar directamente desde el editor.
Todas las cotas viven en `cad/params.scad`.

### Cabeza del sensor: cuatro piezas *(implementada)*

`cad/sensor_head.scad` genera las cuatro piezas según la variable `part`. Se
partió en cuatro por una razón concreta: **cada una tiene una orientación de
impresión distinta en la que no necesita ni un solo soporte.** Fundirlas en una
sola pieza obligaría a soportes en la cara dentada, que es justo la que necesita
precisión.

| Pieza | Descripción | Orientación |
|---|---|---|
| `clamp` | Mordaza en C sobre el borde, parametrizada solo por `rim_thickness`. Nervios antideslizantes y tornillo de apriete que rosca directo en el plástico. Pasacables en el puente. | De canto: es un prisma puro, cada capa es el mismo perfil en U |
| `plate` | Placa de bisagra: se atornilla a la cara lateral de la mordaza y lleva la corona Hirth. Aloja la cabeza del perno del pivote en un avellanado. | Plana, dientes hacia arriba |
| `pod` | Brazo con la corona Hirth complementaria en un extremo y el alojamiento del VL53L1X en el otro. Ventana óptica de Ø8 mm, 2 pilotos M2 y dos nervios que refuerzan la unión en T entre el brazo y la pared del PCB. | Plana, dientes hacia arriba |
| `knob` | Pomo lobulado con tuerca M3 embutida. Se afloja a mano, se gira el pod, se aprieta. | Plana |

**La articulación es un acoplamiento Hirth de paso 4°**: dos caras dentadas
idénticas, en cunas radiales, que engranan y se autocentran. Se eligió frente a
un trinquete de pasador y agujeros porque el Hirth es diente-valle continuo, sin
pared entre detentes; con pasadores, la pared entre agujeros a paso fino cae por
debajo del ancho de extrusión y deja de ser imprimible.

El flanco del diente mide `2·π·r·(paso/2)/360`, o sea que se estrecha hacia el
centro: es en el radio interior donde se redondea al imprimir. La primera
versión sacó de ahí la conclusión equivocada —subir `hirth_r_in` para que el
diente interior saliera definido— y eso infló la pieza entera, porque `r_in`
arrastra a `r_out` y `r_out` es el que fija el tamaño.

La regla correcta separa las dos cosas: **`hirth_r_out` manda en el TAMAÑO,
`detent_step` manda en la RESOLUCIÓN, y `hirth_r_in` solo tiene que dejar pasar
la cabeza del tornillo.** Que los dientes interiores salgan redondeados no
importa por dos razones: el par crece con el radio, así que esos dientes apenas
trabajan; y como las dos caras se imprimen con el mismo perfil, se redondean
igual y siguen engranando.

Con `r_out = 17` y paso 4° el flanco exterior mide 0,59 mm, cómodo para una
boquilla de 0,4. Aplicar la regla redujo la placa de 56 × 54 a 37 × 45 mm y el
pod de 52 × 68 a 34 × 46 mm, **sin perder ninguno de los cuatro detentes
válidos**, y de paso bajó la intrusión del sensor dentro de la canasta de 68 a
45 mm.

La corona se construye como un único `polyhedron` y no como la unión de 90
cuñas. No es microoptimización: unir 90 sólidos no convexos en CGAL tardaba más
de cinco minutos y agotaba el timeout; el poliedro tarda quince segundos.

**Las longitudes de tornillería las calcula el modelo y las imprime al
compilar**, para que no se queden obsoletas al tocar una cota. Con las cotas
actuales: pivote M3×12, placa-mordaza 2× M3×30, apriete M3×16 (sin tuerca), y
2× M2×6 autorroscante para el módulo. (Los mínimos calculados son 10,2 / 28,8 /
13,2 mm; se redondean al tamaño comercial siguiente.)

El orden de montaje importa, porque hay piezas que quedan cautivas: las dos
tuercas de la placa y el perno del pivote se colocan **antes** de atornillar la
placa a la mordaza. Una vez montada, la cara de la mordaza tapa la cabeza del
perno y le impide girar, así que el ángulo se cambia solo con el pomo, sin
llaves y sin sujetar nada por detrás.

Tamaños: la pieza mayor es el pod, 34 × 46 × 18 mm. El conjunto pesa ~35 g.

### El gancho al borde es una sola pieza de código

`cad/lib/rim_hook.scad` tiene el perfil en U que se cuelga del borde, y lo usan
tanto la mordaza del sensor como la caja de electrónica. Las dos patas son
parámetros porque cada pieza quiere lo contrario —la cabeza cuelga hacia dentro
y necesita pata interior larga; la caja cuelga hacia fuera y necesita pata
exterior larga— pero el hueco del borde, el apriete y los nervios son
literalmente el mismo código. Cambiar de canasta es tocar `rim_thickness` una
vez y que se arreglen las dos.

### Caja de electrónica: tres piezas *(implementada)*

`cad/electronics_box.scad`. Exterior 55 × 81 × 24 mm más las orejas.

| Pieza | Descripción | Orientación |
|---|---|---|
| `box` | Celda de pie contra una pared; TP4056 y ESP32-C3 tumbados contra el fondo en el vano de al lado, los dos alineados a la derecha para que sus USB-C salgan por el mismo costado. | Boca hacia arriba |
| `lid` | Tapa con ranuras de ventilación sobre la celda. | Plana |
| `hook` | Gancho al borde, con pata exterior larga: es donde se atornilla la caja. | De canto |

Decisiones que no son obvias:

- **Los módulos van tumbados, no de canto.** Así la caja mide 24 mm de fondo en
  vez de 32, y pegada a la pared hace menos palanca. Los ~13 mm que quedan
  libres por delante no se desperdician: son para el cableado Dupont, que
  abulta más que los propios módulos.
- **Nada se suelda a la celda.** El cable se suelda al muelle y a la lámina de
  latón *antes* de montarlos. El muelle además absorbe la variación real de
  longitud: el hueco de 70 mm acepta celdas de 62 a 69 mm, o sea tanto una sin
  proteger de 65 como una con PCB de protección de 69.
- **El tornillo de apriete del gancho va arriba del todo y la caja cuelga por
  debajo.** Si se solaparan, el saliente de 6 mm del tornillo chocaría contra el
  fondo de la caja y esta no apoyaría plana contra la pata.
- **Los tornillos de la tapa son dos bosses interiores por el lado de los
  módulos y dos orejas exteriores por el lado de la celda.** No hay bosses
  interiores en ese lado porque la celda ocupa el rincón entero.

El modelo se autocomprueba con `assert`: que el nicho del muelle no atraviese el
suelo, que ningún módulo pise un boss de la tapa ni la espina del gancho, y que
ningún tornillo del gancho caiga fuera de la pata o encima del de apriete.

### Piezas pendientes

| Pieza | Descripción |
|---|---|
| `strain_relief.scad` | Pasacables en ambos extremos del latiguillo de 20 cm. |

`cad/build.py` exporta los STL invocando el CLI de OpenSCAD, para que el repo no
guarde binarios generados. Imprime además el informe de geometría y las
longitudes de tornillo, y devuelve código de salida distinto de cero si alguna
pieza falla un `assert`.

**Impresión en Janus (Voron Trident):** PETG —la cocina tiene calor y grasa, el
PLA se deforma—, capa 0.2 mm, 4 perímetros, ~60 g, ~5 h. Diseñado sin soportes:
voladizos por debajo de 45° y la ventana del sensor resuelta con un puente.

⚠️ Janus tiene `[homing_override]` en Z que arranca con `G0 Z10` y cruza la cama
en diagonal. Hay que retirar cualquier pieza alta de la cama antes de lanzar el
print, o el homing estrella el cabezal.

## Firmware

Un solo `src/main.cpp`, sin FreeRTOS ni capas de abstracción. PlatformIO con
framework Arduino; el ESP32-C3 tiene soporte oficial en `platform-espressif32`,
sin necesidad del fork `pioarduino` que sí haría falta con un C6.

Ciclo por despertar (~6 s):

1. Despertar por timer.
2. XSHUT alto, inicializar VL53L1X, aplicar ROI reducido.
3. 20 lecturas → mediana, desviación estándar, conteo de lecturas válidas.
4. XSHUT bajo.
5. Leer batería en GPIO3. Si < 3.3 V → deep sleep indefinido.
6. Conectar WiFi, un POST HTTPS, desconectar.
7. Deep sleep.

Detalles:

- **Secretos fuera del repo.** `include/secrets.h` en `.gitignore`, con
  `include/secrets.h.example` commiteado. El repo es público: credenciales de
  WiFi y token de Grafana no pueden estar en el código.
- **Buffer de reintento en RTC slow memory.** Si falla el WiFi, la muestra se
  guarda con timestamp y se envía en el siguiente POST. Influx line protocol
  acepta timestamp explícito, así que un router reiniciándose no pierde datos.
  Esto también cubre la antena cerámica floja del C3 SuperMini, un defecto
  conocido de esas placas.
- **Modo calibración.** Botón BOOT presionado durante el arranque → 60 s
  imprimiendo distancia por serial a 2 Hz, para elegir el detente en vivo.
- Librería `pololu/VL53L1X` (soporta ROI y es ligera).

Línea enviada:

```
eggbasket,device=cocina distance_mm=142,stddev=3.1,valid=18,status=0,battery_mv=3912,rssi=-58,boots=412
```

`stddev`, `valid` y `status` no son adorno: son la señal de que el ángulo del
sensor está mal antes de que los datos de nivel se vuelvan basura.

## Grafana Cloud

**Datasource:** el Prometheus de la stack. Los datos entran por Influx y se
almacenan como series Prometheus con un label `__proxy_source__="influx"`
añadido automáticamente.

**Dashboard** (`grafana/dashboard.json`), con variables `d_vacia` y `d_llena`:

- Stat "Huevos estimados" — nivel calculado, con umbrales de color.
- Time series de distancia, escala invertida (más arriba = más huevos).
- Stat de batería en mV con umbral en 3.4 V.
- Time series de `stddev` y `valid` — salud de la medición.
- Time series de RSSI.

Todas las queries envueltas en `last_over_time(...[36h])` por la caducidad de
5 minutos de Prometheus.

**Dos reglas de alerta** (`grafana/alert-rules.yaml`), ambas a un contact point
de Telegram:

1. `nivel_pct < 25` sostenido durante 2 h → "Quedan pocos huevos".
   El `for: 2h` evita que una lectura mala dispare la alerta.
2. **No Data durante 36 h** → "El sensor de huevos no reporta".
   Sin esta segunda regla, una batería agotada es indistinguible de una canasta
   llena. Es el modo de fallo más probable del proyecto y el más silencioso.

## Estructura del repo

```
~/git/egg-basket-monitor/          público, MIT
├── README.md
├── LICENSE
├── .gitignore
├── firmware/
│   ├── platformio.ini
│   ├── include/secrets.h.example
│   └── src/main.cpp
├── cad/
│   ├── params.scad
│   ├── sensor_head.scad
│   ├── electronics_box.scad
│   ├── lib/geometry.scad
│   ├── lib/hirth.scad
│   ├── lib/rim_hook.scad
│   ├── strain_relief.scad
│   └── build.py
├── grafana/
│   ├── dashboard.json
│   └── alert-rules.yaml
└── docs/
    ├── bom.md
    ├── wiring.md
    ├── calibration.md
    └── superpowers/specs/
```

## Riesgos abiertos

| Riesgo | Impacto | Cómo se resuelve |
|---|---|---|
| El LDO del C3 SuperMini es un AMS1117 | El sistema muere con la celda al 70% | Medir el brownout con fuente variable. Salida: alimentar 3V3 desde un HT7333. |
| El módulo VL53L1X llega con AMS1117 | Autonomía de semanas en vez de meses | Load switch con MOSFET-P (~USD 1). |
| El ángulo diagonal da lecturas erráticas | El nivel estimado no sirve | Cuatro detentes (8-20°) + `stddev` como métrica de diagnóstico. Última salida: subir a VL53L5CX. |
| Solo hay 12° de ventana angular válida | Un error de montaje de 1 cm en la altura de la mordaza puede sacar al sensor del rango | Verificar con el modo de calibración por serial antes de dar por buena la posición. `geometry.scad` recalcula la ventana si se mide la canasta con más cuidado. |
| Retención del free tier de Grafana Cloud | Histórico corto | Verificar el límite vigente al configurar la stack. |

## Criterios de éxito

1. El dispositivo reporta a Grafana Cloud cada hora durante 7 días seguidos sin
   intervención.
2. La distancia reportada distingue de forma repetible al menos 4 niveles de
   llenado entre canasta vacía y llena.
3. Llega una notificación a Telegram al cruzar el umbral hacia abajo.
4. Llega una notificación a Telegram si el dispositivo se apaga 36 h.
5. Todas las piezas se imprimen sin soportes y se ensamblan sin soldar sobre la
   celda.
