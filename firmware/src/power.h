#pragma once

#include <Arduino.h>

enum class LedPattern {
    BootWaiting,      // parpadeo lento blanco/azul mientras se cuenta el hold del botón
    CalibrationEntered,
    ConfigEntered,
    ConfigActive,     // fijo mientras el AP está levantado
    PostSuccess,
    PostFailed,
    BatteryCutoff,
};

namespace power {

// Inicializa el LED de estado (GPIO8).
void initLed();

// Reproduce un patrón de LED. Bloqueante para los patrones de parpadeo
// corto; ConfigActive deja el LED encendido y retorna de inmediato.
void showLed(LedPattern pattern);

void ledOff();

// Lee el divisor de batería (GPIO3) y devuelve el voltaje de la celda en
// voltios, ya escalado por BATTERY_DIVIDER_RATIO.
float readBatteryVolts();

// mV, para meter directo en la línea Influx.
uint32_t readBatteryMillivolts();

// Duerme indefinidamente (sin temporizador). Usado en el corte por batería
// baja: solo un reset manual (o soldar una celda nueva) despierta al equipo.
[[noreturn]] void deepSleepIndefinitely();

// Duerme el número de minutos indicado y despierta por temporizador.
[[noreturn]] void deepSleepFor(uint32_t minutes);

}  // namespace power
