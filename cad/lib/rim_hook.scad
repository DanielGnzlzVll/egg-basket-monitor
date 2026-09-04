// ===========================================================================
//  Gancho al borde de la canasta
//
//  Perfil en U que se cuelga del borde y se aprieta con un tornillo. Lo usan
//  dos piezas distintas —la cabeza del sensor y la caja de electronica— y
//  vive aqui para que compartan literalmente la misma geometria: si un dia
//  cambia el borde de la canasta, cambia `rim_thickness` y se arreglan las
//  dos a la vez.
//
//  Las dos patas son parametricas porque cada pieza quiere lo contrario:
//  la cabeza cuelga hacia DENTRO y necesita pata interior larga; la caja
//  cuelga hacia FUERA y necesita pata exterior larga.
//
//  Se imprime de canto. Asi es un prisma puro —cada capa es el mismo perfil
//  en U— y no necesita ni un soporte.
// ===========================================================================

include <../params.scad>

hook_slot = rim_thickness + clamp_clearance;   // hueco donde entra el borde
hook_boss = 6;                                 // saliente del tornillo
hook_eps  = 0.01;

// Perfil 2D en el plano XZ. x=0 es la cara exterior del borde de la canasta.
//   grip_out  cuanto baja por fuera
//   grip_in   cuanto baja por dentro
//   pad       espesor de la pata interior
//   screw_z   altura del tornillo de apriete (negativa)
module rim_hook_profile(grip_out, grip_in, pad, screw_z) {
    union() {
        translate([-clamp_wall, 0])
            square([clamp_wall + hook_slot + pad, clamp_wall]);   // puente
        translate([-clamp_wall, -grip_out])
            square([clamp_wall, grip_out]);                       // pata exterior
        translate([hook_slot, -grip_in])
            square([pad, grip_in]);                               // pata interior
        translate([-clamp_wall - hook_boss, screw_z - 7])
            square([hook_boss, 14]);                              // saliente tornillo
    }
}

// Nervios antideslizantes: crestas horizontales en las dos caras que muerden.
module rim_hook_ribs(grip_out, grip_in) {
    depth = min(grip_out, grip_in) - 3;
    if (depth > 6)
        for (z = [-6 : -6 : -depth]) {
            translate([0, z])          polygon([[0,-1.4],[0,1.4],[1.1,0]]);
            translate([hook_slot, z])  polygon([[0,-1.4],[0,1.4],[-1.1,0]]);
        }
}

// Gancho solido, ya con el tornillo de apriete. El tornillo rosca directo en
// el plastico del saliente y su punta empuja el borde; sin tuerca, porque con
// tuerca harian falta cabeza Y tuerca las dos por fuera y nada haria de tope.
module rim_hook(w, grip_out, grip_in, pad, screw_z, ribs = true) {
    difference() {
        translate([0, w / 2, 0]) rotate([90, 0, 0])
            linear_extrude(w, convexity = 6)
                union() {
                    rim_hook_profile(grip_out, grip_in, pad, screw_z);
                    if (ribs) rim_hook_ribs(grip_out, grip_in);
                }

        translate([-clamp_wall - hook_boss - 1, 0, screw_z]) rotate([0, 90, 0])
            cylinder(d = clamp_screw_d - 0.5, h = hook_boss + 1 + hook_eps);
        translate([-clamp_wall, 0, screw_z]) rotate([0, 90, 0])
            cylinder(d = clamp_screw_d, h = clamp_wall + 1.5);
    }
}
