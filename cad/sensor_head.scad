// ===========================================================================
//  egg-basket-monitor  ::  cabeza del sensor
//
//  Se cuelga del borde de la canasta y apunta el VL53L1X hacia el fondo con
//  un angulo regulable por detentes. Solo depende de `rim_thickness`: sirve
//  para cualquier canasta cambiando ese numero.
//
//  CUATRO PIEZAS, todas imprimibles sin un solo soporte:
//    clamp   -> de canto (prisma puro, cada capa es el mismo perfil en U)
//    plate   -> plana, dientes hacia arriba
//    pod     -> plano, dientes hacia arriba
//    knob    -> plano
//
//  TORNILLERIA: las longitudes las calcula y las imprime el propio modelo al
//  compilar, porque dependen de cotas que puedes cambiar. Ver el bloque ECHO.
//
//  ORDEN DE MONTAJE (importa, hay piezas que quedan cautivas):
//    1. Meter a presion las 2 tuercas M3 en la cara trasera de la placa.
//    2. Meter el perno del pivote en la placa por detras; queda enrasado en
//       su avellanado.
//    3. Atornillar la placa a la mordaza desde fuera. La cara de la mordaza
//       tapa la cabeza del pivote y le impide girar: ya no hace falta
//       sujetarla nunca mas, el angulo se cambia solo con el pomo.
//    4. Tuerca M3 a presion en el pomo.
//    5. Pod sobre el pivote, engranar los dientes, apretar el pomo a mano.
//
//  Uso:  openscad -D 'part="clamp"' -o clamp.stl sensor_head.scad
//        part = "clamp" | "plate" | "pod" | "knob" | "assembly"
// ===========================================================================

include <lib/geometry.scad>    // arrastra params.scad y valida el apuntado
include <lib/rim_hook.scad>    // perfil en U, compartido con la caja
use     <lib/hirth.scad>

part = "assembly";

// --- Cotas derivadas -------------------------------------------------------
slot      = hook_slot;               // viene de lib/rim_hook.scad
pad       = 8;                       // espesor de la pata interior con tornillos
px        = rim_thickness + pod_reach;   // X del eje del pivote
pz        = -pivot_drop;                 // Z del eje del pivote

y_plate0  = clamp_width / 2;             // cara lateral de la mordaza
y_teeth   = y_plate0 + plate_t;          // plano base de los dientes
y_pod     = y_teeth + hirth_h;           // plano base de los dientes del pod

mount_gx  = slot + pad / 2;              // tornillos placa-mordaza, en global
mount_gz  = -clamp_grip_in / 2;
mount_lx  = mount_gx - px;               // ...y en el frame local de la placa
mount_ly  = -(mount_gz - pz);

tight_gz  = -clamp_grip_out / 2;         // tornillo de apriete
boss_t    = hook_boss;

wall_t    = 6;                           // espesor de la pared que sujeta el PCB
eps       = 0.01;

head_cbore_d = 6.6;                      // avellanado de la cabeza del pivote
head_cbore   = 3.2;

rib_t = 3.0;                             // nervios brazo-pared del pod
rib_h = 12;
rib_l = 12;

// --- Longitudes de tornilleria, calculadas ---------------------------------
// Se recalculan solas si cambias cualquier cota. Redondear hacia arriba al
// tamano comercial siguiente (10, 12, 16, 20, 25, 30...).
pivot_seat  = y_plate0 + head_cbore;                       // asiento de la cabeza
pivot_nut   = y_pod + hirth_backing + nut_h;               // cara lejana de la tuerca
pivot_len   = pivot_nut - pivot_seat;

// cabeza en la cara -Y de la mordaza, tuerca en la cara +Z de la placa:
// atraviesa la mordaza entera mas lo que hay hasta el fondo de la tuerca
mount_len   = clamp_width + nut_h;
tight_len   = rim_hook_screw_len();                        // + recorrido de apriete
// De la cara delantera de la pared a la cara lejana de la tuerca, pasando por
// el fondo del bolsillo y el PCB.
sensor_len  = wall_t - pcb_pocket_clear + m2_nut_h + 0.5;

// En todo el proyecto no hay un solo autorroscante: donde el tornillo no
// encuentra tuerca al otro lado, la tuerca va embutida en la propia pieza.
echo(str("--- Tornilleria (minimos, redondear al alza) -------------"));
echo(str("  Pivote        M3 x ", round(pivot_len * 10) / 10, " mm  + 1 tuerca (en el pomo)"));
echo(str("  Placa-mordaza M3 x ", round(mount_len * 10) / 10, " mm  x2 + 2 tuercas (en la placa)"));
echo(str("  Apriete       M3 x ", round(tight_len * 10) / 10, " mm  + 1 tuerca (cautiva en el saliente)"));
echo(str("  Sensor        M2 x ", round(sensor_len * 10) / 10, " mm  x2 + 2 tuercas (sueltas, por detras del PCB)"));
echo(str("=========================================================="));

