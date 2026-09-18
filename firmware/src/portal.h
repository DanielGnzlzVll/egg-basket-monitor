#pragma once

namespace portal {

// Levanta el AP EggBasket-Setup + portal cautivo con el formulario combinado
// (WiFi + Grafana/Influx + intervalo de sueño). Bloquea hasta que el usuario
// guarda el formulario o hasta PORTAL_TIMEOUT_S de inactividad.
//
// Devuelve true si se guardó una configuración completa y utilizable
// (settings::save ya fue llamado); false si hubo timeout sin que el usuario
// llegara a enviar el formulario, o si el formulario llegó incompleto.
bool runConfigPortal();

}  // namespace portal
