# Driver mínimo del VL53L0X para MicroPython (módulo "TOF200C VL53L0X").
#
# Portado de la librería vl53l0x-arduino de Pololu (VL53L0X.cpp, rama master,
# commit 9f3773cb48d4e4e844d689cfc529a06f96d1d264):
#   https://github.com/pololu/vl53l0x-arduino
# Copyright (c) 2017-2022 Pololu Corporation, licencia tipo MIT. El código de
# Pololu deriva a su vez de la API oficial de ST (STSW-IMG005),
# Copyright (c) 2016 STMicroelectronics, licencia BSD de 3 cláusulas. Ver
# LICENSE.txt en ese repositorio para el texto completo de ambas.
#
# Misma secuencia que init() de Pololu con io_2v8=true (la E/S va a 3,3 V):
# DataInit, lectura de stop_variable, SPAD de referencia, tabla
# DefaultTuningSettings completa, GPIO, presupuesto de tiempo (~33 ms por
# defecto) y calibraciones VHV y de fase. Mide en modo continuo back-to-back.
# Misma API pública que vl53l1x.py para que main.py use cualquiera de los dos.

import time

DEFAULT_ADDR = 0x29
MODEL_ID = 0xEE

_SYSRANGE_START = 0x00
_SYSTEM_SEQUENCE_CONFIG = 0x01
_SYSTEM_INTERRUPT_CONFIG_GPIO = 0x0A
_SYSTEM_INTERRUPT_CLEAR = 0x0B
_RESULT_INTERRUPT_STATUS = 0x13
_RESULT_RANGE_STATUS = 0x14
_FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT = 0x44
_MSRC_CONFIG_TIMEOUT_MACROP = 0x46
_PRE_RANGE_CONFIG_VCSEL_PERIOD = 0x50
_PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x51
_MSRC_CONFIG_CONTROL = 0x60
_FINAL_RANGE_CONFIG_VCSEL_PERIOD = 0x70
_FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x71
_GPIO_HV_MUX_ACTIVE_HIGH = 0x84
_VHV_CONFIG_PAD_SCL_SDA__EXTSUP_HV = 0x89
_GLOBAL_CONFIG_SPAD_ENABLES_REF_0 = 0xB0
_GLOBAL_CONFIG_REF_EN_START_SELECT = 0xB6
_DYNAMIC_SPAD_NUM_REQUESTED_REF_SPAD = 0x4E
_DYNAMIC_SPAD_REF_EN_START_OFFSET = 0x4F
_IDENTIFICATION_MODEL_ID = 0xC0

# DefaultTuningSettings (vl53l0x_tuning.h de ST), copiada tal cual de
# VL53L0X::init() de Pololu, en el mismo orden. 0xFF selecciona la página.
_TUNING = (
    (0xFF, 0x01), (0x00, 0x00),

    (0xFF, 0x00), (0x09, 0x00), (0x10, 0x00), (0x11, 0x00),

    (0x24, 0x01), (0x25, 0xFF), (0x75, 0x00),

    (0xFF, 0x01), (0x4E, 0x2C), (0x48, 0x00), (0x30, 0x20),

    (0xFF, 0x00), (0x30, 0x09), (0x54, 0x00), (0x31, 0x04), (0x32, 0x03),
    (0x40, 0x83), (0x46, 0x25), (0x60, 0x00), (0x27, 0x00), (0x50, 0x06),
    (0x51, 0x00), (0x52, 0x96), (0x56, 0x08), (0x57, 0x30), (0x61, 0x00),
    (0x62, 0x00), (0x64, 0x00), (0x65, 0x00), (0x66, 0xA0),

    (0xFF, 0x01), (0x22, 0x32), (0x47, 0x14), (0x49, 0xFF), (0x4A, 0x00),

    (0xFF, 0x00), (0x7A, 0x0A), (0x7B, 0x00), (0x78, 0x21),

    (0xFF, 0x01), (0x23, 0x34), (0x42, 0x00), (0x44, 0xFF), (0x45, 0x26),
    (0x46, 0x05), (0x40, 0x40), (0x0E, 0x06), (0x20, 0x1A), (0x43, 0x40),

    (0xFF, 0x00), (0x34, 0x03), (0x35, 0x44),

    (0xFF, 0x01), (0x31, 0x04), (0x4B, 0x09), (0x4C, 0x05), (0x4D, 0x04),

    (0xFF, 0x00), (0x44, 0x00), (0x45, 0x20), (0x47, 0x08), (0x48, 0x28),
    (0x67, 0x00), (0x70, 0x04), (0x71, 0x01), (0x72, 0xFE), (0x76, 0x00),
    (0x77, 0x00),

    (0xFF, 0x01), (0x0D, 0x01),

    (0xFF, 0x00), (0x80, 0x01), (0x01, 0xF8),

    (0xFF, 0x01), (0x8E, 0x01), (0x00, 0x01), (0xFF, 0x00), (0x80, 0x00),
)

