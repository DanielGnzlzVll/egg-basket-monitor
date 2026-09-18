// ===========================================================================
//  egg-basket-monitor  ::  cabeza del sensor
//
//  Se cuelga del borde de la canasta y apunta el VL53L1X hacia el fondo con
//  un angulo regulable por friccion (sin detentes). Solo depende de
//  `rim_thickness`: sirve para cualquier canasta cambiando ese numero.
//
//  El punto de apriete al borde y la oreja de la bisagra viven ahora en
//  `rim_mount.scad` (pieza `mount`, fusiona lo que antes eran `clamp` +
//  `plate` + el `hook` de la caja de electronica). Este archivo se queda con
//  las dos piezas que dependen del sensor en si:
//    pod   -> plano, oreja de friccion hacia -Y
//    knob  -> plano
//
//  TORNILLERIA: las longitudes las calcula y las imprime el propio modelo al
//  compilar. Ver el bloque ECHO.
//
//  ORDEN DE MONTAJE:
//    1. Tuerca M3 a presion en el pomo.
//    2. Pod contra la oreja del mount, tornillo M3 + arandela por el medio,
//       apretar el pomo a mano hasta que la friccion sujete el angulo.
//
//  Uso:  openscad -D 'part="pod"' -o pod.stl sensor_head.scad
//        part = "pod" | "knob" | "assembly"
// ===========================================================================

include <lib/geometry.scad>    // arrastra params.scad y valida el apuntado
include <lib/rim_hook.scad>    // perfil en U, compartido con rim_mount.scad

part = "assembly";

// --- Cotas derivadas -------------------------------------------------------
px = rim_thickness + pod_reach;   // X del eje del pivote (global)
pz = -pivot_drop;                 // Z del eje del pivote (global)

// La oreja del pod queda pegada a la oreja del mount (ver rim_mount.scad):
// el mount ocupa hasta su cara +Y (clamp_width/2), la oreja del pod arranca
// justo ahi y crece hinge_ear_t hacia afuera.
y_ear_mount = clamp_width / 2;
y_pod       = y_ear_mount + hinge_ear_t;

wall_t = 6;    // espesor de la pared que sujeta el PCB
eps    = 0.01;

rib_t = 3.0;   // nervios brazo-pared del pod
rib_h = 12;
rib_l = 12;

// De la cara delantera de la pared a la cara lejana de la tuerca, pasando
// por el fondo del bolsillo y el PCB.
sensor_len = wall_t - pcb_pocket_clear + m2_nut_h + 0.5;

echo(str("--- Tornilleria pod ------------------------------------------"));
echo(str("  Sensor  M2 x ", round(sensor_len * 10) / 10,
         " mm  x2 + 2 tuercas (sueltas, por detras del PCB)"));
echo(str("=========================================================="));

// --- Que modulos VL53L1X caben ---------------------------------------------
pcb_support = (pcb_w + 2 * pcb_pocket_clear - window_d) / 2;
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
//  POD DEL SENSOR   (frame local: origen en el eje del pivote, oreja en
//                    z ∈ [0, hinge_ear_t], direccion de apuntado = -Y)
// ===========================================================================

module pod() {
    pocket_l = pcb_l + 2 * pcb_pocket_clear;
    pocket_w = pcb_w + 2 * pcb_pocket_clear;
    body_h   = pocket_w + 2 * clamp_wall;

    // mirror([0,0,1]): la oreja y el brazo quedan en Z local <= 0 en vez de
    // >= 0. Sin esto, la unica rotacion que separa la oreja del pod de la
    // del mount (evitando que ocupen el mismo tramo de Y) es rotate(-90) en
    // X, pero esa MISMA rotacion invierte la direccion de apuntado del
    // sensor (apunta hacia el borde en vez de hacia el fondo). Con el
    // mirror, rotate(+90) en X -que es la que apunta bien- tambien separa
    // las orejas correctamente. Ver assembly() mas abajo.
    mirror([0, 0, 1])
    difference() {
        union() {
            // Oreja de friccion: reemplaza al disco Hirth. Un disco liso
            // de espesor hinge_ear_t con el agujero del pivote centrado.
            cylinder(d = hinge_ear_w, h = hinge_ear_t);

            // brazo, en el mismo plano que la oreja
            linear_extrude(hinge_ear_t, convexity = 4)
                hull() {
                    circle(d = hinge_ear_w * 0.75);
                    translate([0, -pod_arm + wall_t / 2])
                        square([pocket_l + 2 * clamp_wall, wall_t],
                               center = true);
                }

            // pared que sostiene el PCB, perpendicular al apuntado
            translate([0, -pod_arm + wall_t / 2, 0])
                linear_extrude(body_h)
                    square([pocket_l + 2 * clamp_wall, wall_t], center = true);

            // Dos nervios de refuerzo. Sin ellos, la oreja sujeta en
            // voladizo una pared de body_h de alto y la union en T se
            // parte al primer golpe.
            for (s = [-1, 1])
                translate([s * (pocket_l + clamp_wall) / 2,
                           -pod_arm + wall_t, 0])
                    rotate([0, 90, 0])
                        linear_extrude(rib_t, center = true)
                            polygon([[0, 0], [-rib_h, 0], [0, rib_l]]);
        }

        // Agujero del pivote.
        translate([0, 0, -eps])
            cylinder(d = hinge_screw_d, h = hinge_ear_t + 2 * eps);

        // Bolsillo del PCB, abierto por la cara trasera (+Y local).
        translate([-pocket_l / 2, -pod_arm + wall_t - (pcb_t + pcb_pocket_clear),
                   clamp_wall])
            cube([pocket_l, pcb_t + pcb_pocket_clear + eps, pocket_w]);

        // Ventana optica: atraviesa la pared en la direccion de apuntado.
        translate([optics_offset, -pod_arm + wall_t + 1, body_h / 2])
            rotate([90, 0, 0]) cylinder(d = window_d, h = wall_t + 2);

        // Pasantes M2 para el modulo. Pasantes y no pilotos: el tornillo
        // entra por delante, atraviesa la pared y el PCB, y aprieta contra
        // una tuerca M2 suelta por detras.
        for (s = [-1, 1])
            translate([s * pcb_hole_spacing / 2, -pod_arm + wall_t + 1,
                       body_h / 2])
                rotate([90, 0, 0]) cylinder(d = pcb_hole_d, h = wall_t + 2);

        // Salida de los Dupont por arriba.
        translate([0, -pod_arm + wall_t / 2, body_h - 1])
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
        translate([0, 0, -eps]) cylinder(d = hinge_screw_d, h = knob_h + 1);
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
    // rotate(+90) en X: es la que apunta el sensor hacia el fondo de la
    // canasta (-Z). El mirror() dentro de pod() es lo que evita que su
    // oreja choque con la del mount con esta misma rotacion.
    color("Crimson") translate([px, y_pod, pz])
        rotate([90, 0, 0]) rotate([0, 0, angle_preview]) pod();
    color("DimGray") translate([px, y_pod + hinge_ear_t + 1, pz])
        rotate([-90, 0, 0]) knob();
}

// --- Seleccion de pieza ----------------------------------------------------
if      (part == "pod")      pod();
else if (part == "knob")     knob();
else if (part == "assembly") assembly();
else assert(false, str("part desconocida: ", part));
