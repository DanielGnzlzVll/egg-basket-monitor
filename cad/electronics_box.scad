// ===========================================================================
//  egg-basket-monitor  ::  caja de electronica
//
//  Celda 18650 + TP4056 + ESP32-C3 SuperMini. Cuelga POR FUERA de la canasta
//  con el mismo gancho al borde que la cabeza del sensor. Va fuera y no
//  dentro por dos razones: la celda de litio no queda suspendida sobre la
//  comida, y su peso contrarresta al del pod, que tira hacia dentro.
//
//  La cara de abajo es plana a proposito: sin el gancho, la caja se sostiene
//  de pie sobre la mesa.
//
//  TRES PIEZAS, ninguna necesita soportes:
//    box  -> con la boca hacia arriba
//    lid  -> plana
//    hook -> de canto (prisma puro, igual que la mordaza del sensor)
//
//  DISPOSICION: la celda va de pie contra una pared y los dos modulos al
//  lado, tumbados contra el fondo. Asi la caja queda de 24 mm de fondo en vez
//  de 32: pegada a la pared de la canasta hace menos palanca. Los 13 mm que
//  quedan libres por delante de los modulos no se desperdician, son para el
//  cableado Dupont, que abulta mas que los propios modulos.
//
//  Uso:  openscad -D 'part="box"' -o box.stl electronics_box.scad
//        part = "box" | "lid" | "hook" | "assembly"
// ===========================================================================

include <lib/rim_hook.scad>    // arrastra params.scad

part = "assembly";

// --- Cotas derivadas -------------------------------------------------------
// Marco: X a lo largo del borde, Y hacia arriba, Z hacia fuera de la canasta.
// Z=0 es la cara trasera, la que se apoya en la pared.

box_floor = 6;      // suelo grueso: dentro va el nicho del muelle
box_ceil  = 5;      // techo grueso: dentro va la lamina de laton
divider_t = 2.0;

cell_bay_w  = cell_d + 1;
board_bay_w = max(tp_l, mcu_l) + 3;

in_w = cell_bay_w + divider_t + board_bay_w;
in_h = cell_l + 2;                       // cell_l ya lleva holgura dentro
in_d = cell_d + 1;

out_w = in_w + 2 * box_wall;
out_h = box_floor + in_h + box_ceil;
out_d = box_wall + in_d;                 // sin la tapa

x0 = box_wall;            // cara interior de la pared -X
y0 = box_floor;           // cara superior del suelo
z0 = box_wall;            // cara interior del fondo
lid_z = z0 + in_d;

cx  = x0 + cell_bay_w / 2;      // eje de la celda
cz  = z0 + in_d / 2;
bx0 = x0 + cell_bay_w + divider_t;   // inicio del vano de modulos

tp_y  = y0 + 12;          // TP4056 abajo, ESP32 encima
mcu_y = y0 + 31;

// Los dos modulos van pegados a la pared +X, no centrados: los dos sacan el
// USB-C por ahi y asi el conector queda enfrente de su agujero.
board_gap = 1.5;          // del canto del modulo a la cara interior de la pared

// Tapa: dos bosses interiores por el lado de los modulos y dos orejas
// exteriores por el lado de la celda. No hay bosses interiores en ese lado
// porque la celda ocupa el rincon entero.
lid_y   = [y0 + 5, y0 + in_h - 5];
boss_x  = out_w - box_wall - 6;
ear_x   = -4;
ear_w   = 8;

// Espina para colgar del gancho: engorda la zona alta del tabique para poder
// embutir ahi dos tuercas M3.
hook_cx  = 30;
spine_y0 = y0 + in_h - 18;
spine_y1 = y0 + in_h;
spine_z  = 8;
hook_hole_y = [out_h - 10, out_h - 18];

// El tornillo de apriete del gancho va ARRIBA del todo y la caja cuelga por
// debajo de el. Si se solaparan, el saliente de 6 mm del tornillo chocaria
// contra el fondo de la caja y esta no apoyaria plana contra la pata.
box_hook_screw_z = -7;
box_hang_drop    = 16;   // cuanto baja el techo de la caja bajo el borde
box_hook_pad     = 3.2;

be = 0.01;

// ===========================================================================
//  CAJA
// ===========================================================================

