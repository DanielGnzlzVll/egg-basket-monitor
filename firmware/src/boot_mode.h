#pragma once

enum class BootMode {
    Normal,
    Calibration,
    Config,
};

namespace boot_mode {

// Observa GPIO_BOOT_BUTTON durante BOOT_DECISION_WINDOW_MS y clasifica el
// arranque. Si el botón nunca se presiona, retorna casi de inmediato
// (short-circuit) para no penalizar el ciclo normal en batería, salvo que
// haya un monitor serie abierto por USB: entonces entra a Calibration sin
// tocar el botón (AUTO_CALIBRATION_ON_SERIAL en config.h).
// `hasStoredWifi` fuerza Config si no hay nada guardado, sin importar el
// botón (primer arranque de fábrica).
BootMode detect(bool hasStoredWifi);

}  // namespace boot_mode
