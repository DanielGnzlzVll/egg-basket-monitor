# Prueba del sensor ToF (VL53L0X o VL53L1X, se detecta solo) con una
# Waveshare RP2040-Zero.
#
# Recorre el arranque paso a paso y dice en cuál falla. El detalle sale por el
# serial USB (y los resúmenes y errores también a log.txt en la placa, ver
# log.py). Además el LED RGB de la placa permite probar sin PC:
#
#   rojo, verde, azul al arrancar  -> el script está corriendo (y prueba el LED)
#   2 destellos rojos, pausa       -> nada responde en 0x29 (cableado/alimentación)
#   3 destellos rojos, pausa       -> algo responde en 0x29 pero no es VL53L0X ni VL53L1X
#   4 destellos rojos, pausa       -> se identificó el sensor pero no arranca / no mide
#   destello verde por lectura     -> midiendo bien
#   azul fijo                      -> hay algo a menos de HAND_MM (pon la mano)
#   destello amarillo por lectura  -> lectura inválida (nada en rango)
#
# Ante un fallo no se detiene: registra el error, muestra el código en el LED
# y vuelve a intentarlo desde el principio. Así un cable flojo queda en el log
# cada vez que falla y cada vez que se recupera.

import os
import sys
import time
import machine
import neopixel
from machine import I2C, Pin

try:
    import log
    import vl53l0x
    import vl53l1x
except ImportError as e:
    # Pasa al usar "Run" sin haber subido antes los módulos, o al abrir en
    # VS Code la carpeta padre: MicroPico los sube dentro de una subcarpeta.
    print("FALLO:", e)
    print("Faltan log.py, vl53l0x.py o vl53l1x.py en la raíz de la placa. Abre en VS Code la")
    print("carpeta pico-sensor-test (no la del repo) y usa 'Upload project to Pico'.")
    print("Archivos en la raíz de la placa:", os.listdir())
    raise SystemExit

# Los tres en el borde izquierdo de la RP2040-Zero, junto a 3V3 y GND.
SDA_PIN = 26     # GP26
SCL_PIN = 27     # GP27
XSHUT_PIN = 28   # GP28. None si XSHUT no está cableado
I2C_ID = 1       # GP26/GP27 pertenecen al bloque I2C1
I2C_FREQ = 100_000   # 100 kHz perdona cables Dupont largos; el sensor admite 400 kHz
I2C_FREQ_SLOW = 10_000   # segundo intento de escaneo si a I2C_FREQ no aparece nada
HAND_MM = 150
SAMPLES = 20     # igual que el firmware del ESP32: mediana de 20 lecturas
BUS_TEST_READS = 50
MAX_CONSECUTIVE_ERRORS = 3
RETRY_DELAY_S = 3

# La RP2040-Zero no tiene LED simple: lleva un WS2812 (NeoPixel) en GP16.
LED_PIN = 16
LED_BRIGHTNESS = 0.1   # a plena potencia el WS2812 deslumbra
# Algunas tandas de la placa traen el LED en orden RGB en vez de GRB: si al
# arrancar el primer color es verde en vez de rojo, pon esto a True.
LED_SWAP_RED_GREEN = False

RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 160, 0)
OFF = (0, 0, 0)

_np = neopixel.NeoPixel(Pin(LED_PIN), 1)

# Contadores de toda la sesión, se imprimen en cada resumen.
stats = {"attempts": 0, "readings": 0, "invalid": 0, "i2c_errors": 0}


class SetupError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def led(color):
    r, g, b = (int(c * LED_BRIGHTNESS) for c in color)
    # neopixel manda GRB por defecto; el swap lo convierte en RGB
    _np[0] = (g, r, b) if LED_SWAP_RED_GREEN else (r, g, b)
    _np.write()


def flash(color, ms):
    led(color)
    time.sleep_ms(ms)
    led(OFF)


def blink_code(n, repeats=1):
    for _ in range(repeats):
        for _ in range(n):
            flash(RED, 150)
            time.sleep_ms(250)
        time.sleep_ms(1200)


