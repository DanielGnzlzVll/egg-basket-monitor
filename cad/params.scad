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
clamp_grip_in    = 34;    // mm que baja por dentro (pata del brazo del sensor)
clamp_clearance  = 0.8;   // holgura sobre rim_thickness
clamp_screw_d    = 3.4;   // M3 pasante para el tornillo de apriete
grip_ribs        = true;  // nervios antideslizantes dentro de la mordaza

/* [Tornilleria] ----------------------------------------------------------
   Todos los tornillos del proyecto son de METRICA NORMAL, de los de toda la
   vida. Ni uno solo es autorroscante, a proposito: donde el tornillo no
   encuentra nada al otro lado, se embute una tuerca hexagonal en la pieza y
   es ella la que hace de rosca. Sale mas fiable que roscar en PLA —se puede
   apretar y aflojar mil veces— y no obliga a comprar tornilleria especial.

   Cotas DIN 934 nominales. Si tus tuercas son de otro sitio, midelas: la
   holgura de estos alojamientos es cero a proposito, para que no giren.     */

nut_af    = 6.2;   // entrecaras de la tuerca M3 (5.5 nominal + holgura)
nut_h     = 2.8;   // espesor de la tuerca M3
m2_nut_af = 4.2;   // entrecaras de la tuerca M2 (4.0 nominal + holgura)
m2_nut_h  = 1.6;   // espesor de la tuerca M2

/* [Pivote] -----------------------------------------------------------------
   pivot_drop: mm del borde de la canasta al eje de la bisagra de friccion.  */

pivot_drop = 28;

/* [Pomo de apriete] ----------------------------------------------------- */

knob_d     = 24;
knob_h     = 9;
knob_lobes = 6;

/* [Bisagra de friccion] ---------------------------------------------------
   Reemplaza a la articulacion Hirth: una oreja plana en el mount con una
   tuerca M3 cautiva, y otra oreja lisa en el pod, con una arandela entre
   las dos caras de contacto. El tornillo entra por el pomo, atraviesa el
   pod y rosca en la tuerca del mount. Sin detentes: el angulo se fija por
   friccion pura. Recalibrar en Grafana tras tocar el pivote.

   La tuerca va del lado de la mordaza/borde (-Y), en un alojamiento
   hexagonal abierto a esa cara: no queda tapada por ninguna otra pieza, la
   sujeta solo el hexagono (no puede girar) y la presion del tornillo una
   vez apretado.                                                            */

hinge_screw_d  = 3.4;   // mm, M3 pasante del pivote
hinge_ear_w    = 22;    // mm, ancho x alto de cada oreja (mount y pod)
hinge_ear_t    = 6.0;   // mm, espesor de cada oreja (>= nut_h + 3, la tuerca
                        // del mount se embute por su cara y debe quedar
                        // material detras, hacia el lado del pod)
hinge_arm_t    = 6.0;   // mm, espesor del brazo que conecta la pata del
                        // mount con la oreja (mismo grosor que la oreja)
                        // Entre las dos orejas va una arandela M3 suelta,
                        // sin modelar: es hardware de compra, no impreso.

/* [Angulo de apuntado] ---------------------------------------------------
   0 grados = mirando recto hacia abajo, pegado a la pared.
   Positivo = inclinado hacia el interior de la canasta.
   El maximo seguro lo calcula geometria.scad; no lo fijes a ojo.           */

angle_min     = 0;
angle_max     = 30;
angle_preview = 16;    // solo para la vista de ensamblaje (debe caer dentro
                       // del rango que calcula lib/geometry.scad)

/* [Modulo VL53L1X] -------------------------------------------------------
   MEDIR EL MODULO REAL CUANDO LLEGUE. Los breakout de AliExpress varian
   entre 20x11 y 25x13 mm y la separacion de agujeros cambia con cada lote. */

