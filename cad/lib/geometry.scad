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
// y gana la que admita el rango de angulos mas ancho.
//
// scan_step es solo la resolucion numerica de esta busqueda: con la bisagra
// de friccion no hay detentes fisicos, el angulo se fija por friccion en
// cualquier punto de un rango continuo. No tiene relacion con ninguna pieza.
scan_step  = 0.25;
candidates = [for (a = [0 : scan_step : 60]) a];

function valid_angles(span) = [for (a = candidates) if (aims_ok(a, span)) a];

valid_width = valid_angles(basket_width);
valid_depth = valid_angles(basket_depth);

function span_of(v) = len(v) == 0 ? 0 : (v[len(v) - 1] - v[0]);

mount_on_short_side = span_of(valid_width) >= span_of(valid_depth);
aim_span    = mount_on_short_side ? basket_width : basket_depth;
valid_range = mount_on_short_side ? valid_width : valid_depth;

theta_lo = len(valid_range) > 0 ? valid_range[0] : 0;
theta_hi = len(valid_range) > 0 ? valid_range[len(valid_range) - 1] : 0;

echo(str("=========================================================="));
echo(str("  Canasta: ", basket_width, " x ", basket_depth,
         " x ", basket_height, " mm"));
echo(str("  ROI del receptor: ", roi_fov, " grados (+/- ", roi_half, ")"));
echo(str("  Sensor a ", round(pod_reach + pod_arm), " mm de la pared como",
         " maximo, y ", round(pivot_drop + pod_arm), " mm por debajo del borde"));
echo(str("----------------------------------------------------------"));
echo(str("  Rango valido apuntando a traves de los ", basket_width,
         " mm: ", round(theta_lo * 10) / 10, " - ", round(theta_hi * 10) / 10,
         " grados (", span_of(valid_width), " grados de margen)"));
echo(str("  Rango valido apuntando a traves de los ", basket_depth,
         " mm: (", span_of(valid_depth), " grados de margen)"));
echo(str("----------------------------------------------------------"));
echo(str("  >> MONTAR LA MORDAZA EN MITAD DEL LADO ",
         mount_on_short_side ? "CORTO" : "LARGO",
         ", apuntando a traves de los ", aim_span, " mm"));
echo(str("  >> Rango util de la bisagra de friccion: ",
         round(theta_lo * 10) / 10, " - ", round(theta_hi * 10) / 10, " grados"));

// --- Distancia que va a leer el sensor -------------------------------------
// Estas son las cifras con las que hay que calibrar d_vacia y d_llena en
// Grafana. Si cambias el angulo de apriete, cambian.
theta_nom = (theta_lo + theta_hi) / 2;

h_nom    = sensor_h(theta_nom);
d_empty  = h_nom / cos(theta_nom);
egg_pile = 100;                 // mm de huevos apilados, estimacion
d_full   = (h_nom - egg_pile) / cos(theta_nom);

echo(str("----------------------------------------------------------"));
echo(str("  Angulo nominal (centro del rango): ", theta_nom, " grados"));
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

assert(len(valid_range) > 0,
  str("Ningun angulo sirve. La canasta es demasiado profunda y estrecha ",
      "para el cono del VL53L1X. Opciones: acortar pod_arm o pod_reach, ",
      "o pasar a un VL53L5CX multizona."));

assert(theta_hi - theta_lo >= 4,
  str("El rango valido es de solo ", round((theta_hi - theta_lo) * 10) / 10,
      " grados (", theta_lo, "-", theta_hi, "). Con la bisagra de friccion ",
      "eso no deja margen real para corregir el apuntado a mano. Acorta ",
      "pod_arm o pod_reach para ensanchar el rango."));
