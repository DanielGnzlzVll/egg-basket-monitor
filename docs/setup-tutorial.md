# Tutorial: flasheo y primera configuración

## 1. Requisitos

- [PlatformIO](https://platformio.org/) (extensión de VS Code, o `pip install
  platformio` para el CLI).
- Cable USB-C.
- Cableado armado según `docs/wiring.md`.
- Una cuenta de Grafana Cloud con:
  - La URL de push Influx (Prometheus remote-write con la ruta cambiada a
    `/api/v1/push/influx/write`; en algunas regiones también cambia el host
    de `prometheus` a `influx`).
  - Un **Instance ID** (aparece en la página de detalles del datasource).
  - Un **Access Policy token** con permiso de escritura (`metrics:write`).

Grafana Cloud, dashboard y alertas de Telegram se configuran aparte — ver
`grafana/` cuando esos artefactos estén listos. Este tutorial cubre solo el
firmware.

## 2. Flashear

```bash
cd firmware
pio run -t upload
pio device monitor  # opcional, para ver los logs
```

`platformio.ini` ya lista las librerías necesarias (`WiFiManager`,
`pololu/VL53L0X`, `Adafruit NeoPixel`); PlatformIO las descarga solo en el
primer build.

No hay ningún `secrets.h` que editar: toda la configuración se carga después,
por WiFi.

## 3. Primer arranque: portal de configuración

Como el dispositivo recién flasheado no tiene ninguna red WiFi guardada,
entra automáticamente al **portal de configuración** sin necesidad de tocar
ningún botón.

1. El LED da tres parpadeos azules y queda fijo en azul: el portal está
   activo.
2. Desde tu celular o laptop, conectate a la red WiFi **`EggBasket-Setup`**
   con la contraseña **`eggbasket2026`** (cambiala en
   `firmware/include/config.h` antes de flashear si te preocupa que quede en
   un repo público).
3. Se debería abrir automáticamente una página de configuración (portal
   cautivo). Si no abre sola, andá a `http://192.168.4.1` en el navegador.
4. Elegí tu red WiFi de la lista y completá:
   - **Password** de esa red.
   - **Influx write URL**: la URL completa de Grafana Cloud.
   - **Instance ID**.
   - **API token**.
   - **Nombre del dispositivo** (por defecto `cocina`; usalo si en algún
     momento tenés más de una canasta).
   - **Intervalo de sueño (minutos)**: 60 por defecto, entre 5 y 1440.
5. Guardá. El dispositivo reinicia solo y arranca su ciclo normal: mide,
   se conecta a tu red, y hace un POST a Grafana Cloud.

Si no completás el formulario en 5 minutos, el dispositivo reinicia y vuelve
a intentar (si no hay config guardada, vuelve a levantar el portal).

## 4. Verificar que está funcionando

**Por serial (lo más rápido para probar).** Con el cable USB puesto, abrí el
monitor:

```bash
cd firmware
pio device monitor
```

Cada ciclo normal imprime algo así:

```
=== Ciclo normal ===
Sensor: distancia=412 mm  stddev=1.8  validas=19/20
Bateria: 4.05 V
Conectando a WiFi 'MiCasa'...
WiFi conectado: IP=192.168.1.47  RSSI=-52dBm
Influx POST -> HTTP 204
POST a Grafana Cloud: OK
Durmiendo 60 minutos...
```

Un `HTTP 204` (o cualquier 2xx) confirma que Grafana Cloud aceptó el dato. Si
falla, imprime el código HTTP y el cuerpo de la respuesta con el motivo (por
ejemplo `401` = token o Instance ID mal cargados en el portal, `404` = URL de
push incorrecta).

**En Grafana Cloud.** Explore, elegí el datasource Prometheus de tu stack y
corré:

```
eggbasket_distance_mm
```

Debería aparecer una serie con el label `device="cocina"` (o el nombre que
hayas puesto) actualizándose cada vez que pasa el intervalo configurado.

## 5. Forzar un envío sin esperar el intervalo

No hace falta ningún botón especial: **un RESET simple** (o desconectar y
reconectar la alimentación) alcanza, siempre que no mantengas BOOT
presionado al mismo tiempo. El ciclo normal se dispara en cada arranque, sea
por el temporizador de deep sleep o por un reset manual.

Para iterar más rápido mientras probás, también podés bajar el **intervalo
de sueño** a 5 minutos (el mínimo) desde el portal de configuración (sección
3, paso 4) en vez de resetear a mano cada vez.

## 6. Volver a entrar a un modo especial más adelante

Con la placa ya configurada, para forzar un modo especial hay que sostener
el botón **BOOT** justo cuando el dispositivo arranca (ver
`docs/wiring.md` para dónde está ese botón):

1. Mantené BOOT presionado.
2. Sin soltarlo, presioná y soltá **RESET** (o desconectá y reconectá la
   alimentación).
3. Seguí sosteniendo BOOT: el LED parpadea lento mientras cuenta.
   - Soltalo entre los 3 y 8 segundos → **modo calibración** (dos parpadeos
     verdes, después 60 s imprimiendo distancia cruda por serial a 2 Hz).
   - Seguí sosteniendo más de 8 segundos → **modo configuración** (tres
     parpadeos azules, vuelve a levantar `EggBasket-Setup`; tus credenciales
     WiFi anteriores no se borran hasta que guardes un formulario nuevo).

## 7. Tabla de patrones de LED

| Patrón | Significado |
|---|---|
| Parpadeo lento blanco/azul | Botón BOOT detectado, contando cuánto se sostiene |
| Dos parpadeos verdes | Entró a modo calibración |
| Tres parpadeos azules, luego fijo azul | Entró a modo configuración, portal activo |
| Un parpadeo verde corto | POST a Grafana exitoso, yéndose a dormir |
| Un parpadeo rojo corto | POST falló, muestra guardada para reintentar, yéndose a dormir |
| Tres parpadeos rojos | Batería bajo 3.3 V, entrando a sueño indefinido |

Si tu placa "C3 SuperMini" trae un LED simple de un solo color en vez de un
RGB direccionable, los mismos eventos se traducen a parpadeos simples (ver
`firmware/include/config.h`, `STATUS_LED_IS_NEOPIXEL`).

## 8. Qué hacer si algo no anda

- **El portal no abre / no aparece la red `EggBasket-Setup`.** Revisá el
  monitor serial (`pio device monitor`) para ver si el arranque detectó el
  modo correcto. Confirmá el cableado del botón BOOT (es el que ya trae la
  placa; no hay que cablear nada extra).
- **Conecta a WiFi pero nunca llegan datos a Grafana.** Con el monitor serial
  abierto, forzá un reset y mirá el log del ciclo normal (sección 4): el
  código HTTP que imprime `Influx POST -> HTTP ...` dice exactamente qué
  rechazó Grafana Cloud (401/403 = credenciales, 404 = URL, timeout = sin
  internet real aunque el WiFi haya conectado).
- **El sensor no inicializa** (mensaje de error en modo calibración, o
  "Sensor: fallo de lectura" en el log del ciclo normal): revisar
  `docs/wiring.md`, sección "Módulo del sensor", y confirmar que el chip es
  un VL53L0X (TOF200C); con un VL53L1X hay que volver a su librería.
