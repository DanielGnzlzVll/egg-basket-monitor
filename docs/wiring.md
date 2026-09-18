# Cableado y pinout

Componentes: **ESP32-C3 SuperMini**, sensor ToF **VL53L1X** (módulo pequeño
GY-53L1, 3.3 V), cargador **TP4056 con protección**, celda **18650**, divisor
resistivo 1 MΩ/1 MΩ. Nada se suelda a la celda; ver `docs/bom.md` para el
resto de materiales y `cad/` para las piezas que sostienen todo esto físicamente.

## Diagramas

![Esquema de conexionado](img/wiring-schematic.svg)

![Cadena de alimentación](img/power-chain.svg)

Ambos son SVG locales (sin dependencias externas); se pueden abrir
directamente en el navegador o en cualquier editor de imágenes vectoriales
para imprimir o anotar.

## Tabla de pines (ESP32-C3 SuperMini)

| Señal | Pin C3 | Va a | Por qué este pin |
|---|---|---|---|
| SDA | GPIO4 | VL53L1X SDA | Se evita el I2C por defecto del C3: GPIO8 es el LED RGB integrado y GPIO9 es el botón BOOT |
| SCL | GPIO5 | VL53L1X SCL | Ídem |
| XSHUT | GPIO6 | VL53L1X XSHUT | Bajo = standby (~5 µA); el firmware lo maneja para apagar el sensor entre lecturas |
| ADC batería | GPIO3 | Nodo medio del divisor 1MΩ/1MΩ | Único ADC libre tras reservar 4/5/6 |
| Botón BOOT / config | GPIO9 | Botón BOOT de la placa | Reutilizado: sostenerlo al arrancar decide el modo (ver `docs/setup-tutorial.md`) |
| LED de estado | GPIO8 | LED RGB integrado de la placa | Uso nativo del pin; solo importa como strapping *durante* el reset, no después |
| 3V3 / GND | — | VL53L1X VCC / GND | |

## Cadena de alimentación

```
18650 (B+/B-) → TP4056 con protección (OUT+/OUT-)
             → pin 5V del ESP32-C3 SuperMini → LDO onboard → riel 3V3
                                              → divisor 1MΩ/1MΩ → GPIO3
```

**Riesgo abierto, a verificar con hardware en mano:** alimentar el pin 5V
directo con 3.7-4.2 V (el rango de una celda de litio) solo funciona bien si
la placa lleva un LDO de baja caída (p. ej. ME6211 o SGM2212, ~200 mV de
dropout). Si en cambio lleva un AMS1117 (1.1 V de dropout), el sistema se
apaga por debajo de ~4.4 V — es decir, con la celda todavía casi llena.

Cómo verificarlo: alimentar la placa desde una fuente de laboratorio variable
por el pin 5V, bajar la tensión lentamente desde 4.2 V y anotar en qué
voltaje el ESP32 hace brownout. Si el corte ocurre por encima de ~4.0 V, es
un AMS1117 y hay que cambiar de estrategia: alimentar el riel **3V3
directamente** desde un módulo HT7333 (quiescent ~4 µA) y no conectar USB y
batería al mismo tiempo mientras se usa esa ruta.

## Módulo VL53L1X: qué versión pedir

Explícitamente la versión **pequeña de 3.3 V**. Si el módulo trae un
regulador AMS1117 igual que el punto anterior, su corriente de reposo
(~5 mA) es 50 veces el resto del circuito combinado en deep sleep, y la
batería dura semanas en vez de meses. Plan B si llega el módulo equivocado:
un load switch con MOSFET-P (~USD 1) que le corte la alimentación completa
durante el sueño, comandado desde el mismo pin que hoy maneja XSHUT.

## Botón BOOT: un solo botón, tres funciones

GPIO9 ya es el botón BOOT físico de la placa. El firmware lo reutiliza según
cuánto tiempo se sostenga presionado **en el instante del arranque**
(power-on, reset, o wake por temporizador):

| Sostenido | Modo |
|---|---|
| No presionado | Ciclo normal: mide, envía, duerme |
| 3-8 s | Calibración: 60 s de distancia cruda por serial a 2 Hz |
| Más de 8 s | Portal de configuración WiFi/Grafana (`EggBasket-Setup`) |

El LED da feedback de en qué modo se entró — ver `docs/setup-tutorial.md`
para la tabla completa de patrones. Si no hay ninguna configuración WiFi
guardada (equipo recién flasheado), entra directo al portal sin necesidad de
sostener el botón.

## Notas de la corona ToF / cono del sensor

El emisor del VL53L1X dispara un cono fijo de 27° que no se puede estrechar;
solo el receptor admite ROI reducido (hasta 15° con 4×4 SPADs), que es lo que
usa este firmware. El ángulo físico de montaje se ajusta con la articulación
Hirth impresa (`cad/sensor_head.scad`), no por software. Los detalles de por
qué el rango útil es 8-20° desde la vertical están en
`docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`.
