# Firmware, WiFi provisioning y config web — Diseño

**Fecha:** 2026-09-17
**Estado:** aprobado, pasando a implementación directa (sin plan intermedio separado)
**Contexto:** extiende [2026-09-04-egg-basket-monitor-design.md](2026-09-04-egg-basket-monitor-design.md). El CAD ya está implementado; el firmware no existía hasta ahora.

## Cambio respecto al diseño original

El diseño del 2026-09-04 asumía credenciales de WiFi y Grafana en un
`include/secrets.h` compilado dentro del firmware (gitignored, con un
`.example` commiteado). Eso obliga a reflashear para cambiar de red WiFi o
rotar el token de Grafana.

Se reemplaza por **configuración en runtime vía portal cautivo**: el
dispositivo, si no tiene configuración guardada (o si se le pide
explícitamente), levanta su propio punto de acceso WiFi con un formulario web
donde se cargan tanto las credenciales de WiFi como los parámetros de Grafana
Cloud y el intervalo de sueño. Todo se guarda en NVS (flash) vía la librería
`Preferences` de Arduino-ESP32. `secrets.h` desaparece del diseño.

## Sensor: corrección de nombre

El sensor es el **VL53L1X** de STMicroelectronics (no "BL53LD", una
transcripción incorrecta). Ya estaba fijado por el diseño original con una
justificación detallada (ROI configurable para estrechar el cono del receptor
en el montaje diagonal). Se mantiene sin cambios: mismo pinout, misma
librería (`pololu/VL53L1X`), mismo modo `short`.

## Máquina de estados de arranque

Cada arranque (wake por timer, power-on, o reset manual) ejecuta esta
decisión antes de cualquier otra cosa:

```
setup()
  │
  ├─ Leer GPIO9 (BOOT) durante una ventana de 8-9 s desde el arranque
  │
  ├─ Sin NVS de WiFi guardada           → CONFIG_MODE (primer arranque)
  ├─ BOOT sostenido 3-8 s               → CALIBRATION_MODE (ya existía)
  ├─ BOOT sostenido > 8 s               → CONFIG_MODE (reconfigurar)
  └─ Ningún botón / NVS válida          → NORMAL_MODE (ciclo de medición)
```

La ventana de detección de 8-9 s hace que el usuario nunca tenga que adivinar
cuánto aguantar: se limpia con feedback de LED (ver abajo). El costo en
batería de esta ventana es despreciable porque solo se ejecuta lectura de
GPIO, sin radio ni sensor activos.

### Feedback por LED (GPIO8, RGB integrado del C3 SuperMini)

El original evitaba GPIO8 para I2C por ser pin de strapping, pero como salida
de estado post-arranque es su uso nativo en la placa y no interfiere con el
boot (el strapping solo importa durante el reset).

| Evento | Patrón |
|---|---|
| Botón detectado, aún en ventana de decisión | Parpadeo lento blanco/azul mientras se cuenta |
| Entra a `CALIBRATION_MODE` | Dos parpadeos verdes |
| Entra a `CONFIG_MODE` | Tres parpadeos azules, luego encendido fijo mientras el AP está activo |
| POST a Grafana exitoso | Un parpadeo verde corto antes de dormir |
| POST fallido (buffer a RTC) | Un parpadeo rojo corto antes de dormir |
| Batería < 3.3 V, corte | Tres parpadeos rojos antes del sueño indefinido |

## CONFIG_MODE: portal cautivo

Implementado con **WiFiManager** (tzapu/WiFiManager vía PlatformIO
`lib_deps`), no un servidor a medida: maneja AP, DNS captivo y el formulario
de selección de red, y admite parámetros custom (`WiFiManagerParameter`) para
todo lo que no es WiFi.

- **SSID del AP:** `EggBasket-Setup`
- **Password del AP:** `eggbasket2026` (constante en `src/config.h`,
  documentada en el tutorial, cambiable antes de flashear)
- **Timeout del portal:** 5 minutos sin actividad → `ESP.restart()` y vuelve
  al ciclo normal. Evita drenar la batería si el modo se activó sin querer.
- **Un solo formulario combinado**, con estos campos además de SSID/password
  de WiFi:

  | Campo | Tipo | Notas |
  |---|---|---|
  | Influx write URL | texto, requerido | URL completa, p.ej. `https://influx-prod-XX.grafana.net/api/v1/push/influx/write` |
  | Instance ID (usuario Basic Auth) | texto, requerido | |
  | API token (password Basic Auth) | password, requerido, maxlength 150 | Access Policy token de Grafana Cloud |
  | Device tag | texto, default `cocina` | Va en el line protocol como `device=<tag>` |
  | Intervalo de sueño (minutos) | numérico, default 60, rango 5-1440 | |

- Al guardar: todos los campos se escriben en `Preferences` (namespace
  `cfg`), y el dispositivo reinicia. El próximo arranque entra en
  `NORMAL_MODE` porque ya hay WiFi guardado y no hay botón presionado.
- Validación: `required` en HTML más chequeo en el callback de guardado
  (ningún campo obligatorio vacío); si falla, el portal no cierra y muestra
  el formulario de nuevo.

**Riesgo aceptado y documentado:** el password del AP es una constante en un
repo público. Es un riesgo bajo (ventana de minutos, en la propia casa) pero
se documenta explícitamente en el README para que quien clone el repo decida
si quiere cambiarlo.

## NORMAL_MODE: ciclo de medición (sin cambios de fondo respecto al original)

