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

// Gancho solido, ya con el tornillo de apriete. La punta del tornillo empuja
// el borde de la canasta.
//
// La rosca la da una TUERCA CAUTIVA embutida en la cara exterior del saliente,
// no el plastico: no se usan autorroscantes en ningun sitio del proyecto. El
// hexagono impide que la tuerca gire, asi que el saliente se comporta como un
// inserto roscado y el tornillo avanza al apretarlo, igual que antes.
module rim_hook(w, grip_out, grip_in, pad, screw_z, ribs = true) {
    difference() {
        translate([0, w / 2, 0]) rotate([90, 0, 0])
            linear_extrude(w, convexity = 6)
                union() {
                    rim_hook_profile(grip_out, grip_in, pad, screw_z);
                    if (ribs) rim_hook_ribs(grip_out, grip_in);
                }

        // Alojamiento hexagonal, abierto hacia fuera para poder meter la
        // tuerca con los dedos antes de colgar la pieza.
        translate([-clamp_wall - hook_boss - hook_eps, 0, screw_z])
            rotate([0, 90, 0]) rotate([0, 0, 30])
                cylinder(d = nut_af / cos(30), h = nut_h + hook_eps, $fn = 6);

        // Paso libre desde la tuerca hasta 1 mm mas alla de la cara interior:
        // ese milimetro es el recorrido con el que la punta muerde el borde.
        translate([-clamp_wall - hook_boss - 1, 0, screw_z]) rotate([0, 90, 0])
            cylinder(d = clamp_screw_d, h = hook_boss + clamp_wall + 2);
    }
}

// Longitud minima del tornillo de apriete, bajo cabeza. Se exporta para que
// cada pieza que use el gancho la pueda echo-ar sin recalcularla.
function rim_hook_screw_len() = hook_boss + clamp_wall + 3;
