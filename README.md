# Egg Basket Monitor

Sensor de nivel para una canasta de huevos: mide distancia con un ToF
VL53L1X, duerme casi todo el tiempo en un ESP32-C3 SuperMini a batería, y
manda una lectura por hora a Grafana Cloud vía Influx line protocol. Sin PCB
a medida, sin infraestructura intermedia, sin conteo exacto de huevos —
solo una alerta antes de que se acaben.

Ver el diseño completo en
[`docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`](docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md)
y la extensión de provisioning WiFi/config web en
[`docs/superpowers/specs/2026-09-17-firmware-wifi-config-design.md`](docs/superpowers/specs/2026-09-17-firmware-wifi-config-design.md).

## Estructura del repo

```
cad/        Piezas paramétricas en OpenSCAD (mordaza, articulación, caja de electrónica)
firmware/   Proyecto PlatformIO (ESP32-C3, Arduino framework)
docs/       Wiring, tutorial de setup, calibración, lista de materiales
grafana/    Dashboard y reglas de alerta (pendiente)
```

## Firmware

- [`docs/wiring.md`](docs/wiring.md) — pinout completo y diagramas de
  conexionado (esquema + cadena de alimentación).
- [`docs/setup-tutorial.md`](docs/setup-tutorial.md) — flasheo con
  PlatformIO y primera configuración vía el portal WiFi cautivo
  (`EggBasket-Setup`).
- [`docs/calibration.md`](docs/calibration.md) — cómo elegir el ángulo
  correcto de montaje del sensor con el modo de calibración por serial.

No hay ningún archivo de credenciales en el repo: WiFi, endpoint de Grafana
Cloud, token, tag del dispositivo e intervalo de sueño se cargan una vez, por
WiFi, desde un formulario que sirve el propio dispositivo. Todo queda en NVS
(flash interna), no en el código fuente.

**Estado:** el firmware se escribió sin el hardware físico presente
(desarrollo en `C:\Users\DanielGonzalez\git\egg-basket-monitor` sin
PlatformIO CLI instalado localmente para compilar). Falta compilar y probar
en la placa real antes de darlo por bueno — ver "Riesgos abiertos" en el
spec de diseño.

## Hardware

Lista de materiales completa en [`docs/bom.md`](docs/bom.md). Resumen: ya
tenés el ESP32-C3 SuperMini y la celda 18650; hay que comprar el módulo
VL53L1X (versión pequeña de 3.3 V), un TP4056 con protección, dos
resistencias de 1 MΩ y tornillería métrica — todo por ~USD 8-12.

## Licencia

MIT.