# Sobrecargas del cálculo del presupuesto de tiempo (µs), como en Pololu/ST.
_START_OVERHEAD = 1910
_END_OVERHEAD = 960
_MSRC_OVERHEAD = 660
_TCC_OVERHEAD = 590
_DSS_OVERHEAD = 690
_PRE_RANGE_OVERHEAD = 660
_FINAL_RANGE_OVERHEAD = 550

# Estado crudo del sensor (DeviceRangeStatus, bits 6..3 de 0x14) -> código de
# este driver. Agrupado como hace VL53L0X_get_pal_range_status() de ST y
# reutilizando los números de vl53l1x.py cuando el significado coincide.
_STATUS_RTN = (
    255,  # 0  sin actualizar
    5,    # 1  fallo test de continuidad del VCSEL
    5,    # 2  fallo watchdog del VCSEL
    5,    # 3  no se encontró valor VHV
    2,    # 4  MSRC sin objetivo
    2,    # 5  fallo de SNR
    4,    # 6  fase fuera de límites
    1,    # 7  sigma por encima del umbral
    3,    # 8  TCC (target centre check)
    4,    # 9  fase inconsistente
    3,    # 10 recorte por distancia mínima
    0,    # 11 medición completa (válida)
    8,    # 12 underflow del algoritmo
    8,    # 13 overflow del algoritmo
    2,    # 14 umbral de ignorado de rango
)

STATUS_TEXT = {
    0: "OK",
    1: "sigma alto (lectura ruidosa)",
    2: "señal débil (nada en rango o superficie oscura)",
    3: "objetivo demasiado cerca (por debajo del rango mínimo)",
    4: "fuera de rango",
    5: "error de hardware",
    8: "error interno del algoritmo (underflow/overflow)",
    255: "sin medición nueva / estado desconocido",
}


def _decode_vcsel_period(reg_val):
    return (reg_val + 1) << 1


def _calc_macro_period(vcsel_period_pclks):
    # En nanosegundos. PLL_period_ps = 1655; macro_period_vclks = 2304.
    return ((2304 * vcsel_period_pclks * 1655) + 500) // 1000


def _decode_timeout(reg_val):
    # formato: "(LSByte * 2^MSByte) + 1"; Pololu lo trunca a 16 bits
    return (((reg_val & 0x00FF) << ((reg_val & 0xFF00) >> 8)) + 1) & 0xFFFF


def _encode_timeout(timeout_mclks):
    if timeout_mclks <= 0:
        return 0
    ls_byte = timeout_mclks - 1
    ms_byte = 0
    while ls_byte & 0xFFFFFF00:
        ls_byte >>= 1
        ms_byte += 1
    return (ms_byte << 8) | (ls_byte & 0xFF)


def _mclks_to_us(timeout_period_mclks, vcsel_period_pclks):
    macro_period_ns = _calc_macro_period(vcsel_period_pclks)
    return ((timeout_period_mclks * macro_period_ns) + 500) // 1000


