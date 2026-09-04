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
3. Rótula con detentes cada 5° entre 15° y 60° en la pieza impresa, para
   corregir el ángulo sin reimprimir. El ángulo es el parámetro que más
   probablemente falle a la primera.

### Montaje: cabeza en el borde, midiendo en diagonal

El sensor se sujeta al borde de la canasta y apunta en diagonal hacia el fondo
opuesto, no verticalmente desde arriba. Esto deja libre la boca de la canasta,
que es por donde se ponen y sacan los huevos.

La electrónica **no** va en el borde. Un 18650 con su cuna pesa ~70 g y volcaría
una canasta liviana. El sistema se parte en dos cuerpos unidos por un latiguillo
Dupont de 20 cm:

- **Cabeza del sensor** (~15 g): mordaza en C + rótula + VL53L1X.
- **Caja de electrónica**: MCU, celda, TP4056. Apoyada en la mesa detrás de la
  canasta o fijada con imanes al mueble.

Beneficio secundario: la canasta se puede levantar y lavar, y la celda de litio
no queda suspendida sobre la comida.

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

| Pieza | Descripción |
|---|---|
| `sensor_head.scad` | Mordaza en C sobre el borde de la canasta, parametrizada por `rim_thickness`. Rótula con detentes cada 5° entre 15° y 60°. Ventana de 12 mm y alojamiento del módulo VL53L1X con 2 tornillos M2. |
| `battery_cradle.scad` | Cuna para 18650. Nicho para resorte de bolígrafo en el negativo (absorbe la tolerancia real de 64.5-65.5 mm de largo), lámina de latón en el positivo, tornillo M2 que pinza el cable Dupont contra cada contacto. Dimensionada también para aceptar un portapilas comercial si los contactos impresos resultan intermitentes. |
| `enclosure.scad` | Aloja MCU, cuna y TP4056. Aberturas para ambos USB-C en la misma cara, acceso al botón BOOT, ventilación sobre la celda, nichos para imanes 6×3 en la pared trasera, tapa con 4 tornillos M3. |
| `strain_relief.scad` | Pasacables en ambos extremos del latiguillo de 20 cm. |

`cad/build.py` exporta los STL invocando el CLI de OpenSCAD, para que el repo no
guarde binarios generados.

**Impresión en Janus (Voron Trident):** PETG —la cocina tiene calor y grasa, el
PLA se deforma—, capa 0.2 mm, 4 perímetros, ~60 g, ~5 h. Diseñado sin soportes:
voladizos por debajo de 45° y la ventana del sensor resuelta con un puente.

⚠️ Janus tiene `[homing_override]` en Z que arranca con `G0 Z10` y cruza la cama
en diagonal. Hay que retirar cualquier pieza alta de la cama antes de lanzar el
print, o el homing estrella el cabezal.

**Bloqueante:** faltan las medidas de la canasta (boca, alto, espesor y material
del borde, presencia de repisa encima). Los `.scad` se escriben con valores por
defecto razonables; no se exportan STL hasta tener las cotas reales.

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
  imprimiendo distancia por serial a 2 Hz, para apuntar la rótula en vivo.
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
│   ├── battery_cradle.scad
│   ├── enclosure.scad
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
| El ángulo diagonal da lecturas erráticas | El nivel estimado no sirve | Rótula con detentes + `stddev` como métrica de diagnóstico. Última salida: subir a VL53L5CX. |
| Faltan las medidas de la canasta | No se pueden exportar STL | Pendiente del usuario. Los `.scad` son paramétricos. |
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