// --- Que modulos VL53L1X caben ---------------------------------------------
// Los dos limites reales al elegir breakout. Ninguno tiene que ver con el
// apuntado: la canasta tiene 500 mm de fondo y un brazo de 30 no la inmuta.
// Son puramente mecanicos, y por eso son faciles de pasar por alto.
pcb_support = (pcb_w + 2 * pcb_pocket_clear - window_d) / 2;   // material que
                                                               // queda arriba
                                                               // y abajo del PCB
echo(str("--- Modulo VL53L1X ---------------------------------------"));
echo(str("  Con ", pcb_l, " x ", pcb_w, " mm el PCB apoya sobre ",
         round(pcb_support * 100) / 100, " mm de reborde"));
echo(str("  Ancho minimo del PCB: ", window_d + 4, " mm (ventana de ",
         window_d, " + 2 mm de apoyo por lado)"));
echo(str("  Separacion minima de agujeros: ",
         window_d + pcb_hole_d + 1, " mm (si no, el agujero cae en la ventana)"));
echo(str("=========================================================="));

assert(pcb_support >= 2,
       str("El PCB solo apoyaria sobre ", pcb_support, " mm. O el modulo es ",
           "mas ancho (pcb_w >= ", window_d + 4, ") o la ventana mas pequena."));
assert(pcb_hole_spacing / 2 > window_d / 2 + pcb_hole_d / 2 + 0.5,
       "Los agujeros de montaje del modulo caen dentro de la ventana optica.");
assert(pcb_hole_spacing < pcb_l - 2,
       "Los agujeros de montaje se salen del PCB. Revisa la medida.");

// ===========================================================================
//  MORDAZA
// ===========================================================================

module clamp() {
    difference() {
        rim_hook(clamp_width, clamp_grip_out, clamp_grip_in, pad, tight_gz,
                 ribs = grip_ribs);

        // Tornillos de la placa de bisagra. Pasantes lisos: la cabeza apoya
        // en esta cara (-Y, la de fuera, accesible con la llave) y la tuerca
        // va embutida en la placa. Asi la cara +Y de la placa queda limpia,
        // que es donde se apoya el disco dentado del pod.
        for (s = [-1, 1])
            translate([mount_gx, clamp_width / 2 + 1, mount_gz + s * plate_screw_sep / 2])
                rotate([90, 0, 0]) cylinder(d = plate_screw_d, h = clamp_width + 2);

        // Pasacables en el puente.
        translate([slot + pad / 2, 0, clamp_wall + 1])
            rotate([90, 0, 0]) cylinder(d = wire_channel_d, h = clamp_width + 2,
                                        center = true);
    }
}

// ===========================================================================
//  PLACA DE BISAGRA   (frame local: origen en el pivote, dientes hacia +Z)
// ===========================================================================

module plate() {
    difference() {
        union() {
            hirth_disc(detent_step, hirth_r_in, hirth_r_out, hirth_h,
                       plate_t, pivot_screw_d);
            translate([0, 0, -plate_t]) linear_extrude(plate_t, convexity = 4)
                hull() {
                    circle(r = hirth_r_out * 0.75);
                    translate([mount_lx, mount_ly - plate_screw_sep / 2])
                        circle(d = plate_w);
                    translate([mount_lx, mount_ly + plate_screw_sep / 2])
                        circle(d = plate_w);
                }
        }
        // Tornillos hacia la mordaza, con la tuerca embutida por la cara de
        // atras. Se meten las dos tuercas a presion, se apoya la placa en la
        // mordaza y se atornilla desde fuera.
        for (s = [-1, 1])
            translate([mount_lx, mount_ly + s * plate_screw_sep / 2, -plate_t - 1]) {
                cylinder(d = plate_screw_d, h = plate_t + 2);
                cylinder(d = nut_af / cos(30), h = 1 + nut_h, $fn = 6);
            }

        // Avellanado del perno del pivote: la cabeza queda enrasada y la cara
        // lateral de la mordaza la retiene, asi no hace falta sujetarla.
        translate([0, 0, -plate_t - eps]) cylinder(d = head_cbore_d, h = head_cbore);
    }
}

// ===========================================================================
//  POD DEL SENSOR   (frame local: origen en el pivote, dientes hacia +Z,
//                    direccion de apuntado = -Y)
// ===========================================================================

module pod() {
    pocket_l = pcb_l + 2 * pcb_pocket_clear;
    pocket_w = pcb_w + 2 * pcb_pocket_clear;
    body_h   = pocket_w + 2 * clamp_wall;          // alto del pod en Z local