def reset_sensor():
    if XSHUT_PIN is None:
        log.info("XSHUT no cableado: se asume el pull-up del módulo")
        return
    # Drenador abierto: se tira a GND para apagar y se suelta para encender,
    # sin forzar 3.3 V contra el pull-up del módulo (que puede ir a su LDO de
    # 2.8 V). El pull-up interno cubre los módulos que no traen uno.
    xshut = Pin(XSHUT_PIN, Pin.OPEN_DRAIN, value=0, pull=Pin.PULL_UP)
    time.sleep_ms(10)
    xshut.value(1)
    # tBOOT es 1.2 ms como máximo; se deja margen, como recomiendan en los foros
    # del VL53L0X, que no tiene registro de "arrancado" que consultar.
    time.sleep_ms(50)
    log.info("XSHUT (GP{}): a GND 10 ms -> liberado, espera de arranque 50 ms".format(XSHUT_PIN))


def check_lines():
    """Mira SDA y SCL eléctricamente antes de que el periférico I2C los tome.

    Con el pull-down interno activado (~50 kΩ), una línea sólo lee 1 si hay un
    pull-up externo más fuerte, que es lo que traen los módulos VL53L0X/VL53L1X. Con el
    pull-up interno, una línea que sigue en 0 está en corto a GND o la retiene
    un dispositivo colgado. Devuelve True si SDA quedó retenida en bajo.
    """
    sda_stuck = False
    for name, num in (("SDA", SDA_PIN), ("SCL", SCL_PIN)):
        pin = Pin(num, Pin.IN, Pin.PULL_DOWN)
        time.sleep_us(100)
        with_pull_down = pin.value()
        pin.init(Pin.IN, Pin.PULL_UP)
        time.sleep_us(100)
        with_pull_up = pin.value()
        pin.init(Pin.IN, None)

        if with_pull_down:
            log.info("{} (GP{}): pull-up externo presente, línea en alto. OK".format(name, num))
        elif with_pull_up:
            log.warn("{} (GP{}): sin pull-up externo. Los pull-ups del módulo van a su VIN: "
                     "¿llega 3.3 V a VIN? ¿el cable {} está conectado?".format(name, num, name))
        else:
            log.error("{} (GP{}): en bajo incluso con pull-up interno. Corto a GND, cable "
                      "en el pin equivocado o el sensor retiene la línea".format(name, num))
            if name == "SDA":
                sda_stuck = True
    return sda_stuck


def recover_bus():
    """Libera un esclavo que se quedó a mitad de byte reteniendo SDA en bajo:
    hasta 9 pulsos de reloj y una condición de STOP (I2C spec, 3.1.16)."""
    scl = Pin(SCL_PIN, Pin.OPEN_DRAIN, value=1, pull=Pin.PULL_UP)
    sda = Pin(SDA_PIN, Pin.IN, Pin.PULL_UP)
    pulses = 0
    while not sda.value() and pulses < 9:
        scl.value(0)
        time.sleep_us(10)
        scl.value(1)
        time.sleep_us(10)
        pulses += 1
    sda = Pin(SDA_PIN, Pin.OPEN_DRAIN, value=0, pull=Pin.PULL_UP)
    time.sleep_us(10)
    sda.value(1)
    time.sleep_us(10)
    released = sda.value()
    Pin(SDA_PIN, Pin.IN, None)
    Pin(SCL_PIN, Pin.IN, None)
    if released:
        log.info("Recuperación del bus: SDA liberada tras {} pulsos de reloj".format(pulses))
    else:
        log.error("Recuperación del bus: SDA sigue en bajo tras 9 pulsos. Es un corto, no un "
                  "sensor colgado")