def _us_to_mclks(timeout_period_us, vcsel_period_pclks):
    macro_period_ns = _calc_macro_period(vcsel_period_pclks)
    return ((timeout_period_us * 1000) + (macro_period_ns // 2)) // macro_period_ns


class VL53L0X:
    def __init__(self, i2c, addr=DEFAULT_ADDR):
        self.i2c = i2c
        self.addr = addr
        self.boot_error = None
        self._stop_variable = 0
        self._timing_budget_us = 0

    def _read(self, reg, n):
        return self.i2c.readfrom_mem(self.addr, reg, n)

    def _read_u8(self, reg):
        return self._read(reg, 1)[0]

    def _read_u16(self, reg):
        b = self._read(reg, 2)
        return (b[0] << 8) | b[1]

    def _write(self, reg, data):
        self.i2c.writeto_mem(self.addr, reg, data)

    def _write_u8(self, reg, value):
        self._write(reg, bytes((value & 0xFF,)))

    def _write_u16(self, reg, value):
        self._write(reg, bytes(((value >> 8) & 0xFF, value & 0xFF)))

    def model_id(self):
        return self._read_u8(_IDENTIFICATION_MODEL_ID)

    def wait_boot(self, timeout_ms=1000):
        """Espera a que el sensor responda con su Model ID (0xEE). Si falla,
        boot_error guarda el último error I2C (None si el bus respondía pero
        el valor leído nunca fue 0xEE)."""
        self.boot_error = None
        start = time.ticks_ms()
        while time.ticks_diff(time.ticks_ms(), start) < timeout_ms:
            try:
                if self.model_id() == MODEL_ID:
                    return True
                self.boot_error = None
            except OSError as e:
                self.boot_error = e  # recién salido de XSHUT todavía no responde por I2C
            time.sleep_ms(2)
        return False

    def init(self, timeout_ms=1000):
        """Secuencia de VL53L0X::init(io_2v8=true) de Pololu. Devuelve False si
        el Model ID no cuadra o si la lectura de SPAD o una calibración no
        terminan en timeout_ms."""
        if self.model_id() != MODEL_ID:
            return False

        # --- VL53L0X_DataInit() ---
        # El sensor arranca con la E/S en modo 1V8; la pasamos a 2V8 (3,3 V).
        self._write_u8(_VHV_CONFIG_PAD_SCL_SDA__EXTSUP_HV,
                       self._read_u8(_VHV_CONFIG_PAD_SCL_SDA__EXTSUP_HV) | 0x01)

        # "Set I2C standard mode"
        self._write_u8(0x88, 0x00)

        self._write_u8(0x80, 0x01)
        self._write_u8(0xFF, 0x01)
        self._write_u8(0x00, 0x00)
        self._stop_variable = self._read_u8(0x91)
        self._write_u8(0x00, 0x01)
        self._write_u8(0xFF, 0x00)
        self._write_u8(0x80, 0x00)

        # desactiva los límites SIGNAL_RATE_MSRC (bit 1) y SIGNAL_RATE_PRE_RANGE (bit 4)
        self._write_u8(_MSRC_CONFIG_CONTROL, self._read_u8(_MSRC_CONFIG_CONTROL) | 0x12)

        # límite de señal del rango final a 0,25 MCPS (punto fijo Q9.7)
        self._write_u16(_FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT, int(0.25 * (1 << 7)))

        self._write_u8(_SYSTEM_SEQUENCE_CONFIG, 0xFF)

        # --- VL53L0X_StaticInit() ---
        info = self._get_spad_info(timeout_ms)
        if info is None:
            return False
        spad_count, spad_type_is_aperture = info

        # El mapa de SPAD de referencia se lee de GLOBAL_CONFIG_SPAD_ENABLES_REF_0..5
        ref_spad_map = bytearray(self._read(_GLOBAL_CONFIG_SPAD_ENABLES_REF_0, 6))

        # -- VL53L0X_set_reference_spads() (asume que los valores de NVM son válidos)
        self._write_u8(0xFF, 0x01)
        self._write_u8(_DYNAMIC_SPAD_REF_EN_START_OFFSET, 0x00)
        self._write_u8(_DYNAMIC_SPAD_NUM_REQUESTED_REF_SPAD, 0x2C)
        self._write_u8(0xFF, 0x00)
        self._write_u8(_GLOBAL_CONFIG_REF_EN_START_SELECT, 0xB4)

        first_spad_to_enable = 12 if spad_type_is_aperture else 0  # 12 = primer SPAD de apertura
        spads_enabled = 0
        for i in range(48):
            if i < first_spad_to_enable or spads_enabled == spad_count:
                ref_spad_map[i // 8] &= ~(1 << (i % 8)) & 0xFF
            elif (ref_spad_map[i // 8] >> (i % 8)) & 0x01:
                spads_enabled += 1

        self._write(_GLOBAL_CONFIG_SPAD_ENABLES_REF_0, ref_spad_map)

        # -- VL53L0X_load_tuning_settings()
        for reg, value in _TUNING:
            self._write_u8(reg, value)

        # -- VL53L0X_SetGpioConfig(): interrupción "nueva muestra lista", activa en bajo
        self._write_u8(_SYSTEM_INTERRUPT_CONFIG_GPIO, 0x04)
        self._write_u8(_GPIO_HV_MUX_ACTIVE_HIGH,
                       self._read_u8(_GPIO_HV_MUX_ACTIVE_HIGH) & ~0x10 & 0xFF)
        self._write_u8(_SYSTEM_INTERRUPT_CLEAR, 0x01)

        self._timing_budget_us = self.get_timing_budget_us()

        # "Disable MSRC and TCC by default"
        self._write_u8(_SYSTEM_SEQUENCE_CONFIG, 0xE8)

        # "Recalculate timing budget"
        self.set_timing_budget_us(self._timing_budget_us)

        # --- VL53L0X_PerformRefCalibration() ---
        self._write_u8(_SYSTEM_SEQUENCE_CONFIG, 0x01)  # VHV
        if not self._single_ref_calibration(0x40, timeout_ms):
            return False
        self._write_u8(_SYSTEM_SEQUENCE_CONFIG, 0x02)  # fase
        if not self._single_ref_calibration(0x00, timeout_ms):
            return False
        # "restore the previous Sequence Config"
        self._write_u8(_SYSTEM_SEQUENCE_CONFIG, 0xE8)
        return True

    def _get_spad_info(self, timeout_ms):
        """Número y tipo de SPAD de referencia (VL53L0X_get_info_from_device()).
        Devuelve (cuenta, es_apertura) o None si vence el tiempo."""
        self._write_u8(0x80, 0x01)
        self._write_u8(0xFF, 0x01)
        self._write_u8(0x00, 0x00)

        self._write_u8(0xFF, 0x06)
        self._write_u8(0x83, self._read_u8(0x83) | 0x04)
        self._write_u8(0xFF, 0x07)
        self._write_u8(0x81, 0x01)

        self._write_u8(0x80, 0x01)

        self._write_u8(0x94, 0x6B)
        self._write_u8(0x83, 0x00)
        start = time.ticks_ms()
        while self._read_u8(0x83) == 0x00:
            if time.ticks_diff(time.ticks_ms(), start) > timeout_ms:
                return None
            time.sleep_ms(1)
        self._write_u8(0x83, 0x01)
        tmp = self._read_u8(0x92)

        self._write_u8(0x81, 0x00)
        self._write_u8(0xFF, 0x06)
        self._write_u8(0x83, self._read_u8(0x83) & ~0x04 & 0xFF)
        self._write_u8(0xFF, 0x01)
        self._write_u8(0x00, 0x01)

        self._write_u8(0xFF, 0x00)
        self._write_u8(0x80, 0x00)

        return tmp & 0x7F, bool((tmp >> 7) & 0x01)

    def _single_ref_calibration(self, vhv_init_byte, timeout_ms):
        self._write_u8(_SYSRANGE_START, 0x01 | vhv_init_byte)  # modo START_STOP
        if not self.wait_data_ready(timeout_ms):
            return False
        self._write_u8(_SYSTEM_INTERRUPT_CLEAR, 0x01)
        self._write_u8(_SYSRANGE_START, 0x00)
        return True

    def _sequence_step_enables(self):
        c = self._read_u8(_SYSTEM_SEQUENCE_CONFIG)
        return {
            "tcc": (c >> 4) & 1,
            "dss": (c >> 3) & 1,
            "msrc": (c >> 2) & 1,
            "pre_range": (c >> 6) & 1,
            "final_range": (c >> 7) & 1,
        }

    def _sequence_step_timeouts(self, enables):
        t = {}
        t["pre_range_vcsel_period_pclks"] = _decode_vcsel_period(
            self._read_u8(_PRE_RANGE_CONFIG_VCSEL_PERIOD))
        t["msrc_dss_tcc_mclks"] = self._read_u8(_MSRC_CONFIG_TIMEOUT_MACROP) + 1
        t["msrc_dss_tcc_us"] = _mclks_to_us(t["msrc_dss_tcc_mclks"],
                                            t["pre_range_vcsel_period_pclks"])
        t["pre_range_mclks"] = _decode_timeout(self._read_u16(_PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI))
        t["pre_range_us"] = _mclks_to_us(t["pre_range_mclks"],
                                         t["pre_range_vcsel_period_pclks"])
        t["final_range_vcsel_period_pclks"] = _decode_vcsel_period(
            self._read_u8(_FINAL_RANGE_CONFIG_VCSEL_PERIOD))
        final_mclks = _decode_timeout(self._read_u16(_FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI))
        if enables["pre_range"]:
            final_mclks = (final_mclks - t["pre_range_mclks"]) & 0xFFFF  # uint16 como en Pololu
        t["final_range_mclks"] = final_mclks
        t["final_range_us"] = _mclks_to_us(final_mclks, t["final_range_vcsel_period_pclks"])
        return t

    def get_timing_budget_us(self):
        """Presupuesto de tiempo de medición actual en µs
        (VL53L0X_get_measurement_timing_budget_micro_seconds())."""
        enables = self._sequence_step_enables()
        t = self._sequence_step_timeouts(enables)
        budget = _START_OVERHEAD + _END_OVERHEAD
        if enables["tcc"]:
            budget += t["msrc_dss_tcc_us"] + _TCC_OVERHEAD
        if enables["dss"]:
            budget += 2 * (t["msrc_dss_tcc_us"] + _DSS_OVERHEAD)
        elif enables["msrc"]:
            budget += t["msrc_dss_tcc_us"] + _MSRC_OVERHEAD
        if enables["pre_range"]:
            budget += t["pre_range_us"] + _PRE_RANGE_OVERHEAD
        if enables["final_range"]:
            budget += t["final_range_us"] + _FINAL_RANGE_OVERHEAD
        self._timing_budget_us = budget
        return budget

    def set_timing_budget_us(self, us):
        """Tiempo permitido para cada medición (mínimo ~20000 µs; por defecto
        ~33000 µs). Más tiempo = menos ruido. Devuelve False si no cabe."""
        enables = self._sequence_step_enables()
        t = self._sequence_step_timeouts(enables)
        used = _START_OVERHEAD + _END_OVERHEAD
        if enables["tcc"]:
            used += t["msrc_dss_tcc_us"] + _TCC_OVERHEAD
        if enables["dss"]:
            used += 2 * (t["msrc_dss_tcc_us"] + _DSS_OVERHEAD)
        elif enables["msrc"]:
            used += t["msrc_dss_tcc_us"] + _MSRC_OVERHEAD
        if enables["pre_range"]:
            used += t["pre_range_us"] + _PRE_RANGE_OVERHEAD
        if enables["final_range"]:
            used += _FINAL_RANGE_OVERHEAD
            if used > us:
                return False  # "Requested timeout too big."
            final_mclks = _us_to_mclks(us - used, t["final_range_vcsel_period_pclks"])
            if enables["pre_range"]:
                final_mclks += t["pre_range_mclks"]
            self._write_u16(_FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI, _encode_timeout(final_mclks))
            self._timing_budget_us = us
        return True

    def start_ranging(self):
        """Modo continuo back-to-back (VL53L0X_StartMeasurement())."""
        self._write_u8(0x80, 0x01)
        self._write_u8(0xFF, 0x01)
        self._write_u8(0x00, 0x00)
        self._write_u8(0x91, self._stop_variable)
        self._write_u8(0x00, 0x01)
        self._write_u8(0xFF, 0x00)
        self._write_u8(0x80, 0x00)
        self._write_u8(_SYSRANGE_START, 0x02)  # VL53L0X_REG_SYSRANGE_MODE_BACKTOBACK

    def stop_ranging(self):
        self._write_u8(_SYSRANGE_START, 0x01)  # VL53L0X_REG_SYSRANGE_MODE_SINGLESHOT
        self._write_u8(0xFF, 0x01)
        self._write_u8(0x00, 0x00)
        self._write_u8(0x91, 0x00)
        self._write_u8(0x00, 0x01)
        self._write_u8(0xFF, 0x00)

    def clear_interrupt(self):
        self._write_u8(_SYSTEM_INTERRUPT_CLEAR, 0x01)

    def data_ready(self):
        return (self._read_u8(_RESULT_INTERRUPT_STATUS) & 0x07) != 0

    def wait_data_ready(self, timeout_ms=1000):
        start = time.ticks_ms()
        while time.ticks_diff(time.ticks_ms(), start) < timeout_ms:
            if self.data_ready():
                return True
            time.sleep_ms(2)
        return False

    def read(self):
        """Devuelve (distancia_mm, estado, señal_kcps) y deja lista la siguiente."""
        # Bloque de resultados como lo lee la API de ST: +0 estado, +6 señal
        # (Q9.7 MCPS), +10 distancia en mm.
        b = self._read(_RESULT_RANGE_STATUS, 12)
        raw = (b[0] >> 3) & 0x0F
        status = _STATUS_RTN[raw] if raw < len(_STATUS_RTN) else 255
        signal = (((b[6] << 8) | b[7]) * 1000) >> 7  # MCPS Q9.7 -> kcps
        distance = (b[10] << 8) | b[11]
        if status == 0 and distance >= 8190:
            status = 4  # 8190/8191 = sin objetivo en rango
        self.clear_interrupt()
        return distance, status, signal
