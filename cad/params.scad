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

   Quien manda en el TAMANO de la pieza es hirth_r_out, y quien manda en la
   RESOLUCION es detent_step. No hay que confundirlos: la tentacion es subir
   los dos radios para que el diente salga ancho, y eso hincha la pieza
   entera sin necesidad.

   El flanco mide 2*pi*r*(step/2)/360, o sea que se estrecha hacia el centro.
   Con r_out=17 y step=4 el flanco exterior mide 0.59 mm, comodo para una
   boquilla de 0.4. En r_in=11 baja a 0.38 mm y los dientes de dentro salen
   redondeados, y no pasa nada por dos razones: el par crece con el radio,
   asi que esos dientes apenas trabajan, y como las dos caras se imprimen
   con el mismo perfil se redondean igual y siguen encajando.

   Regla practica: dimensiona hirth_r_out para que el flanco exterior pase
   de 0.5 mm, y deja hirth_r_in en lo que haga falta para que quepa la
   cabeza del tornillo del pivote.                                          */

detent_step   = 4;     // grados por posicion (90 posiciones en 360)
hirth_r_in    = 11;    // mm, radio interior de la corona dentada
hirth_r_out   = 17;    // mm, radio exterior
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
pcb_hole_d       = 2.3;   // mm, M2 PASANTE (no piloto: no se usan autorroscantes)
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
// PCB libre el disco dentado. Vive aqui, y no dentro de sensor_head.scad,
// porque geometry.scad lo necesita para saber donde acaba mirando el sensor.
pod_arm = hirth_r_out + pcb_w / 2 + 6;   // mm

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

// Gancho de la caja: pata exterior larga (es donde se atornilla la caja) y
// pata interior corta (solo tiene que enganchar).
box_hook_w   = 26;
box_hook_out = 40;
box_hook_in  = 18;

/* [Impresion] ----------------------------------------------------------- */

nozzle  = 0.4;
layer_h = 0.2;
fit     = 0.25;   // holgura generica pieza-a-pieza

$fn = 72;
