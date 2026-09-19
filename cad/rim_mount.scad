// ===========================================================================
//  egg-basket-monitor  ::  mount unificado (mordaza + gancho)
//
//  Una sola pieza que se aprieta al borde de la canasta en un UNICO punto y
//  sostiene dos cosas a la vez:
//    - brazo interior: termina en una oreja de friccion donde se atornilla
//      el pod del sensor (reemplaza a clamp + plate + Hirth).
//    - brazo exterior: reproduce la interfaz de montaje que YA tiene la
//      caja de electronica impresa, con las cotas congeladas en params.scad
//      (reemplaza al modulo hook() que antes vivia en electronics_box.scad).
//
//  Se imprime de canto, igual que antes: prisma puro, sin soportes.
//
//  Uso:  openscad -D 'part="mount"' -o mount.stl rim_mount.scad
// ===========================================================================

include <lib/geometry.scad>    // arrastra params.scad y valida el apuntado
include <lib/rim_hook.scad>    // perfil en U compartido

part = "mount";

// --- Cotas derivadas -------------------------------------------------------
pad = 8;   // espesor de la pata interior, donde nace el brazo de la oreja

// Un solo tornillo de apriete al borde para todo el conjunto, arriba del
// todo (igual que el hook original) para que su saliente no choque contra
// la caja colgada por debajo.
tight_gz = box_hook_screw_z;

// Eje del pivote: mismo punto que usan sensor_head.scad y geometry.scad.
px = rim_thickness + pod_reach;
pz = -pivot_drop;

// La oreja de este mount ocupa Y de [y_ear0, y_ear0+hinge_ear_t]; la oreja
// del pod (sensor_head.scad) arranca justo donde esta termina.
y_ear0 = clamp_width / 2;

tight_len = rim_hook_screw_len();
// Tornillo pasante de rosca completa: rosca en la tuerca cautiva del mount
// en un extremo, atraviesa la oreja del pod y la arandela, y rosca tambien
// en la tuerca del pomo en el otro extremo. Se tensa girando el pomo; la
// tuerca del mount no gira porque esta embutida en su alojamiento hexagonal.
hinge_len = 2 * hinge_ear_t + 1 + knob_h;

echo(str("--- Tornilleria mount --------------------------------------"));
echo(str("  Apriete al borde  M3 x ", round(tight_len * 10) / 10,
         " mm + 1 tuerca (cautiva en el saliente)"));
echo(str("  Pivote (bisagra)  M3 x ", round(hinge_len * 10) / 10,
         " mm, rosca completa + 1 tuerca (cautiva en el mount) + ",
         "1 tuerca (en el pomo) + 1 arandela suelta"));
echo(str("=========================================================="));

// Los dos agujeros hacia la espina de la caja (interfaz congelada) tienen
// que caer dentro de la pata exterior de este mount, y no pisar el saliente
// del tornillo de apriete que ahora comparten box y sensor.
for (z = box_iface_hole_z) {
    assert(-z < box_hook_out - 4,
           "Un agujero de la interfaz de la caja cae por debajo de la pata exterior del mount.");
    assert(-z > -box_hook_screw_z + 7,
           "Un agujero de la interfaz de la caja pisa el saliente del tornillo de apriete.");
}

module mount() {
    union() {
        difference() {
            // Cuerpo base: pata interior larga (clamp_grip_in, aloja el
            // brazo hacia la bisagra) + pata exterior larga (box_hook_out,
            // aloja la caja), ambas en el MISMO punto de apriete.
            rim_hook(clamp_width, box_hook_out, clamp_grip_in, pad, tight_gz,
                     ribs = grip_ribs);

            // Pasantes hacia la espina de la caja (interfaz congelada).
            for (z = box_iface_hole_z)
                translate([-clamp_wall - 1, 0, z])
                    rotate([0, 90, 0])
                        cylinder(d = box_screw_d, h = clamp_wall + 2);
        }

        // Brazo hacia la oreja de la bisagra: de la pata interior hasta el
        // eje del pivote, del mismo espesor que la oreja (hinge_arm_t) y
        // centrado en Y sobre y_ear0 + hinge_ear_t/2.
        translate([0, y_ear0 + hinge_ear_t / 2 - hinge_arm_t / 2, 0])
            hull() {
                translate([hook_slot + pad / 2, 0, -clamp_grip_in + 6])
                    cube([pad, hinge_arm_t, 12], center = true);
                translate([px, 0, pz])
                    cube([hinge_ear_w * 0.6, hinge_arm_t, hinge_ear_w * 0.6],
                         center = true);
            }

        // Oreja de la bisagra, con el agujero del pivote y su tuerca
        // cautiva. Ocupa Y de [y_ear0, y_ear0 + hinge_ear_t]: la del pod
        // arranca justo despues.
        //
        // La tuerca va abierta hacia el pod (+Y): se mete a presion antes
        // de acoplar el pod, y la propia oreja del pod la deja atrapada sin
        // que pueda girar ni caerse. El tornillo entra por el otro extremo
        // (pomo), atraviesa el pod, y rosca aqui.
        difference() {
            translate([px, y_ear0, pz])
                rotate([-90, 0, 0])
                    cylinder(d = hinge_ear_w, h = hinge_ear_t);

            // Agujero pasante del tornillo, hasta donde arranca la tuerca.
            translate([px, y_ear0 - eps, pz])
                rotate([-90, 0, 0])
                    cylinder(d = hinge_screw_d, h = hinge_ear_t - nut_h + eps);

            // Tuerca cautiva M3.
            translate([px, y_ear0 + hinge_ear_t - nut_h, pz])
                rotate([-90, 0, 0])
                    cylinder(d = nut_af / cos(30), h = nut_h + eps, $fn = 6);
        }
    }
}

eps = 0.01;

if (part == "mount") mount();
else assert(false, str("part desconocida: ", part));
