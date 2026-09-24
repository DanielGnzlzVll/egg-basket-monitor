# Log con marca de tiempo al serial USB y, opcionalmente, a un archivo en la
# flash de la placa para revisar después una prueba que corrió sin PC.
#
# El RP2040 no tiene reloj de tiempo real: la marca es el tiempo desde el
# arranque, en segundos.
#
# Al archivo sólo va INFO en adelante (resúmenes y errores, no cada lectura)
# para no gastar la flash; al llenarse MAX_FILE_BYTES pasa a log.old.txt.

import os
import sys
import time

DEBUG, INFO, WARN, ERROR = 10, 20, 30, 40
_NAMES = {DEBUG: "DEBUG", INFO: "INFO", WARN: "WARN", ERROR: "ERROR"}

LOG_FILE = "log.txt"
OLD_FILE = "log.old.txt"
MAX_FILE_BYTES = 64 * 1024

level = DEBUG
to_file = True


def _stamp():
    return "{:10.3f}".format(time.ticks_ms() / 1000)


def _write_file(line):
    try:
        try:
            if os.stat(LOG_FILE)[6] > MAX_FILE_BYTES:
                try:
                    os.remove(OLD_FILE)
                except OSError:
                    pass
                os.rename(LOG_FILE, OLD_FILE)
        except OSError:
            pass  # todavía no existe
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except OSError as e:
        print("(no se pudo escribir {}: {})".format(LOG_FILE, e))


def _log(lvl, msg):
    if lvl < level:
        return
    line = "[{}] {:5} {}".format(_stamp(), _NAMES[lvl], msg)
    print(line)
    if to_file and lvl >= INFO:
        _write_file(line)


def debug(msg):
    _log(DEBUG, msg)


def info(msg):
    _log(INFO, msg)


def warn(msg):
    _log(WARN, msg)


def error(msg):
    _log(ERROR, msg)


def exception(msg, exc):
    error("{}: {}".format(msg, describe_oserror(exc) if isinstance(exc, OSError) else repr(exc)))
    sys.print_exception(exc)


# Lo que significa cada errno cuando sale de una operación I2C en el RP2040.
_I2C_ERRNO = {
    5: "EIO: el dispositivo no respondió (NACK). Cable suelto, dirección equivocada o sensor sin alimentación",
    110: "ETIMEDOUT: el bus no avanzó. SCL o SDA retenidos en bajo, o falta pull-up",
    116: "ETIMEDOUT: el bus no avanzó. SCL o SDA retenidos en bajo, o falta pull-up",
    19: "ENODEV: no hay dispositivo en esa dirección",
}


def describe_oserror(exc):
    code = exc.args[0] if exc.args else None
    return "[Errno {}] {}".format(code, _I2C_ERRNO.get(code, "error I2C desconocido"))
