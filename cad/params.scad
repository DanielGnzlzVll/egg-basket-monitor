// ===========================================================================
//  egg-basket-monitor  ::  parametros globales
//  Toda cota que puedas necesitar cambiar vive AQUI. Ningun otro archivo
//  deberia tener numeros magicos.
// ===========================================================================

/* [Canasta] --------------------------------------------------------------
   Solo `rim_thickness` afecta a la geometria de la mordaza. Las otras tres
   medidas se usan unicamente para calcular el rango util de angulos y para
   la vista de contexto. Cambiar de canasta = cambiar rim_thickness.        */

basket_width   = 300;   // mm, lado largo de la boca
basket_depth   = 150;   // mm, lado corto de la boca
basket_height  = 500;   // mm, del borde al fondo
rim_thickness  = 10;    // mm, espesor de la pared donde muerde la mordaza

/* [Optica del VL53L1X] ---------------------------------------------------
   El emisor dispara SIEMPRE un cono de 27 grados y eso no es configurable.
   Solo el receptor admite ROI, hasta un minimo de 15 grados con 4x4 SPADs.
   Ese 15 es el numero que manda para el calculo de angulos.                */

emitter_cone = 27;      // grados, fijo por hardware
roi_fov      = 15;      // grados, ROI de 4x4 SPADs (el mas estrecho posible)
wall_margin  = 20;      // mm que el borde del ROI debe dejar libres contra
                        // cualquier pared en el fondo de la canasta

/* [Mordaza] ------------------------------------------------------------- */

clamp_width      = 26;    // mm a lo largo del borde
clamp_wall       = 3.2;   // mm de pared
clamp_grip_out   = 20;    // mm que baja por fuera de la canasta
clamp_grip_in    = 34;    // mm que baja por dentro
clamp_clearance  = 0.8;   // holgura sobre rim_thickness
clamp_screw_d    = 3.4;   // M3 pasante para el tornillo de apriete
nut_af           = 6.2;   // entrecaras de la tuerca M3
nut_h            = 2.8;   // espesor de la tuerca M3
grip_ribs        = true;  // nervios antideslizantes dentro de la mordaza

/* [Placa de bisagra] -----------------------------------------------------
   Pieza plana que se atornilla a la cara lateral de la mordaza y lleva en su
   punta la corona Hirth. Existe como pieza aparte por una sola razon: asi la
   mordaza queda como un prisma puro (se imprime de canto, sin un solo
   soporte) y la corona se imprime plana con los dientes hacia arriba, que es
   la unica orientacion en que salen definidos.                             */

plate_t          = 6.0;   // mm de espesor (>= nut_h + 3, la tuerca se embute
                          //  por la cara de atras y debe quedar material)
plate_w          = 18;    // mm de ancho del brazo
plate_screw_d    = 3.4;   // M3 pasante hacia la mordaza
plate_screw_sep  = 16;    // mm entre los dos tornillos de sujecion
pivot_drop       = 28;    // mm del borde de la canasta al eje del pivote

/* [Pomo de apriete] ----------------------------------------------------- */

knob_d     = 24;
knob_h     = 9;
knob_lobes = 6;

/* [Articulacion Hirth] ---------------------------------------------------
   Dos caras dentadas identicas que engranan cada `detent_step` grados.
   Se aflojan a mano, se gira, se vuelven a apretar.

   Lo que limita el paso es hirth_r_in, no el paso en si: el diente es mas
   estrecho cuanto mas cerca del centro, y donde se redondea al imprimir es
   en el radio interior. El flanco util ahi mide 2*pi*r_in*(step/2)/360.
   Con r_in=18 y step=4 salen 0.63 mm, comodo para una boquilla de 0.4.
   Regla: si bajas detent_step, sube hirth_r_in en la misma proporcion.     */

detent_step   = 4;     // grados por posicion (90 posiciones en 360)
hirth_r_in    = 18;    // mm, radio interior de la corona dentada
hirth_r_out   = 26;    // mm, radio exterior
hirth_h       = 1.4;   // mm, altura del diente
hirth_backing = 3.2;   // mm, espesor del disco detras de los dientes
pivot_screw_d = 3.4;   // M3 pasante del eje

/* [Angulo de apuntado] ---------------------------------------------------
   0 grados = mirando recto hacia abajo, pegado a la pared.
   Positivo = inclinado hacia el interior de la canasta.
   El maximo seguro lo calcula geometria.scad; no lo fijes a ojo.           */

angle_min     = 0;
angle_max     = 30;
angle_preview = 16;    // solo para la vista de ensamblaje (debe ser un detente valido)

/* [Modulo VL53L1X] -------------------------------------------------------
   MEDIR EL MODULO REAL CUANDO LLEGUE. Los breakout de AliExpress varian
   entre 20x11 y 25x13 mm y la separacion de agujeros cambia con cada lote. */

pcb_l            = 25.0;  // mm, largo del PCB
pcb_w            = 11.0;  // mm, ancho del PCB
pcb_t            = 1.6;   // mm, espesor del PCB
pcb_hole_spacing = 20.0;  // mm entre centros de los agujeros de montaje
pcb_hole_d       = 2.1;   // mm, agujero para tornillo M2 autorroscante
pcb_pocket_clear = 0.4;   // holgura del bolsillo
// Ventana optica. Tiene que dejar pasar el cono de 27 grados desde la
// apertura del sensor a traves del material que queda por delante del PCB
// (wall_t menos la profundidad del bolsillo, unos 4 mm):
//     2 * (2.7 + 4*tan(13.5)) = 7.3 mm
// Ø8 deja margen. No conviene agrandarla mas: el bolsillo solo mide 11.8 mm
// de alto y una ventana mayor se lo comeria entero, dejando el PCB sin
// apoyo por arriba y por abajo.
window_d         = 8.0;   // mm
optics_offset    = 0;     // mm, del centro del PCB al eje optico (medir)
wire_channel_d   = 6.0;   // mm, canal para los 5 Dupont

/* [Alcance del brazo] ----------------------------------------------------
   Cuanto se mete el sensor hacia el interior de la canasta, medido desde
   la cara interna de la pared. Alejar el sensor de la pared es la unica
   defensa fisica real contra que el cono del emisor la ilumine.
   No se pone una capota: una capota recortada a 27 grados no bloquea nada
   que este dentro del cono, y la pared cercana esta dentro del cono.       */

pod_reach = 26;   // mm, de la cara interna de la pared al eje del pivote

// Del eje del pivote al centro del sensor. Sale de la propia geometria del
// pod, pero vive aqui porque geometry.scad lo necesita para saber donde acaba
// mirando el sensor de verdad.
pod_arm = hirth_r_out + pcb_w / 2 + 10;   // mm

/* [Impresion] ----------------------------------------------------------- */

nozzle  = 0.4;
layer_h = 0.2;
fit     = 0.25;   // holgura generica pieza-a-pieza

$fn = 72;
