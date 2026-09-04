// ===========================================================================
//  Acoplamiento Hirth  ::  articulacion con detentes
//
//  Dos caras dentadas IDENTICAS que engranan cada `step` grados. Se afloja el
//  tornillo central, se separan lo justo, se gira, se vuelven a juntar. Los
//  dientes son cunas triangulares que se autocentran y aguantan par en ambos
//  sentidos, no como un simple apriete por friccion.
//
//  Por que Hirth y no un trinquete de pasador y agujeros: con pasadores hace
//  falta pared entre agujero y agujero, y con paso de 6 grados en un radio
//  razonable esa pared cae por debajo del ancho de extrusion. El Hirth es
//  diente-valle continuo, sin pared intermedia, asi que baja a pasos finos
//  sin dejar de ser imprimible.
//
//  Se imprime con los dientes MIRANDO HACIA ARRIBA. En cualquier otra
//  orientacion salen escalonados.
//
//  La corona se construye como UN SOLO poliedro y no como la union de N
//  cunas: unir 60 solidos no convexos en CGAL tarda minutos, el poliedro
//  tarda milisegundos.
// ===========================================================================

// Corona + respaldo + agujero del eje.
//   step    grados por posicion de detente
//   r_in    radio interior de la corona
//   r_out   radio exterior
//   h       altura del diente
//   backing espesor macizo por debajo de la corona (z de -backing a 0)
//   bore    diametro del agujero pasante del eje
//   phase   desfase angular; dos caras identicas engranan con medio paso
//           de desfase entre ellas
//
// La zona central (r < r_in) queda plana en z=0 a proposito: al engranar,
// los dos planos base quedan separados exactamente `h`, asi que cualquier
// resalte central chocaria antes de que los dientes asienten.
module hirth_disc(step, r_in, r_out, h, backing, bore, phase = 0) {
    n    = round(360 / step);
    m    = 2 * n;                 // pico y valle alternados
    dphi = 360 / m;

    // k par = cresta del diente, k impar = fondo del valle
    ang = [for (k = [0 : m-1]) phase + k * dphi];
    zs  = [for (k = [0 : m-1]) (k % 2 == 0) ? h : 0];

    pts = concat(
        [for (k = [0:m-1]) [r_in  * cos(ang[k]), r_in  * sin(ang[k]), zs[k]]],
        [for (k = [0:m-1]) [r_out * cos(ang[k]), r_out * sin(ang[k]), zs[k]]],
        [for (k = [0:m-1]) [r_in  * cos(ang[k]), r_in  * sin(ang[k]), -backing]],
        [for (k = [0:m-1]) [r_out * cos(ang[k]), r_out * sin(ang[k]), -backing]]
    );

    // Indices: ti=k, to=m+k, bi=2m+k, bo=3m+k.
    // Orden horario visto desde fuera de cada cara. Se emiten triangulos y no
    // cuadrilateros porque ninguna de las cuatro superficies es plana: la de
    // arriba zigzaguea y las laterales viven sobre un cilindro. Con quads,
    // OpenSCAD avisa y triangula por su cuenta.
    faces = concat(
        [for (k = [0:m-1]) let (j = (k+1) % m) each
            [[k, j, m + j], [k, m + j, m + k]]],                            // dientes
        [for (k = [0:m-1]) let (j = (k+1) % m) each
            [[2*m+k, 3*m+k, 3*m+j], [2*m+k, 3*m+j, 2*m+j]]],                // fondo
        [for (k = [0:m-1]) let (j = (k+1) % m) each
            [[k, 2*m+k, 2*m+j], [k, 2*m+j, j]]],                            // pared interior
        [for (k = [0:m-1]) let (j = (k+1) % m) each
            [[m+k, m+j, 3*m+j], [m+k, 3*m+j, 3*m+k]]]                       // pared exterior
    );

    difference() {
        union() {
            polyhedron(points = pts, faces = faces, convexity = 10);
            // relleno del disco central, hasta el plano de los valles
            translate([0, 0, -backing]) cylinder(r = r_in + 0.05, h = backing);
        }
        translate([0, 0, -backing - 1]) cylinder(d = bore, h = backing + h + 2);
    }
}