1. `XSHUT` alto, iniciar VL53L1X, aplicar ROI reducido, modo `short`.
2. 20 lecturas → mediana, desviación estándar, conteo de válidas.
3. `XSHUT` bajo (standby, ~5 µA).
4. Leer batería en GPIO3 vía el divisor 1M/1M. Si `< 3.3 V`: LED de corte,
   `esp_deep_sleep_start()` sin timer (sueño indefinido), fin.
5. Cargar config de `Preferences`. `WiFi.begin(ssid, pass)`, esperar conexión
   con timeout de 15 s.
6. Si conecta: armar línea(s) Influx (la actual + cualquiera pendiente en el
   buffer RTC), POST HTTPS con Basic Auth, `text/plain`.
   - Éxito (2xx): vaciar buffer RTC, LED verde.
   - Fallo (timeout, no-2xx, sin WiFi): guardar la muestra actual en el
     buffer RTC (anillo de 3, la más vieja se descarta si está lleno), LED
     rojo.
7. `WiFi.disconnect(true)`.
8. `esp_sleep_enable_timer_wakeup(sleep_minutes * 60 * 1e6)`,
   `esp_deep_sleep_start()`.

### Buffer de reintento en RTC

`RTC_DATA_ATTR` struct con 3 slots `{distance_mm, stddev_x10, valid_count,
battery_mv, minutes_ago, occupied}`. `minutes_ago` se incrementa en cada
ciclo fallido adicional y se usa para calcular el timestamp explícito en la
línea Influx reenviada (Influx line protocol acepta timestamp en el mismo
POST). Esto sobrevive deep sleep porque la RTC slow memory no se borra entre
ciclos (solo se borra con power-on-reset real, ej. batería quitada).

### Línea Influx

```
eggbasket,device=<tag> distance_mm=<n>,stddev=<f>,valid=<n>,status=<0|1>,battery_mv=<n>,rssi=<n>,boots=<n> [timestamp_ns]
```

`status=1` marca una muestra reenviada desde el buffer (para poder filtrarlas
o auditarlas en Grafana si hace falta). `boots` es un contador persistido en
RTC memory que sobrevive deep sleep (se resetea solo con power-on-reset).

## Estructura del firmware

```
firmware/
├── platformio.ini
├── include/
│   └── config.h            # constantes: pines, SSID/pass del AP, timeouts
├── src/
│   ├── main.cpp             # setup() con la máquina de estados de arranque
│   ├── boot_mode.h/.cpp      # detección de BOOT sostenido + LED feedback
│   ├── sensor.h/.cpp         # init VL53L1X, ROI, 20 lecturas, mediana/stddev
│   ├── settings.h/.cpp       # wrapper de Preferences (NVS): get/set config
│   ├── portal.h/.cpp         # WiFiManager + parámetros custom + callback de guardado
│   ├── telemetry.h/.cpp      # línea Influx, POST HTTPS, buffer RTC de reintento
│   └── power.h/.cpp          # lectura de batería, deep sleep, LED
```

Sin `secrets.h`: no hay ningún credential en el repo, todo vive en NVS del
dispositivo en runtime.

## Pinout (sin cambios respecto al original, se documenta con diagrama)

| Señal | Pin C3 SuperMini | Va a |
|---|---|---|
| SDA | GPIO4 | VL53L1X SDA |
| SCL | GPIO5 | VL53L1X SCL |
| XSHUT | GPIO6 | VL53L1X XSHUT |
| ADC batería | GPIO3 | Nodo medio divisor 1MΩ/1MΩ |
| Botón BOOT/config | GPIO9 | Botón BOOT de la placa (pull-up interno) |
| LED de estado | GPIO8 | RGB integrado de la placa |
| 3V3 / GND | — | VL53L1X VCC / GND, extremo superior del divisor a 3V3, inferior a GND |

Se agregan a `docs/wiring.md`: tabla (la de arriba), diagrama de conexión
tipo breadboard (SVG) y diagrama esquemático simplificado (SVG), ambos
locales en `docs/img/`.

## Documentación nueva

- `docs/wiring.md`: pinout + diagramas SVG + cadena de alimentación.
- `docs/setup-tutorial.md`: flasheo con PlatformIO, primer arranque, conexión
  al AP `EggBasket-Setup`, llenado del formulario, verificación en Grafana
  Cloud, tabla de patrones de LED, cómo volver a `CONFIG_MODE` o
  `CALIBRATION_MODE`.
- `docs/calibration.md`: uso del modo de calibración por serial (ya descrito
  en el spec original) para elegir el detente de la articulación Hirth.
- `README.md`: sección "Firmware" enlazando a los tres documentos de arriba.

## Fuera de alcance (sin cambios respecto al original)

- PCB a medida, conteo exacto de huevos, multi-canasta, Home Assistant.
- Cifrado de flash / NVS encriptada: el token de Grafana queda en NVS en
  texto plano. Riesgo aceptado para un dispositivo doméstico; se documenta.
- Verificación en hardware real: este documento y el código que sigue se
  desarrollan sin el dispositivo físico presente. La compilación con
  PlatformIO no se pudo verificar en esta máquina (CLI no instalado). Queda
  pendiente compilar y probar en hardware antes de dar el firmware por
  bueno.

## Criterios de éxito (agregados a los del spec original)

6. Desde cero (sin NVS), el dispositivo levanta `EggBasket-Setup`, acepta el
   formulario combinado, guarda config y arranca en `NORMAL_MODE` sin
   reflashear.
7. Mantener BOOT > 8 s en cualquier arranque reabre el portal sin perder la
   config anterior hasta que se guarde una nueva.
8. Una falla de POST no pierde la muestra: aparece en el siguiente envío
   exitoso con su timestamp original.
