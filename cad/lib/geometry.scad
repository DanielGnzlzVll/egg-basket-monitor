// ===========================================================================
//  Verificacion geometrica del apuntado
//
//  Este archivo no produce solidos. A partir de las medidas de la canasta y
//  de donde acaba el sensor colgado del brazo, decide en que lado hay que
//  montar la mordaza y que posiciones de detente son utilizables.
//      openscad -o /dev/null lib/geometry.scad
//  Tambien se incluye desde sensor_head.scad, asi que avisa al compilar.
//
//  El problema que resuelve: el emisor del VL53L1X abre 27 grados y no se
//  puede estrechar. Si el cono toca una pared mucho antes de llegar al fondo,
//  la pared devuelve mas senal que los huevos y el sensor mide la pared.
//  Lo unico estrechable es el ROI del receptor, hasta 15 grados con 4x4
//  SPADs, y el receptor es quien decide de donde se lee la distancia.
//
//  Ojo con una trampa: el sensor NO esta pegado a la pared. Cuelga de un
//  brazo que lo mete `pod_reach + pod_arm*sin(theta)` hacia el interior. Eso
//  lo aleja de la pared de montaje (bien) pero lo acerca a la de enfrente
//  (mal), asi que el calculo hay que hacerlo desde la posicion real, no
//  desde el borde.
// ===========================================================================

include <../params.scad>

roi_half = roi_fov / 2;   // 7.5 grados

// --- Donde acaba el sensor, en funcion del angulo --------------------------
// x medido desde la cara interna de la pared de montaje.
// h medido desde el sensor hasta el fondo de la canasta.
function sensor_x(t) = pod_reach + pod_arm * sin(t);
function sensor_h(t) = basket_height - pivot_drop - pod_arm * cos(t);

// Donde aterrizan los dos bordes del ROI en el fondo.
function near_hit(t) = sensor_x(t) + sensor_h(t) * tan(t - roi_half);
function far_hit(t)  = sensor_x(t) + sensor_h(t) * tan(t + roi_half);

// Un angulo vale si el ROI entero cae en el fondo dejando `wall_margin`
// libre contra las dos paredes.
function aims_ok(t, span) = near_hit(t) >= wall_margin
                         && far_hit(t)  <= span - wall_margin;

// --- Que lado conviene -----------------------------------------------------
// Se prueba a apuntar a traves de cada una de las dos dimensiones de la boca
// y gana la que admita mas posiciones de detente.
candidates = [for (a = [0 : detent_step : 60]) a];

function detents_for(span) = [for (a = candidates) if (aims_ok(a, span)) a];

det_across_width = detents_for(basket_width);
det_across_depth = detents_for(basket_depth);

mount_on_short_side = len(det_across_width) >= len(det_across_depth);
aim_span       = mount_on_short_side ? basket_width : basket_depth;
usable_detents = mount_on_short_side ? det_across_width : det_across_depth;

echo(str("=========================================================="));
echo(str("  Canasta: ", basket_width, " x ", basket_depth,
         " x ", basket_height, " mm"));
echo(str("  ROI del receptor: ", roi_fov, " grados (+/- ", roi_half, ")"));
echo(str("  Sensor a ", round(pod_reach + pod_arm), " mm de la pared como",
         " maximo, y ", round(pivot_drop + pod_arm), " mm por debajo del borde"));
echo(str("----------------------------------------------------------"));
echo(str("  Detentes validos apuntando a traves de los ", basket_width,
         " mm: ", det_across_width));
echo(str("  Detentes validos apuntando a traves de los ", basket_depth,
         " mm: ", det_across_depth));
echo(str("----------------------------------------------------------"));
echo(str("  >> MONTAR LA MORDAZA EN MITAD DEL LADO ",
         mount_on_short_side ? "CORTO" : "LARGO",
         ", apuntando a traves de los ", aim_span, " mm"));
echo(str("  >> Posiciones utilizables: ", usable_detents, " grados"));

// --- Distancia que va a leer el sensor -------------------------------------
// Estas son las cifras con las que hay que calibrar d_vacia y d_llena en
// Grafana. Si cambias de detente, cambian.
theta_nom = len(usable_detents) > 0
              ? usable_detents[floor(len(usable_detents) / 2)]
              : 0;

h_nom    = sensor_h(theta_nom);
d_empty  = h_nom / cos(theta_nom);
egg_pile = 100;                 // mm de huevos apilados, estimacion
d_full   = (h_nom - egg_pile) / cos(theta_nom);

echo(str("----------------------------------------------------------"));
echo(str("  Detente nominal: ", theta_nom, " grados"));
echo(str("  El ROI barre del mm ", round(near_hit(theta_nom)),
         " al ", round(far_hit(theta_nom)), " sobre un vano de ",
         aim_span, " mm"));
echo(str("  d_vacia estimada: ", round(d_empty), " mm"));
echo(str("  d_llena estimada: ", round(d_full),
         " mm (con ", egg_pile, " mm de huevos)"));
echo(str("  Recorrido util:   ", round(d_empty - d_full), " mm"));
echo(str("  Modo del VL53L1X: ",
         d_empty < 1300 ? "SHORT (el mas inmune a luz ambiente)"
                        : d_empty < 3000 ? "MEDIUM" : "LONG"));
echo(str("=========================================================="));

assert(len(usable_detents) > 0,
  str("Ningun angulo sirve. O la canasta es demasiado profunda y estrecha ",
      "para el cono del VL53L1X, o detent_step es demasiado grueso y se ",
      "salta la ventana valida. Opciones: bajar detent_step, acortar ",
      "pod_arm, o pasar a un VL53L5CX multizona."));

assert(len(usable_detents) > 1,
  str("Solo hay una posicion de detente valida (", usable_detents,
      "), asi que la articulacion regulable no aporta nada. Baja ",
      "detent_step en params.scad."));