// Marco en relieve que posiciona un modulo. Se hace en relieve y no rebajado
// para no adelgazar el fondo, que solo tiene box_wall de espesor.
module board_frame(l, w, y) {
    fw = 1.5;             // ancho del marco
    fh = board_recess;    // alto
    x  = out_w - box_wall - board_gap - l - fit;   // alineado a la derecha
    difference() {
        translate([x - fw, y - fw, z0])
            cube([l + fit + 2 * fw, w + fit + 2 * fw, fh]);
        translate([x, y, z0 - 1])
            cube([l + fit, w + fit, fh + 2]);
    }
}

module box() {
    difference() {
        union() {
            // Cuerpo hueco, abierto por +Z.
            difference() {
                cube([out_w, out_h, out_d]);
                translate([x0, y0, z0]) cube([in_w, in_h, in_d + 1]);
            }

            // Tabique que impide que la celda se pase al vano de modulos.
            // Solo 10 mm de fondo: por delante pasan los cables.
            translate([x0 + cell_bay_w, y0, z0]) cube([divider_t, in_h, 10]);

            // Espina con las tuercas del gancho.
            translate([hook_cx - 7, spine_y0, z0]) cube([14, spine_y1 - spine_y0, spine_z]);

            // Bosses de la tapa, lado de los modulos.
            for (y = lid_y) translate([boss_x, y, z0]) cylinder(d = box_boss_d, h = in_d);

            // Orejas de la tapa, lado de la celda.
            for (y = lid_y) translate([ear_x - ear_w / 2, y - 6, 0]) cube([ear_w, 12, out_d]);

            board_frame(tp_l,  tp_w,  tp_y);
            board_frame(mcu_l, mcu_w, mcu_y);
        }

        // --- Taladros de la tapa -------------------------------------------
        for (y = lid_y) {
            translate([boss_x, y, lid_z - 10]) cylinder(d = box_screw_d - 0.5, h = 10 + be);
            translate([ear_x,  y, out_d - 10]) cylinder(d = box_screw_d - 0.5, h = 10 + be);
        }

        // --- Sujecion al gancho: pasante desde atras, tuerca por dentro -----
        for (y = hook_hole_y) {
            translate([hook_cx, y, -1])
                cylinder(d = box_screw_d, h = z0 + spine_z + 2);
            translate([hook_cx, y, z0 + spine_z - nut_h])
                cylinder(d = nut_af / cos(30), h = nut_h + be, $fn = 6);
        }

        // --- Contactos de la celda ------------------------------------------
        // Negativo abajo: nicho para un muelle de boligrafo. El muelle come la
        // diferencia entre celdas de 65 y de 70 mm, que es real y grande.
        translate([cx, y0 + be, cz]) rotate([90, 0, 0])
            cylinder(d = spring_d, h = spring_h + be);

        // Positivo arriba: rebaje para una lamina de laton.
        translate([cx - strip_w / 2, y0 + in_h - be, cz - 7])
            cube([strip_w, strip_t + 0.2 + be, 14]);

        // Paso de los dos cables de la celda al vano de modulos.
        for (y = [y0 + 6, y0 + in_h - 6])
            translate([x0 + cell_bay_w - 1, y, z0 + 5]) rotate([0, 90, 0])
                cylinder(d = 5, h = divider_t + 2);

        // --- Huecos de los dos USB-C, los dos en la misma cara --------------
        for (b = [[tp_y, tp_w], [mcu_y, mcu_w]])
            translate([out_w - box_wall - 1, b[0] + b[1] / 2 - usb_w / 2, z0 - be])
                cube([box_wall + 2, usb_w, usb_h]);
    }
}

// ===========================================================================
//  TAPA
// ===========================================================================

module lid() {
    difference() {
        union() {
            cube([out_w, out_h, box_lid_t]);
            for (y = lid_y)
                translate([ear_x - ear_w / 2, y - 6, 0]) cube([ear_w, 12, box_lid_t]);
        }
        for (y = lid_y) {
            translate([boss_x, y, -1]) cylinder(d = box_screw_d, h = box_lid_t + 2);
            translate([ear_x,  y, -1]) cylinder(d = box_screw_d, h = box_lid_t + 2);
        }
        // Ventilacion sobre la celda. Una celda de litio en una caja estanca
        // en una cocina es justo lo que no hay que hacer.
        for (i = [0 : 4])
            translate([cx - 6, y0 + 12 + i * 11, -1]) cube([12, 3, box_lid_t + 2]);
    }
}

