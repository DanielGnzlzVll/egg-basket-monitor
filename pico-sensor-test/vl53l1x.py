# Driver mínimo del VL53L1X para MicroPython.
#
# Portado de la ULD API oficial de ST (VL53L1X_api.c): mismo bloque de
# configuración por defecto, misma secuencia de arranque y mismos registros.
# Deja el sensor en modo "long" (el que trae la configuración por defecto),
# que alcanza de sobra para verificar que el sensor funciona.

import time

DEFAULT_ADDR = 0x29
MODEL_ID = 0xEACC

_VHV_CONFIG__TIMEOUT_MACROP_LOOP_BOUND = 0x0008
_VHV_CONFIG__INIT = 0x000B
_GPIO_HV_MUX__CTRL = 0x0030
_GPIO__TIO_HV_STATUS = 0x0031
_SYSTEM__INTERRUPT_CLEAR = 0x0086
_SYSTEM__MODE_START = 0x0087
_RESULT__RANGE_STATUS = 0x0089
_RESULT__FINAL_RANGE_MM = 0x0096
_RESULT__PEAK_SIGNAL_RATE = 0x0098
_FIRMWARE__SYSTEM_STATUS = 0x00E5
_IDENTIFICATION__MODEL_ID = 0x010F

# Registros 0x2D..0x87, VL51L1X_DEFAULT_CONFIGURATION de la ULD.
_DEFAULT_CONFIG = bytes((
    0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x02, 0x08,  # 0x2D
    0x00, 0x08, 0x10, 0x01, 0x01, 0x00, 0x00, 0x00,  # 0x35
    0x00, 0xFF, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x00,  # 0x3D
    0x00, 0x20, 0x0B, 0x00, 0x00, 0x02, 0x0A, 0x21,  # 0x45
    0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0xC8,  # 0x4D
    0x00, 0x00, 0x38, 0xFF, 0x01, 0x00, 0x08, 0x00,  # 0x55
    0x00, 0x01, 0xCC, 0x0F, 0x01, 0xF1, 0x0D, 0x01,  # 0x5D
    0x68, 0x00, 0x80, 0x08, 0xB8, 0x00, 0x00, 0x00,  # 0x65
    0x00, 0x0F, 0x89, 0x00, 0x00, 0x00, 0x00, 0x00,  # 0x6D
    0x00, 0x00, 0x01, 0x0F, 0x0D, 0x0E, 0x0E, 0x00,  # 0x75
    0x00, 0x02, 0xC7, 0xFF, 0x9B, 0x00, 0x00, 0x00,  # 0x7D
    0x01, 0x00, 0x00,                                # 0x85
))

# Traducción del estado crudo del sensor al código de la ULD (status_rtn).
_STATUS_RTN = (255, 255, 255, 5, 2, 4, 1, 7, 3, 0, 255, 255,
               9, 13, 255, 255, 255, 255, 10, 6, 255, 255, 11, 12)

STATUS_TEXT = {
    0: "OK",
    1: "sigma alto (lectura ruidosa)",
    2: "señal débil (nada en rango o superficie oscura)",
    4: "fuera de rango",
    5: "error de hardware",
    7: "wraparound (objetivo muy lejos)",
}


class VL53L1X:
    def __init__(self, i2c, addr=DEFAULT_ADDR):
        self.i2c = i2c
        self.addr = addr

    def _read(self, reg, n):
        return self.i2c.readfrom_mem(self.addr, reg, n, addrsize=16)

    def _read_u8(self, reg):
        return self._read(reg, 1)[0]

    def _read_u16(self, reg):
        b = self._read(reg, 2)
        return (b[0] << 8) | b[1]

    def _write_u8(self, reg, value):
        self.i2c.writeto_mem(self.addr, reg, bytes((value,)), addrsize=16)

    def model_id(self):
        return self._read_u16(_IDENTIFICATION__MODEL_ID)

    def wait_boot(self, timeout_ms=1000):
        """Espera a que el firmware del sensor arranque. Si falla, boot_error
        guarda el último error I2C (None si el bus respondía pero no arrancó)."""
        self.boot_error = None
        start = time.ticks_ms()
        while time.ticks_diff(time.ticks_ms(), start) < timeout_ms:
            try:
                if self._read_u8(_FIRMWARE__SYSTEM_STATUS) & 0x01:
                    return True
                self.boot_error = None
            except OSError as e:
                self.boot_error = e  # recién salido de XSHUT todavía no responde por I2C
            time.sleep_ms(2)
        return False

    def init(self, timeout_ms=1000):
        self.i2c.writeto_mem(self.addr, 0x2D, _DEFAULT_CONFIG, addrsize=16)
        # La ULD hace una medición de descarte para calibrar el VHV.
        self.start_ranging()
        if not self.wait_data_ready(timeout_ms):
            return False
        self.clear_interrupt()
        self.stop_ranging()
        self._write_u8(_VHV_CONFIG__TIMEOUT_MACROP_LOOP_BOUND, 0x09)
        self._write_u8(_VHV_CONFIG__INIT, 0x00)
        return True

    def start_ranging(self):
        self._write_u8(_SYSTEM__MODE_START, 0x40)

    def stop_ranging(self):
        self._write_u8(_SYSTEM__MODE_START, 0x00)

    def clear_interrupt(self):
        self._write_u8(_SYSTEM__INTERRUPT_CLEAR, 0x01)

    def data_ready(self):
        polarity = 0 if self._read_u8(_GPIO_HV_MUX__CTRL) & 0x10 else 1
        return (self._read_u8(_GPIO__TIO_HV_STATUS) & 0x01) == polarity

    def wait_data_ready(self, timeout_ms=1000):
        start = time.ticks_ms()
        while time.ticks_diff(time.ticks_ms(), start) < timeout_ms:
            if self.data_ready():
                return True
            time.sleep_ms(2)
        return False

    def read(self):
        """Devuelve (distancia_mm, estado, señal_kcps) y deja lista la siguiente."""
        raw = self._read_u8(_RESULT__RANGE_STATUS) & 0x1F
        status = _STATUS_RTN[raw] if raw < len(_STATUS_RTN) else 255
        distance = self._read_u16(_RESULT__FINAL_RANGE_MM)
        signal = self._read_u16(_RESULT__PEAK_SIGNAL_RATE) * 8
        self.clear_interrupt()
        return distance, status, signal