    difference() {
        union() {
            // medio paso de desfase: es lo que hace que dos coronas
            // identicas engranen en vez de chocar pico contra pico
            hirth_disc(detent_step, hirth_r_in, hirth_r_out, hirth_h,
                       hirth_backing, pivot_screw_d, phase = detent_step / 2);

            // brazo, en el plano del disco
            translate([0, 0, -hirth_backing])
                linear_extrude(hirth_backing, convexity = 4)
                    hull() {
                        circle(r = hirth_r_out * 0.75);
                        translate([0, -pod_arm + wall_t / 2])
                            square([pocket_l + 2 * clamp_wall, wall_t],
                                   center = true);
                    }

            // pared que sostiene el PCB, perpendicular al apuntado
            translate([0, -pod_arm + wall_t / 2, -hirth_backing])
                linear_extrude(body_h)
                    square([pocket_l + 2 * clamp_wall, wall_t], center = true);

            // Dos nervios de refuerzo. Sin ellos, un brazo de hirth_backing
            // de espesor sujeta en voladizo una pared de body_h de alto: la
            // union en T se parte al primer golpe. Van en los extremos, por
            // detras de la pared, para no invadir ni el bolsillo del PCB ni
            // el cono optico.
            for (s = [-1, 1])
                translate([s * (pocket_l + clamp_wall) / 2,
                           -pod_arm + wall_t, -hirth_backing])
                    rotate([0, 90, 0])
                        linear_extrude(rib_t, center = true)
                            polygon([[0, 0], [-rib_h, 0], [0, rib_l]]);
        }

        // Bolsillo del PCB, abierto por la cara trasera (+Y local).
        translate([-pocket_l / 2, -pod_arm + wall_t - (pcb_t + pcb_pocket_clear),
                   -hirth_backing + clamp_wall])
            cube([pocket_l, pcb_t + pcb_pocket_clear + eps, pocket_w]);

        // Ventana optica: atraviesa la pared en la direccion de apuntado.
        translate([optics_offset, -pod_arm + wall_t + 1, -hirth_backing + body_h / 2])
            rotate([90, 0, 0]) cylinder(d = window_d, h = wall_t + 2);

        // Pasantes M2 para el modulo. Pasantes y no pilotos: el tornillo entra
        // por delante, atraviesa la pared y el PCB, y aprieta contra una tuerca
        // M2 suelta por detras, que es lo que sujeta el modulo contra el fondo
        // del bolsillo. Apretar con los dedos: una tuerca contra un PCB
        // desnudo, a llave, lo raja.
        for (s = [-1, 1])
            translate([s * pcb_hole_spacing / 2, -pod_arm + wall_t + 1,
                       -hirth_backing + body_h / 2])
                rotate([90, 0, 0]) cylinder(d = pcb_hole_d, h = wall_t + 2);

        // Salida de los Dupont por arriba.
        translate([0, -pod_arm + wall_t / 2, -hirth_backing + body_h - 1])
            cube([wire_channel_d, wall_t + 2, 6], center = true);
    }
}

// ===========================================================================
//  POMO DE APRIETE
// ===========================================================================

module knob() {
    difference() {
        union() {
            cylinder(d = knob_d * 0.72, h = knob_h);
            for (i = [0 : knob_lobes - 1]) rotate([0, 0, i * 360 / knob_lobes])
                translate([knob_d * 0.36, 0, 0]) cylinder(d = knob_d * 0.30, h = knob_h);
        }
        translate([0, 0, -eps]) cylinder(d = pivot_screw_d, h = knob_h + 1);
        translate([0, 0, -eps]) cylinder(d = nut_af / cos(30), h = nut_h + eps, $fn = 6);
    }
}

// ===========================================================================
//  ENSAMBLAJE  (solo para mirar; no se exporta)
// ===========================================================================

module basket_context() {
    color("Tan", 0.25) {
        translate([0, -60, -basket_height]) cube([rim_thickness, 120, basket_height]);
        translate([0, -60, -basket_height]) cube([basket_width, 120, 2]);
    }
}

module assembly() {
    basket_context();
    color("SteelBlue")  clamp();
    color("Goldenrod")  translate([px, y_teeth, pz]) rotate([-90, 0, 0]) plate();
    color("Crimson")    translate([px, y_pod,   pz]) rotate([ 90, 0, 0])
                            rotate([0, 0, angle_preview]) pod();
    color("DimGray")    translate([px, y_pod + hirth_backing + 1, pz])
                            rotate([-90, 0, 0]) knob();
}

// --- Seleccion de pieza ----------------------------------------------------
if      (part == "clamp")    clamp();
else if (part == "plate")    plate();
else if (part == "pod")      pod();
else if (part == "knob")     knob();
else if (part == "assembly") assembly();
else assert(false, str("part desconocida: ", part));
