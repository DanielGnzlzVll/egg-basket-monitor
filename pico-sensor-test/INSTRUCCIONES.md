# Instrucciones: cargar la prueba en la RP2040-Zero desde VS Code

Paso a paso para dejar la Waveshare RP2040-Zero corriendo la prueba del
sensor y ver sus logs, usando VS Code en Windows. En este documento "la
placa" es la RP2040-Zero; MicroPico y MicroPython la tratan igual que a una
Raspberry Pi Pico porque llevan el mismo chip, así que en menús y mensajes
verás "Pico".

Hay dos cargas distintas y conviene no mezclarlas:

1. **MicroPython** (el "firmware" de la placa, un archivo `.uf2`). Se instala
   **una sola vez** y es lo único que necesita el modo bootloader.
2. **Los scripts de la prueba** (`main.py`, `vl53l0x.py`, `vl53l1x.py`, `log.py`). Se suben
   por USB-serial con la extensión MicroPico, sin bootloader, tantas veces
   como haga falta.

## 0. Material

- Waveshare RP2040-Zero.
- Cable **USB-C de datos**. Muchos cables de carga no llevan los hilos de
  datos: si la placa no aparece por ningún lado, lo primero es cambiar el cable.
- Módulo VL53L1X y 5 cables Dupont, conectados como en el
  [diagrama](wiring.svg) (ver también el [README](README.md#conexiones)).
  La RP2040-Zero viene sin pines soldados: hace falta soldarle una tira de
  pines (o al menos los 7 primeros del borde izquierdo) para usar Dupont.
- Antes de conectarla, lee
  [Antes de conectar la placa nueva](README.md#antes-de-conectar-la-placa-nueva)
  en el README: la Pico anterior se quemó y conviene descartar el sensor.

## 1. Extensiones de VS Code

| Extensión | ID | ¿Hace falta? |
|---|---|---|
| **MicroPico** (paulober) | `paulober.pico-w-go` | **Sí.** Conecta con la placa, sube archivos, abre la consola (REPL) donde salen los logs |
| Python (Microsoft) | `ms-python.python` | Recomendada: resaltado y análisis del código |
| Pylance (Microsoft) | `ms-python.vscode-pylance` | Recomendada: autocompletado de `machine`, `Pin`, `I2C` con los stubs que instala MicroPico |

Instálalas desde la vista de extensiones (Ctrl+Shift+X) buscando por nombre,
o desde una terminal de Windows (PowerShell):

```
code --install-extension paulober.pico-w-go
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
```

No hace falta el SDK de C de la Pico ni la extensión oficial "Raspberry Pi
Pico": eso es para programar en C/C++. Tampoco hace falta instalar drivers:
Windows 10/11 reconoce la placa como puerto serie USB por sí solo.

### Importante: VS Code en Windows, no en WSL

El repo está clonado dentro de WSL (`/home/daniel/egg-basket-monitor`), pero
**WSL no ve los puertos USB de Windows**. Si abres la carpeta en una ventana
"WSL: Ubuntu" de VS Code, MicroPico nunca encontrará la placa.

Abre la carpeta en una ventana **normal de Windows**:

1. En VS Code: *File → Open Folder...*
2. Pega esta ruta:
   ```
   \\wsl.localhost\Ubuntu\home\daniel\egg-basket-monitor\pico-sensor-test
   ```
3. Si VS Code ofrece "Reopen in WSL", di que **no**.

La esquina inferior izquierda **no** debe mostrar "WSL: Ubuntu". Si MicroPico
da problemas leyendo la ruta de red `\\wsl.localhost`, copia la carpeta
`pico-sensor-test` a una ruta de Windows (por ejemplo
`C:\Users\DanielGonzalez\pico-sensor-test`) y abre esa.

## 2. Modo bootloader e instalación de MicroPython

Sólo la primera vez, o para actualizar/reinstalar MicroPython.

**Descargar el firmware:** <https://micropython.org/download/RPI_PICO/> →
la última versión estable, archivo `.uf2`. Es el firmware de la Raspberry Pi
Pico normal, que es el que recomienda Waveshare para la RP2040-Zero: mismo
chip y misma flash de 2 MB. No uses el de la Pico W ni el de la Pico 2.

**Entrar en modo bootloader.** La RP2040-Zero tiene dos botones junto al
conector USB-C: **BOOT** y **RESET**. Con la placa ya conectada:

1. **Mantén pulsado BOOT.**
2. **Pulsa y suelta RESET.**
3. **Suelta BOOT.**

O, con la placa desconectada: mantén BOOT, conecta el cable USB, suelta BOOT.

Windows monta una unidad nueva llamada **`RPI-RP2`** con dos archivos
(`INDEX.HTM` e `INFO_UF2.TXT`). Eso es el bootloader: vive en la ROM del
RP2040, así que siempre está disponible y no se puede "brickear" la placa.

**Instalar:** arrastra el `.uf2` descargado a la unidad `RPI-RP2`. La copia
tarda unos segundos, la unidad desaparece sola y la placa se reinicia con
MicroPython. Que Windows diga que el dispositivo se desconectó es normal.

También se entra al bootloader sin tocar los botones, si ya tiene
MicroPython: en la consola de MicroPico escribe
`import machine; machine.bootloader()`.

**El botón RESET solo** (sin BOOT) reinicia la placa: vuelve a ejecutar
`main.py` desde cero, como desconectar y conectar el USB. Útil para repetir la
prueba sin tocar el cable.

## 3. Subir la prueba con MicroPico

1. Conecta la placa normalmente (sin BOOT).
2. Abre en VS Code la carpeta del repo, **`egg-basket-monitor`** (la
   carpeta padre). Ya está configurada: `.vscode/settings.json` le dice a
   MicroPico que suba sólo los `.py` de `pico-sensor-test/` a la raíz de la
   placa (ver "Qué se sube a la placa" abajo). La primera vez en un PC
   nuevo, Ctrl+Shift+P → **`MicroPico: Initialize MicroPico Project`**
   para descargar los stubs del autocompletado; respeta la configuración
   que ya existe.
3. En la barra de estado inferior debe aparecer **"Pico Connected"** (con una
   marca ✓). Si dice "Pico Disconnected", mira el apartado 6.
4. Ctrl+Shift+P → **`MicroPico: Upload Project to Board`**. Sube `main.py`,
   `vl53l0x.py`, `vl53l1x.py` y `log.py` a la flash de la placa. Tarda unos
   segundos; las siguientes veces sólo sube lo que cambió.
5. Reinicia para que arranque `main.py`: Ctrl+Shift+P →
   **`MicroPico: Reset > Soft`**, o haz clic en la consola vREPL y pulsa
   **Ctrl+D**. O pulsa el botón RESET de la placa (esto corta la conexión
   serie un instante; MicroPico reconecta solo).

### Qué se sube a la placa

Sin configurar, "Upload Project" sube la carpeta abierta entera con todos
los `.py`, `.json`, `.txt`, `.html`… que encuentre, incluidas cachés como
`.mypy_cache/` (cientos de `.json`) y hasta `cad/build.py`. Por eso tardaba
tanto y dejaba los módulos en subcarpetas donde MicroPython no los encuentra.

La configuración de `egg-basket-monitor/.vscode/settings.json` lo limita:

```json
"micropico.syncFolder": "pico-sensor-test",
"micropico.syncAllFileTypes": false,
"micropico.syncFileTypes": ["py"],
"micropico.pyIgnore": ["**/.vscode", "**/.git", "**/.gitignore", "**/__pycache__",
                       "**/.mypy_cache", "**/env", "**/venv", "**/.venv", "**/.idea"]
```

- `syncFolder`: sólo se sube `pico-sensor-test/`, y su contenido va a la
  **raíz** de la placa (`pico-sensor-test/log.py` → `/log.py`).
- `syncFileTypes`: sólo `.py`; README, INSTRUCCIONES y el SVG se quedan fuera.
- `pyIgnore`: cachés y carpetas de entorno. Sólo acepta nombres con `**/`
  delante, no comodines como `**/*.md`.

`.vscode/` está en el `.gitignore` del repo, así que esta configuración vive
sólo en tu copia local. Si abres directamente la carpeta `pico-sensor-test`
en vez de la del repo también funciona: la carpeta abierta es la raíz y con
los tipos por defecto de MicroPico los `.md` y el `.svg` ya no se suben.

Si antes se subió basura a la placa, Ctrl+Shift+P →
**`MicroPico: Delete All Files from Board`** y vuelve al paso 4.

A partir de ahí, `main.py` se ejecuta solo cada vez que la placa recibe
alimentación, incluso con un cargador de móvil y sin PC.

Para probar un cambio rápido sin subirlo, abre `main.py` y pulsa **Run** en
la barra de estado (o `MicroPico: Run Current File on Board`). Ejecuta la
versión del editor, pero los demás módulos tienen que estar ya en la placa
(paso 4).

## 4. Ver los logs

MicroPico abre una terminal **"MicroPico vREPL"** al conectar (si no está:
Ctrl+Shift+P → `MicroPico: Connect`, o *Terminal → New Terminal (With
Profile) → MicroPico vREPL*). Todo lo que imprime la prueba sale ahí.

- **Ctrl+C** detiene la prueba y deja la consola `>>>` de MicroPython.
- **Ctrl+D** reinicia (soft reset) y vuelve a ejecutar `main.py` desde cero.

Cada línea lleva los segundos desde el arranque y un nivel:

```
[     1.204] INFO  === Prueba VL53L1X en Waveshare RP2040-Zero ===
[     1.206] INFO  --- Intento de arranque #1 ---
[     1.220] INFO  SDA (GP26): pull-up externo presente, línea en alto. OK
[     1.221] INFO  SCL (GP27): pull-up externo presente, línea en alto. OK
[     1.230] INFO  Escaneo I2C1 a 100 kHz: ['0x29']
[     1.236] INFO  Model ID: 0xEACC (esperado 0xEACC)
[     1.260] INFO  Prueba de estabilidad del bus: 50/50 lecturas correctas, 0 errores I2C, 0 valores corruptos
[     1.410] INFO  Sensor inicializado en 148 ms. Midiendo; ...
[     1.520] DEBUG distancia   412 mm   señal   9344 kcps
[     1.620] DEBUG distancia   410 mm   señal   9280 kcps
...
[     3.420] INFO  Resumen: 20 válidas de 20, mediana 411 mm, desviación 1.8 mm | sesión: ...
```

### Qué mirar si falla la conexión I2C

Es el fallo que tuvimos con el ESP32, así que el log lo desglosa por pasos. La
primera línea `WARN` o `ERROR` dice dónde está el problema:

| En el log | Qué significa | Qué revisar |
|---|---|---|
| `SDA/SCL: sin pull-up externo` | La línea no tiene el pull-up del módulo | Los pull-ups del módulo van a su VIN: sin 3.3 V en VIN no hay pull-up. O el cable de esa línea no está conectado |
| `SDA/SCL: en bajo incluso con pull-up interno` | Línea en corto a GND o retenida | Cable en el pin equivocado, o el sensor colgado (el script intenta liberarlo solo) |
| `Escaneo ... : ningún dispositivo` a 100 y 10 kHz | Nadie contesta en el bus | SDA/SCL cruzados, VIN/GND, XSHUT a GND |
| `responde a 10 kHz pero no a 100 kHz` | El bus funciona, pero con flancos lentos | Cables largos, pull-ups débiles, mal contacto |
| `Prueba de estabilidad: 47/50 ...` | Contacto intermitente: falla a ratos | Crimpado de los Dupont, cable flojo. **Candidato número uno para lo que pasaba con el ESP32** |
| `Model ID: 0x.... (esperado 0xEACC)` | No es un VL53L1X | Probablemente un VL53L0X, que usa la misma dirección |
| `[Errno 5] EIO` | El sensor no respondió a una transacción (NACK) | Cable suelto, sensor sin alimentación |
| `[Errno 110] ETIMEDOUT` | El bus se quedó bloqueado | Una línea retenida en bajo, falta pull-up |
| `Error I2C leyendo la medición (1/3 seguidos)` | Falló una lectura durante la medición | Si se repite, mueve los cables mientras miras el log para encontrar el que falla |

La línea `MicroPython ... | Raspberry Pi Pico with RP2040` del principio es
normal: el firmware es el de la Pico y se identifica así.

Tras un fallo el script **no se detiene**: registra el error y vuelve a
intentarlo cada pocos segundos (`Intento de arranque #N`). Puedes mover o
reconectar cables mientras miras el log y ver exactamente cuándo falla y
cuándo se recupera.

### Log guardado en la placa (pruebas sin PC)

Los mensajes `INFO`, `WARN` y `ERROR` (resúmenes y errores, no cada lectura)
también se guardan en `log.txt` en la flash de la placa. Pasa a `log.old.txt`
al llegar a 64 KB, así que nunca llena la memoria. Para leerlo después de una
prueba sin PC, conecta la placa, pulsa Ctrl+C en el vREPL y escribe:

```
print(open('log.txt').read())
```

Para borrarlo: `import os; os.remove('log.txt')`. Para desactivar el archivo,
pon `to_file = False` en `log.py`, y para ver sólo resúmenes y errores (sin
cada lectura), `level = INFO`.

## 5. Alternativa sin VS Code: mpremote

Desde **PowerShell de Windows** (en WSL tampoco ve el puerto):

```
pip install mpremote
cd \\wsl.localhost\Ubuntu\home\daniel\egg-basket-monitor\pico-sensor-test
mpremote cp main.py vl53l0x.py vl53l1x.py log.py :
mpremote reset
mpremote repl            # logs en vivo; Ctrl+] para salir
mpremote cat :log.txt    # log guardado
mpremote bootloader      # entrar al modo bootloader sin tocar BOOT
```

## 6. Si VS Code no encuentra la placa

- **"Pico Disconnected"** y en el Administrador de dispositivos no aparece
  ningún "Dispositivo serie USB (COMx)": cable de sólo carga, o la placa no
  tiene MicroPython (sigue en modo bootloader o vacía). Repite el apartado 2.
- **Aparece el puerto COM pero MicroPico no conecta:** otro programa lo tiene
  abierto (Thonny, mpremote, un monitor serie). Sólo uno puede usarlo a la vez:
  ciérralos y ejecuta `MicroPico: Connect`.
- **La ventana de VS Code dice "WSL: Ubuntu" abajo a la izquierda:** ver
  "VS Code en Windows, no en WSL" en el apartado 1.
- **La unidad `RPI-RP2` no aparece al entrar en bootloader:** BOOT tiene que
  seguir pulsado *mientras* sueltas RESET (o mientras conectas el cable), y
  soltarse después. Y otra vez: el cable.
- **`ImportError: no module named 'log'`** (o `'vl53l0x'`/`'vl53l1x'`): en
  la placa está `main.py` pero no los demás módulos, o están dentro de una
  subcarpeta. Pasa si usas **Run** sin haber hecho antes **Upload Project**,
  o si se abrió la carpeta padre sin la configuración de "Qué se sube a la
  placa": MicroPico sube los archivos con su ruta relativa a la carpeta
  abierta (`/pico-sensor-test/log.py`) y MicroPython sólo busca en la raíz.
  Para ver qué hay en la placa, en el vREPL: `import os; os.listdir()`.
- **"Upload Project" tarda muchísimo:** está subiendo cosas que no debe.
  Comprueba que `.vscode/settings.json` de la carpeta abierta tiene la
  configuración de "Qué se sube a la placa" (apartado 3).
- **La placa se calienta o Windows avisa de un problema con el puerto USB:**
  desconecta ya. Suele ser un corto en el cableado (VIN a GND, o 5V tocando
  otro pin); repasa [Antes de conectar la placa nueva](README.md#antes-de-conectar-la-placa-nueva).
