# Lista de materiales

Todo son módulos ya hechos que se conectan con cable Dupont. **No hay PCB
custom** y no hace falta soldar nada salvo dos resistencias y los dos contactos
de la celda (nunca sobre la celda).

## Ya lo tienes — coste 0

| Componente | Nota |
|---|---|
| ESP32-C3 SuperMini | Con sus limitaciones ya contempladas en el diseño: sin cargador de litio, sin divisor de batería, deep sleep de fábrica ~500 µA |
| Celda 18650 | El hueco de la caja acepta de 62 a 69 mm, así que da igual si es protegida o no |
| Resorte de bolígrafo | Contacto negativo. Es lo que absorbe la diferencia de largo entre celdas |
| Lámina de latón o clip metálico | Contacto positivo |
| Cable USB-C | Para cargar y para flashear |
| Filamento PETG | ~90 g entre las siete piezas. PETG y no PLA: la cocina tiene calor y grasa |

## Hay que comprar — AliExpress, ~USD 8-12

| # | Componente | Búsqueda | USD |
|---|---|---|---|
| 1 | Módulo VL53L1X, versión pequeña de 3.3 V | `VL53L1X module GY-53L1` | 3-6 |
| 2 | TP4056 **con protección**, USB-C | `TP4056 USB-C protection DW01` | 0.60 |
| 3 | Resistencias 1 MΩ 1% (×2) | `1M ohm 1% resistor` | 0.20 |
| 4 | Dupont hembra-hembra 20 cm (pack 40) | `dupont female female 20cm` | 1-2 |
| 5 | Termorretráctil surtido | `heat shrink tube assortment` | 1 |
| 6 | Tornillería M3 + M2 (ver abajo) | `M3 hex socket screw assortment kit` | 2-3 |

### Los dos ítems que importan

**El VL53L1X (ítem 1).** Hay que pedir explícitamente la versión pequeña de
3.3 V. Si el módulo trae un regulador AMS1117, su corriente de reposo (~5 mA) es
50× todo el resto del circuito en reposo, y la batería pasa de durar meses a
durar semanas. Plan B si llega el equivocado: un load switch con MOSFET-P (~USD 1)
que le corte la alimentación entera durante el sueño.

**El TP4056 (ítem 2).** Tiene que ser la variante **con protección** (lleva un
DW01A y un FS8205A junto al chip principal). La versión sin protección es un
céntimo más barata y deja la celda sin corte por sobredescarga ni por
cortocircuito. No es negociable con una celda desnuda.

## Tornillería

Las longitudes las calcula el propio modelo al compilar (`python cad/build.py`),
así que si tocas una cota del CAD, vuelve a mirar aquí. Con las cotas actuales:

| Dónde | Qué | Cantidad |
|---|---|---|
| Pivote de la articulación | M3×12 | 1 |
| Placa → mordaza | M3×30 | 2 |
| Apriete de los dos ganchos | M3×16 | 2 |
| Caja → gancho | M3×14 | 2 |
| Tapa de la caja | M3×10 autorroscante (rosca directo en el plástico) | 4 |
| Módulo VL53L1X al pod | M2×6 autorroscante | 2 |
| Tuercas M3 | 1 en el pomo, 2 en la placa, 2 en la espina de la caja | 5 |

Los tornillos de apriete de los ganchos y los de la tapa roscan directamente en
el plástico: no llevan tuerca a propósito, porque con tuerca harían falta cabeza
y tuerca las dos por fuera y nada haría de tope.

## Dónde van las dos resistencias

El ESP32-C3 SuperMini no trae divisor de batería, así que hace falta uno de
1 MΩ/1 MΩ para leer la tensión de la celda por GPIO3. **No lleva protoboard**:
son dos componentes, se sueldan en línea sobre un Dupont y se aíslan con
termorretráctil. Una miniprotoboard de 170 puntos mide 47×35 mm y no cabe en el
vano de la caja, que tiene 29 mm de ancho.

El divisor consume 2.1 µA permanentes, despreciable frente a los ~500 µA del
deep sleep de la placa.

## Lo que ya NO hace falta

Dos ítems que estaban en la primera versión de la lista y han caído al avanzar
el CAD:

- **Imanes de neodimio 6×3.** La caja iba a fijarse al mueble con imanes. Ahora
  cuelga del borde con su propio gancho impreso, igual que la cabeza del sensor.
- **Miniprotoboard de 170 puntos.** Ver arriba: no cabe y no hace falta.

## Piezas impresas

Siete, ninguna necesita soportes. `python cad/build.py` las exporta todas a
`cad/out/`.

| Pieza | Orientación |
|---|---|
| `clamp` | De canto |
| `plate` | Plana, dientes hacia arriba |
| `pod` | Plana, dientes hacia arriba |
| `knob` | Plana |
| `box` | Boca hacia arriba |
| `lid` | Plana |
| `hook` | De canto |

⚠️ **Janus (Voron Trident)** tiene `[homing_override]` en Z que arranca con
`G0 Z10` y cruza la cama en diagonal. Retira cualquier pieza alta de la cama
antes de lanzar el print o un `G28` pelado estrella el cabezal.