pcb_l            = 20.0;  // mm, ancho real del TOF200C
pcb_w            = 11.0;  // mm, alto del PCB
pcb_t            = 1.6;   // mm, espesor del PCB (sin medir, se mantiene)
pcb_hole_spacing = 14.4;  // mm entre centros de agujero, ficha del TOF200C
pcb_hole_d       = 2.3;   // mm, M2 PASANTE (agujero real Ø2, esto da holgura)
pcb_pocket_clear = 0.4;   // holgura del bolsillo
// Ventana optica. Tiene que dejar pasar el cono de 27 grados desde la
// apertura del sensor a traves del material que queda por delante del PCB
// (wall_t menos la profundidad del bolsillo, unos 4 mm):
//     2 * (2.7 + 4*tan(13.5)) = 7.3 mm
// Y no mas: el bolsillo mide pcb_w + 0.8 de alto, asi que cada milimetro de
// ventana se lo come al reborde donde apoya el PCB. Con Ø8 el apoyo bajaba a
// 1.9 mm y el assert de sensor_head.scad salta. Ø7.5 deja 2.15 mm.
window_d         = 7.5;   // mm
optics_offset    = 0;     // mm, del centro del PCB al eje optico (medir)
wire_channel_d   = 6.0;   // mm, canal para los 5 Dupont

/* [Alcance del brazo] ----------------------------------------------------
   Cuanto se mete el sensor hacia el interior de la canasta, medido desde
   la cara interna de la pared. Alejar el sensor de la pared es la unica
   defensa fisica real contra que el cono del emisor la ilumine.
   No se pone una capota: una capota recortada a 27 grados no bloquea nada
   que este dentro del cono, y la pared cercana esta dentro del cono.       */

pod_reach = 16;   // mm, de la cara interna de la pared al eje del pivote

// Del eje del pivote al centro del sensor: lo justo para que la pared del
// PCB libre la oreja de la bisagra de friccion. Vive aqui, y no dentro de
// sensor_head.scad, porque geometry.scad lo necesita para saber donde acaba
// mirando el sensor.
pod_arm = hinge_ear_w / 2 + pcb_w / 2 + 6;   // mm

/* [Caja de electronica] --------------------------------------------------
   Cuelga POR FUERA de la canasta, con su propio gancho al borde. Va fuera y
   no dentro por dos razones: la celda de litio no queda suspendida sobre la
   comida, y su peso contrarresta el del pod, que tira hacia dentro.

   Tambien se sostiene de pie sobre una mesa sin el gancho: la cara de abajo
   es plana a proposito.

   MEDIR LOS MODULOS REALES CUANDO LLEGUEN. Los clones de AliExpress varian.  */

cell_d = 18.6;   // mm, diametro del 18650 (nominal 18.4-18.6)
cell_l = 68;     // mm de hueco: 65 de celda mas el muelle, que come holgura

// Contactos. Nada se suelda a la celda: el cable se suelda al muelle y a la
// lamina ANTES de montarlos, que es igual de fiable y mucho menos peligroso.
spring_d = 7.5;  // nicho del muelle de boligrafo, polo negativo
spring_h = 3.5;  // profundidad del nicho (el muelle va comprimido, no libre)
strip_w  = 10;   // rebaje de la lamina de laton, polo positivo
strip_t  = 0.8;

tp_l  = 26;   tp_w  = 17;   tp_t = 5;    // TP4056 con proteccion
mcu_l = 22.5; mcu_w = 18;   mcu_t = 6;   // ESP32-C3 SuperMini
board_recess = 1.5;                      // alto del reborde que sitia el modulo
// El hueco es para el CONECTOR MACHO con su funda, no para el receptaculo.
usb_w = 12.5; usb_h = 7.5;

box_wall    = 2.4;
box_lid_t   = 2.4;
box_screw_d = 3.4;   // M3 de la tapa

/* [Interfaz congelada con la caja de electronica] -------------------------
   La caja (electronics_box.scad: box/lid) YA ESTA IMPRESA. Estos numeros son
   la interfaz de montaje con la que se taladro esa pieza fisica; los usa
   rim_mount.scad para que el brazo exterior del mount reproduzca el mismo
   gancho que antes generaba electronics_box.scad::hook(). NO se recalculan
   a partir de otras cotas de la caja (in_h, out_h, etc.): son una foto fija
   del objeto real. Si algun dia se reimprime la caja con otras cotas, hay
   que actualizar este bloque a mano.                                       */
box_hook_out      = 40;    // pata exterior larga, donde el mount se atornilla a la caja
box_hook_screw_z  = -7;    // arriba del todo, para no chocar con la caja colgada
box_iface_hole_z  = [-26, -34]; // = -(box_hang_drop + out_h - y), y en [71, 63]
                                // con box_hang_drop=16 y out_h=81 (cell_l=68)

/* [Impresion] ----------------------------------------------------------- */

nozzle  = 0.4;
layer_h = 0.2;
fit     = 0.25;   // holgura generica pieza-a-pieza

$fn = 72;