// ===========================================================================
//  GANCHO
// ===========================================================================

module hook() {
    difference() {
        rim_hook(box_hook_w, box_hook_out, box_hook_in, box_hook_pad,
                 box_hook_screw_z);
        // Pasantes hacia la espina de la caja. La cabeza apoya en la cara
        // exterior, que queda accesible con la caja ya colgada.
        for (y = hook_hole_y)
            translate([-clamp_wall - 1, 0, -(box_hang_drop + out_h - y)])
                rotate([0, 90, 0])
                    cylinder(d = box_screw_d, h = clamp_wall + 2);
    }
}

// ===========================================================================
//  ENSAMBLAJE  (solo para mirar)
// ===========================================================================

// La caja trabaja en su propio marco (Y es la vertical). Aqui se gira para
// que la vista salga con la gravedad donde toca.
module assembly() { rotate([90, 0, 0]) assembly_raw(); }

module assembly_raw() {
    color("SteelBlue") box();
    color("Silver")    translate([0, 0, lid_z]) lid();

    // La celda, para ver que cabe.
    color("DimGray", 0.6)
        translate([cx, y0 + 1, cz]) rotate([-90, 0, 0])
            cylinder(d = cell_d, h = in_h - 3);

    // El gancho vive en otro marco (x hacia dentro de la canasta, z hacia
    // abajo). Esta matriz lo trae al marco de la caja: gancho +x -> caja -z,
    // gancho +y -> caja -x, gancho +z -> caja +y.
    multmatrix([[ 0, -1, 0, hook_cx],
                [ 0,  0, 1, out_h + box_hang_drop],
                [-1,  0, 0, -clamp_wall],
                [ 0,  0, 0, 1]]) {
        color("Goldenrod") hook();
        color("Tan", 0.25) translate([0, -70, -160])
            cube([rim_thickness, 140, 160]);   // trozo de pared, solo contexto
    }
}

// --- Seleccion de pieza ----------------------------------------------------
echo(str("--- Caja de electronica ----------------------------------"));
echo(str("  Exterior: ", out_w, " x ", out_h, " x ",
         round((out_d + box_lid_t) * 10) / 10, " mm (mas orejas)"));
// El muelle es lo que hace que valga cualquier celda: da igual que sea una de
// 65 sin proteger o una de 69 con PCB, el muelle come la diferencia.
echo(str("  Hueco de ", in_h, " mm: acepta celdas de ",
         round(in_h - strip_t - 7), " a ", round(in_h - strip_t), " mm"));
echo(str("  Tornilleria: 4x M3x10 autorroscante (tapa), 2x M3x",
         ceil(clamp_wall + z0 + spine_z), " + 2 tuercas (gancho),",
         " 1x M3x16 (apriete)"));
echo(str("=========================================================="));

assert(spring_h < box_floor - 1.5, "El nicho del muelle atraviesa el suelo.");
assert(tp_y > lid_y[0] + box_boss_d / 2,
       "El TP4056 pisa el boss inferior de la tapa. Sube tp_y.");
assert(tp_y + tp_w < mcu_y, "El TP4056 choca con el MCU.");
assert(mcu_y + mcu_w < spine_y0,
       "El modulo MCU choca con la espina del gancho. Baja mcu_y o sube in_h.");
assert(mcu_y + mcu_w < lid_y[1] - box_boss_d / 2,
       "El MCU pisa el boss superior de la tapa.");
assert(hook_cx - 7 > x0 + cell_bay_w - 1,
       "La espina del gancho invade el hueco de la celda. Sube hook_cx.");
for (y = hook_hole_y) {
    assert(y > spine_y0 + 4 && y < spine_y1 - 4,
           "Un tornillo del gancho cae fuera de la espina.");
    assert(box_hang_drop + out_h - y < box_hook_out - 4,
           "Un tornillo del gancho cae por debajo de la pata exterior.");
    assert(box_hang_drop + out_h - y > -box_hook_screw_z + 7,
           "Un tornillo del gancho pisa el saliente del de apriete.");
}

if      (part == "box")      box();
else if (part == "lid")      lid();
else if (part == "hook")     hook();
else if (part == "assembly") assembly();
else assert(false, str("part desconocida: ", part));