def scan():
    for freq in (I2C_FREQ, I2C_FREQ_SLOW):
        i2c = I2C(I2C_ID, sda=Pin(SDA_PIN), scl=Pin(SCL_PIN), freq=freq)
        found = i2c.scan()
        log.info("Escaneo I2C{} a {} kHz: {}".format(
            I2C_ID, freq // 1000, [hex(a) for a in found] or "ningún dispositivo"))
        if vl53l1x.DEFAULT_ADDR in found:
            if freq != I2C_FREQ:
                log.warn("El sensor responde a {} kHz pero no a {} kHz: pull-ups débiles, "
                         "cables largos o mal contacto. Se sigue a {} kHz".format(
                             freq // 1000, I2C_FREQ // 1000, freq // 1000))
            return i2c
        if found:
            raise SetupError(2, "hay dispositivos I2C pero ninguno en 0x29. ¿Otro sensor en "
                                "el bus o SDA/SCL de otro dispositivo?")
    raise SetupError(2, "nada responde en el bus I2C. Revisa: VIN a 3V3 (no a 5V), GND, "
                        "SDA<->GP{} y SCL<->GP{} no cruzados, y que XSHUT no esté a "
                        "GND".format(SDA_PIN, SCL_PIN))


def identify(i2c):
    """Distingue VL53L0X de VL53L1X: los dos contestan en 0x29 y se parecen
    mucho, pero el L0X usa registros de 8 bits (ID 0xEE en 0xC0) y el L1X de
    16 bits (ID 0xEACC en 0x010F). Primero el de 8 bits: una lectura de 16
    bits escribiría el segundo byte de la dirección en un registro del L0X.

    Reintenta durante 1 s porque recién soltado XSHUT el chip aún no contesta.
    """
    addr = vl53l1x.DEFAULT_ADDR
    last_error = None
    id_8 = id_16 = None
    start = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start) < 1000:
        try:
            id_8 = i2c.readfrom_mem(addr, 0xC0, 1)[0]
            if id_8 == vl53l0x.MODEL_ID:
                log.info("Chip detectado: VL53L0X (registro 0xC0 = 0x{:02X})".format(id_8))
                return vl53l0x
            b = i2c.readfrom_mem(addr, 0x010F, 2, addrsize=16)
            id_16 = (b[0] << 8) | b[1]
            if id_16 == vl53l1x.MODEL_ID:
                log.info("Chip detectado: VL53L1X (registro 0x010F = 0x{:04X})".format(id_16))
                return vl53l1x
        except OSError as e:
            last_error = e
        time.sleep_ms(10)
    if id_8 is None and id_16 is None and last_error is not None:
        stats["i2c_errors"] += 1
        raise SetupError(4, "el sensor respondió al escaneo pero falla al leer sus registros: "
                            + log.describe_oserror(last_error)
                            + ". Típico de un contacto intermitente en SDA/SCL")
    raise SetupError(3, "lo que hay en 0x29 no es VL53L0X ni VL53L1X: 0xC0 = {}, 0x010F = {} "
                        "(esperado 0x{:02X} o 0x{:04X})".format(
                            "0x{:02X}".format(id_8) if id_8 is not None else "sin respuesta",
                            "0x{:04X}".format(id_16) if id_16 is not None else "sin respuesta",
                            vl53l0x.MODEL_ID, vl53l1x.MODEL_ID))


def bus_test(sensor, driver):
    """Lee el Model ID muchas veces: un contacto intermitente falla sólo a ratos."""
    errors = 0
    wrong = 0
    for _ in range(BUS_TEST_READS):
        try:
            if sensor.model_id() != driver.MODEL_ID:
                wrong += 1
        except OSError as e:
            errors += 1
            stats["i2c_errors"] += 1
            log.debug("  lectura fallida: " + log.describe_oserror(e))
    ok = BUS_TEST_READS - errors - wrong
    msg = "Prueba de estabilidad del bus: {}/{} lecturas correctas, {} errores I2C, {} valores " \
          "corruptos".format(ok, BUS_TEST_READS, errors, wrong)
    if ok == BUS_TEST_READS:
        log.info(msg)
    else:
        log.warn(msg + ". Conexión intermitente: revisa crimpado y contactos de los Dupont")


def setup():
    stats["attempts"] += 1
    log.info("--- Intento de arranque #{} ---".format(stats["attempts"]))

    log.info("[1/5] Reset del sensor")
    reset_sensor()

    log.info("[2/5] Estado eléctrico de SDA/SCL")
    if check_lines():
        recover_bus()

    log.info("[3/5] Escaneo del bus I2C")
    i2c = scan()

    log.info("[4/5] Identificación del sensor")
    driver = identify(i2c)
    sensor = driver.VL53L0X(i2c) if driver is vl53l0x else driver.VL53L1X(i2c)
    t0 = time.ticks_ms()
    if not sensor.wait_boot():
        if sensor.boot_error is not None:
            stats["i2c_errors"] += 1
            raise SetupError(4, "el sensor respondió al escaneo pero falla al leer sus registros: "
                                + log.describe_oserror(sensor.boot_error)
                                + ". Típico de un contacto intermitente en SDA/SCL")
        raise SetupError(4, "el sensor se identificó pero su firmware no termina de arrancar")
    log.info("Sensor listo en {} ms".format(time.ticks_diff(time.ticks_ms(), t0)))
    bus_test(sensor, driver)

    log.info("[5/5] Inicialización")
    t0 = time.ticks_ms()
    if not sensor.init():
        raise SetupError(4, "la inicialización del sensor no terminó (calibración o primera "
                            "medición). Puede estar dañado o con alimentación inestable")
    sensor.start_ranging()
    log.info("Sensor inicializado en {} ms. Midiendo; acerca la mano: el LED se pone azul "
             "por debajo de {} mm".format(time.ticks_diff(time.ticks_ms(), t0), HAND_MM))
    return sensor, driver


def median(values):
    s = sorted(values)
    mid = len(s) // 2
    return s[mid] if len(s) % 2 else (s[mid - 1] + s[mid]) / 2


def stddev(values):
    mean = sum(values) / len(values)
    return (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5


def measure(sensor, driver):
    """Mide hasta que el bus falla MAX_CONSECUTIVE_ERRORS veces seguidas."""
    window = []
    invalid = 0
    consecutive = 0
    while True:
        try:
            if not sensor.wait_data_ready(2000):
                log.error("El sensor no entregó una medición en 2 s")
                return
            distance, status, signal = sensor.read()
            consecutive = 0
        except OSError as e:
            stats["i2c_errors"] += 1
            consecutive += 1
            led(OFF)
            log.warn("Error I2C leyendo la medición ({}/{} seguidos): {}".format(
                consecutive, MAX_CONSECUTIVE_ERRORS, log.describe_oserror(e)))
            if consecutive >= MAX_CONSECUTIVE_ERRORS:
                log.error("Se perdió la comunicación con el sensor")
                return
            time.sleep_ms(50)
            continue

        stats["readings"] += 1
        if status == 0:
            window.append(distance)
            if distance < HAND_MM:
                led(BLUE)
            else:
                flash(GREEN, 20)
            log.debug("distancia {:5d} mm   señal {:6d} kcps".format(distance, signal))
        else:
            invalid += 1
            stats["invalid"] += 1
            flash(YELLOW, 20)
            log.debug("inválida ({:5d} mm)  estado {}: {}".format(
                distance, status, driver.STATUS_TEXT.get(status, "desconocido")))

        if len(window) + invalid >= SAMPLES:
            if window:
                log.info("Resumen: {} válidas de {}, mediana {} mm, desviación {:.1f} mm | "
                         "sesión: {} lecturas, {} inválidas, {} errores I2C, {} arranques".format(
                             len(window), SAMPLES, median(window), stddev(window),
                             stats["readings"], stats["invalid"], stats["i2c_errors"],
                             stats["attempts"]))
            else:
                log.info("Resumen: 0 válidas de {}: apunta a algo a menos de ~2 m".format(SAMPLES))
            window = []
            invalid = 0


def main():
    log.info("=== Prueba de sensor ToF (VL53L0X / VL53L1X) en Waveshare RP2040-Zero ===")
    log.info("Prueba del LED: debería verse ROJO, VERDE y AZUL, en ese orden. Si el primero "
             "es verde, pon LED_SWAP_RED_GREEN = True en main.py")
    for color in (RED, GREEN, BLUE):
        flash(color, 500)
        time.sleep_ms(150)

    log.info("MicroPython {} | {} | CPU {} MHz".format(
        sys.version, os.uname().machine, machine.freq() // 1_000_000))
    log.info("SDA=GP{} SCL=GP{} XSHUT={} I2C{} a {} kHz".format(
        SDA_PIN, SCL_PIN, "GP{}".format(XSHUT_PIN) if XSHUT_PIN is not None else "no cableado",
        I2C_ID, I2C_FREQ // 1000))

    while True:
        try:
            measure(*setup())
            code = 4
        except SetupError as e:
            log.error("FALLO: " + e.message)
            code = e.code
        except OSError as e:
            # Un cable que se suelta a mitad de una transacción I2C acaba aquí.
            stats["i2c_errors"] += 1
            log.exception("Error I2C durante el arranque", e)
            code = 4
        log.info("Reintento en {} s (código de LED: {} destellos rojos)".format(RETRY_DELAY_S, code))
        blink_code(code)
        time.sleep(RETRY_DELAY_S)


main()
