# Rim Mount Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fusionar `clamp`+`hook` en una pieza `mount` con un solo punto de apriete al borde, reemplazar la bisagra Hirth por un pivote de fricción, y corregir las cotas del PCB al sensor TOF200C real, sin tocar la geometría de `box`/`lid` ya impresas.

**Architecture:** Todo el proyecto es OpenSCAD paramétrico. `params.scad` es la única fuente de cotas; `lib/geometry.scad` valida el apuntado; `lib/rim_hook.scad` es el perfil en U compartido. Este plan añade `cad/rim_mount.scad` (pieza `mount`), recorta `sensor_head.scad` (pierde `clamp`/`plate`, `pod` cambia de bisagra) y `electronics_box.scad` (pierde `hook`), y borra `lib/hirth.scad`.

**Tech Stack:** OpenSCAD (CLI en `C:\Program Files\OpenSCAD\openscad.exe`), `cad/build.py` (Python, exporta STL y corre los `echo`/`assert` de cada modelo).

**Spec:** `docs/superpowers/specs/2026-09-18-cad-rim-mount-redesign-design.md`

## Global Constraints

- Ni un tornillo autorroscante en todo el proyecto: donde no hay nada al otro lado, tuerca hexagonal embutida.
- Toda cota vive en `params.scad`; ningún otro archivo tiene números mágicos nuevos.
- `box`/`lid` (en `electronics_box.scad`) no cambian ni una cota ni una posición de agujero: ya están impresas.
- Cada pieza se imprime sin soportes (regla del proyecto desde el spec de 2026-09-04).
- Verificación de cada tarea: `python cad/build.py <parte>` debe salir con código 0 y sin `WARNING`/`ERROR`/`ASSERT` en la salida.

---

### Task 1: Corregir cotas del PCB y preparar `params.scad` para la bisagra de fricción

**Files:**
- Modify: `cad/params.scad`

**Interfaces:**
- Produces: `pcb_l = 20.0`, `pcb_hole_spacing = 14.4` (consumidos por `sensor_head.scad` Task 2).
- Produces: nuevos parámetros `hinge_screw_d`, `hinge_ear_w`, `hinge_ear_t`, `hinge_washer_d`, `hinge_arm_t` (consumidos por `sensor_head.scad` Task 2 y `rim_mount.scad` Task 3).
- Produces: `pod_arm` recalculado sin depender de `hirth_r_out` (consumido por `lib/geometry.scad`, sin cambios en ese archivo).
- Produces: bloque `box_iface_*` con la interfaz congelada hacia la caja ya impresa (consumido por `rim_mount.scad` Task 3).
- Removes: `hirth_r_in`, `hirth_r_out`, `hirth_h`, `hirth_backing`, `detent_step`, `plate_t`, `plate_w`, `plate_screw_d`, `plate_screw_sep`. Nadie más los usa tras este plan (confirmado por `grep -rn hirth cad/` antes de empezar: solo aparecían en `params.scad`, `sensor_head.scad` y `lib/hirth.scad`).

- [ ] **Step 1: Corregir las cotas del PCB real (TOF200C)**

En `cad/params.scad`, dentro de `/* [Modulo VL53L1X] */`:

```openscad
pcb_l            = 20.0;  // mm, ancho real del TOF200C (antes 25.0, generico)
pcb_w            = 11.0;  // mm, alto del PCB (ya coincidia)
pcb_t            = 1.6;   // mm, espesor del PCB (sin medir, se mantiene)
pcb_hole_spacing = 14.4;  // mm entre centros de agujero, medido en la ficha del TOF200C (antes 20.0)
pcb_hole_d       = 2.3;   // mm, M2 pasante (el agujero real mide Ø2, esto ya da holgura)
```

- [ ] **Step 2: Verificar que las asserts de `sensor_head.scad` siguen pasando con las cotas nuevas**

Run: `cd cad && python build.py --report`
Expected: en el bloque `--- Modulo VL53L1X ---`, "Con 20 x 11 mm el PCB apoya sobre 2.15 mm de reborde" (el margen no cambia, solo cambió `pcb_l`, que no entra en esa cuenta) y ningún `ERROR`/`ASSERT` en stderr.

- [ ] **Step 3: Reemplazar la sección `[Articulacion Hirth]` por `[Bisagra de friccion]`**

Borrar el bloque completo:
```openscad
detent_step   = 4;
hirth_r_in    = 11;
hirth_r_out   = 17;
hirth_h       = 1.4;
hirth_backing = 3.2;
pivot_screw_d = 3.4;
```

Y en su lugar escribir:
```openscad
/* [Bisagra de friccion] ---------------------------------------------------
   Reemplaza a la articulacion Hirth: una oreja plana en el mount y otra en
   el pod, un tornillo M3 pasante con una arandela entre las caras de
   contacto, apretado a mano con el pomo lobulado. Sin detentes: el angulo
   se fija por friccion pura. Recalibrar en Grafana tras tocar el pivote.    */

hinge_screw_d  = 3.4;   // mm, M3 pasante del pivote
hinge_ear_w    = 22;    // mm, ancho x alto de cada oreja (mount y pod)
hinge_ear_t    = 5;     // mm, espesor de cada oreja
hinge_arm_t    = 5;     // mm, espesor del brazo que conecta la pata del
                        // mount con la oreja (mismo grosor que la oreja)
hinge_washer_d = 7;     // mm, diametro de apoyo de la arandela M3 entre
                        // las dos orejas
```

- [ ] **Step 4: Quitar la sección `[Placa de bisagra]` (ya no existe placa separada)**

Borrar:
```openscad
plate_t          = 6.0;
plate_w          = 18;
plate_screw_d    = 3.4;
plate_screw_sep  = 16;
```

`pivot_drop` se queda (sigue siendo "mm del borde al eje del pivote", ahora del mount en vez de la placa). Dejar el comentario del bloque actualizado a:
```openscad
/* [Pivote] ---------------------------------------------------------------
   pivot_drop: mm del borde de la canasta al eje de la bisagra de friccion.  */

pivot_drop = 28;
```

- [ ] **Step 5: Recalcular `pod_arm` sin el radio del Hirth**

En `/* [Alcance del brazo] */`, cambiar:
```openscad
pod_arm = hirth_r_out + pcb_w / 2 + 6;   // mm
```
por:
```openscad
// Del eje del pivote al centro del sensor: lo justo para que la pared del
// PCB libre la oreja de la bisagra de friccion.
pod_arm = hinge_ear_w / 2 + pcb_w / 2 + 6;   // mm
```

- [ ] **Step 6: Añadir el bloque de interfaz congelada hacia la caja de electrónica**

Al final de `params.scad`, después de la sección `[Caja de electronica]`:

```openscad
/* [Interfaz congelada con la caja de electronica] -------------------------
   La caja (electronics_box.scad: box/lid) YA ESTA IMPRESA. Estos numeros son
   una copia exacta de las cotas con las que se taladro esa pieza fisica; NO
   se recalculan a partir de otros parametros porque el objeto real ya no
   cambia. Los usa rim_mount.scad para que el brazo exterior del mount
   reproduzca el mismo gancho que antes generaba electronics_box.scad.
   Si algun dia se reimprime la caja con otras cotas, hay que actualizar
   este bloque a mano (y solo a mano: no hay formula que lo haga por vos).   */

box_iface_w        = 26;        // = box_hook_w
box_iface_out      = 40;        // = box_hook_out
box_iface_in       = 18;        // = box_hook_in
box_iface_pad      = 3.2;       // = box_hook_pad
box_iface_screw_z  = -7;        // = box_hook_screw_z
box_iface_screw_d  = 3.4;       // = box_screw_d
box_iface_hole_z   = [-26, -34]; // = -(box_hang_drop + out_h - y), y en [71, 63]
                                 // con box_hang_drop=16 y out_h=81 (cell_l=68)
```

- [ ] **Step 7: Verificar que el reporte completo sigue sano**

Run: `cd cad && python build.py --report`
Expected: código de salida 0, sin `ERROR`/`ASSERT`/`WARNING` nuevos. (Fallará al intentar exportar `clamp`/`plate`/`hook` en el Step siguiente porque esos módulos todavía existen pero sus archivos ya no compilarán con los símbolos borrados — eso se resuelve en las Tasks 2 y 4, no antes.)

- [ ] **Step 8: Commit**

```bash
git add cad/params.scad
git commit -m "cad: cotas reales del TOF200C y parametros de la bisagra de friccion"
```

---

### Task 2: Reescribir `pod()` en `sensor_head.scad` con oreja de fricción, quitar `clamp`/`plate`/Hirth

**Files:**
- Modify: `cad/sensor_head.scad`

**Interfaces:**
- Consumes: `hinge_screw_d`, `hinge_ear_w`, `hinge_ear_t` de `params.scad` (Task 1).
- Produces: módulo `pod()` con una oreja plana (agujero `hinge_screw_d`) en el extremo del brazo, sin disco Hirth. `part = "pod" | "knob" | "assembly"` (ya no acepta `"clamp"` ni `"plate"`).
- Removes: módulos `clamp()`, `plate()`, `include <lib/hirth.scad>`, y las variables derivadas que solo ellos usaban (`slot`, `y_plate0`, `y_teeth`, `mount_gx`, `mount_gz`, `mount_lx`, `mount_ly`, `tight_gz`, `boss_t`, `head_cbore_d`, `head_cbore`, `pivot_seat`, `pivot_nut`, `pivot_len`, `mount_len`, `tight_len`).

- [ ] **Step 1: Quitar el include de Hirth y las piezas que desaparecen**

En `cad/sensor_head.scad`, quitar la línea:
```openscad
use     <lib/hirth.scad>
```

Quitar los módulos `clamp()` y `plate()` completos.

- [ ] **Step 2: Simplificar las cotas derivadas al principio del archivo**

Reemplazar el bloque de "Cotas derivadas" (que hoy calcula `slot`, `pad`, `mount_gx`, etc. para el clamp/plate) por solo lo que `pod()` y `knob()` siguen necesitando:

```openscad
// --- Cotas derivadas -------------------------------------------------------
px = rim_thickness + pod_reach;   // X del eje del pivote (global, para la vista)
pz = -pivot_drop;                 // Z del eje del pivote (global, para la vista)

y_pod  = 0;   // el pod ya no se apoya sobre una placa: su cara de la oreja
              // queda al ras de la oreja del mount (ver rim_mount.scad)

wall_t = 6;   // espesor de la pared que sujeta el PCB
eps    = 0.01;

rib_t = 3.0;  // nervios brazo-pared del pod
rib_h = 12;
rib_l = 12;
```

- [ ] **Step 3: Reescribir `pod()` con oreja de fricción en vez de disco Hirth**

```openscad
// ===========================================================================
//  POD DEL SENSOR   (frame local: origen en el eje del pivote, oreja hacia
//                    -X (apoya contra la oreja del mount), apuntado = -Y)
// ===========================================================================

module pod() {
    pocket_l = pcb_l + 2 * pcb_pocket_clear;
    pocket_w = pcb_w + 2 * pcb_pocket_clear;
    body_h   = pocket_w + 2 * clamp_wall;

    difference() {
        union() {
            // Oreja de la bisagra: un bloque plano con el agujero del
            // pivote, del mismo tamano que la oreja complementaria del
            // mount (hinge_ear_w x hinge_ear_w x hinge_ear_t).
            translate([-hinge_ear_t, -hinge_ear_w / 2, -hinge_ear_w / 2])
                cube([hinge_ear_t, hinge_ear_w, hinge_ear_w]);

            // brazo, en el plano de la oreja
            translate([-hinge_ear_t, 0, -wall_t / 2])
                rotate([0, 0, 0])
                linear_extrude(wall_t, convexity = 4)
                    hull() {
                        translate([0, 0]) circle(d = hinge_ear_w * 0.9);
                        translate([-pod_arm + wall_t / 2, 0])
                            square([wall_t, pocket_l + 2 * clamp_wall],
                                   center = true);
                    }

            // pared que sostiene el PCB, perpendicular al apuntado
            translate([-pod_arm + wall_t / 2, -(pocket_l + 2 * clamp_wall) / 2,
                       -body_h / 2])
                cube([wall_t, pocket_l + 2 * clamp_wall, body_h]);

            // Dos nervios de refuerzo brazo-pared.
            for (s = [-1, 1])
                translate([-pod_arm + wall_t, s * (pocket_l + clamp_wall) / 2,
                           -body_h / 2])
                    rotate([0, 90, 90])
                        linear_extrude(rib_t, center = true)
                            polygon([[0, 0], [-rib_h, 0], [0, rib_l]]);
        }

        // Agujero del pivote en la oreja.
        translate([-hinge_ear_t - eps, 0, 0])
            rotate([0, 90, 0]) cylinder(d = hinge_screw_d, h = hinge_ear_t + 2 * eps);

        // Bolsillo del PCB, abierto por la cara trasera (+X local).
        translate([-pod_arm + wall_t - (pcb_t + pcb_pocket_clear),
                   -pocket_l / 2, -pocket_w / 2])
            cube([pcb_t + pcb_pocket_clear + eps, pocket_l, pocket_w]);

        // Ventana optica: atraviesa la pared en la direccion de apuntado.
        translate([-pod_arm - 1, 0, 0])
            rotate([0, 90, 0]) cylinder(d = window_d, h = wall_t + 2);

        // Pasantes M2 para el modulo.
        for (s = [-1, 1])
            translate([-pod_arm - 1, s * pcb_hole_spacing / 2, 0])
                rotate([0, 90, 0]) cylinder(d = pcb_hole_d, h = wall_t + 2);

        // Salida de los Dupont por arriba.
        translate([-pod_arm + wall_t / 2, 0, body_h / 2 - 3])
            cube([wall_t + 2, wire_channel_d, 6], center = true);
    }
}
```

> Nota para quien ejecute este paso: la reescritura cambia el eje de
> apuntado de "apoyado sobre un plano XY con dientes hacia +Z" a "un
> bloque simple con el eje del pivote en X". Es MUY probable que al
> renderizar por primera vez algo quede desalineado (ventana optica no
> centrada en la pared, bolsillo del PCB en el lado equivocado, nervios
> chocando con el bolsillo). Eso se corrige en el Step 5 mirando el PNG,
> no adivinando: no hay manera de garantizar en el papel que una
> reescritura de este tamano salga perfecta a la primera.

- [ ] **Step 4: Actualizar la selección de pieza al final del archivo**

```openscad
if      (part == "pod")      pod();
else if (part == "knob")     knob();
else if (part == "assembly") assembly();
else assert(false, str("part desconocida: ", part));
```

Y simplificar `assembly()` para que ya no posicione `clamp()`/`plate()` (se mueve a `rim_mount.scad`, Task 3 lo re-arma):

```openscad
module assembly() {
    basket_context();
    color("Crimson") translate([px, 0, pz]) pod();
    color("DimGray") translate([px - hinge_ear_t - 1, 0, pz]) rotate([0, -90, 0]) knob();
}
```

- [ ] **Step 5: Compilar, mirar el render y corregir lo que no cuadre**

Run:
```bash
cd cad
python build.py pod knob
"C:\Program Files\OpenSCAD\openscad.exe" -o out/pod_preview.png --imgsize=1000,800 --camera=0,0,0,55,0,25,150 -D 'part="pod"' sensor_head.scad
```

Leer `cad/out/pod_preview.png` con la herramienta Read y confirmar: la ventana óptica cae centrada en la pared, el bolsillo del PCB no atraviesa la oreja, los nervios no invaden el bolsillo ni la ventana, y no queda ningún hueco flotante (geometría no manifold). Si algo no cuadra, ajustar las coordenadas del Step 3 y repetir — no seguir a la Task 3 hasta que este render se vea correcto.

Expected: `python build.py pod knob` sale con código 0 y sin `ERROR`/`ASSERT` en stderr; el PNG muestra un brazo sólido con ventana óptica centrada.

- [ ] **Step 6: Commit**

```bash
git add cad/sensor_head.scad
git commit -m "cad: pod con oreja de friccion, elimina clamp/plate/hirth de sensor_head"
```

---

### Task 3: Crear `cad/rim_mount.scad` con la pieza combinada `mount`

**Files:**
- Create: `cad/rim_mount.scad`

**Interfaces:**
- Consumes: `hook_slot`, `hook_boss`, `rim_hook()`, `rim_hook_screw_len()` de `lib/rim_hook.scad`; `clamp_width`, `clamp_wall`, `clamp_grip_in`, `grip_ribs`, `pivot_drop`, `hinge_screw_d`, `hinge_ear_w`, `hinge_ear_t`, `hinge_arm_t`, `pod_reach`, `rim_thickness`, `box_iface_*`, `nut_h` de `params.scad`.
- Produces: módulo `mount()`, seleccionable con `part = "mount"`.

- [ ] **Step 1: Escribir `cad/rim_mount.scad`**

```openscad
// ===========================================================================
//  egg-basket-monitor  ::  mount unificado (mordaza + gancho)
//
//  Una sola pieza que se aprieta al borde de la canasta en un UNICO punto y
//  sostiene dos cosas a la vez:
//    - brazo interior: termina en una oreja de friccion donde se atornilla
//      el pod del sensor (reemplaza a clamp + plate + Hirth).
//    - brazo exterior: reproduce la interfaz de montaje que YA tiene la
//      caja de electronica impresa, cotas congeladas en params.scad
//      (reemplaza al modulo hook() de electronics_box.scad).
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
tight_gz = box_iface_screw_z;

// Eje del pivote, mismo punto que usan sensor_head.scad y geometry.scad.
px = rim_thickness + pod_reach;
pz = -pivot_drop;

tight_len = rim_hook_screw_len();
hinge_len = 2 * hinge_ear_t + 3 + nut_h;   // dos orejas + arandela + tuerca

echo(str("--- Tornilleria mount --------------------------------------"));
echo(str("  Apriete al borde  M3 x ", round(tight_len * 10) / 10,
         " mm + 1 tuerca (cautiva en el saliente)"));
echo(str("  Pivote (bisagra)  M3 x ", round(hinge_len * 10) / 10,
         " mm + 1 tuerca (pomo) + 1 arandela suelta"));
echo(str("=========================================================="));

module mount() {
    union() {
        difference() {
            // Cuerpo base: pata interior larga (clamp_grip_in, para la
            // sensor) + pata exterior larga (box_iface_out, para la caja),
            // ambas en el MISMO punto de apriete.
            rim_hook(clamp_width, box_iface_out, clamp_grip_in, pad, tight_gz,
                     ribs = grip_ribs);

            // Pasantes hacia la espina de la caja (interfaz congelada).
            for (z = box_iface_hole_z)
                translate([-clamp_wall - 1, 0, z])
                    rotate([0, 90, 0])
                        cylinder(d = box_iface_screw_d, h = clamp_wall + 2);
        }

        // Brazo hacia la oreja de la bisagra: de la pata interior hasta el
        // eje del pivote.
        hull() {
            translate([hook_slot + pad / 2, 0, -clamp_grip_in / 2])
                cube([hinge_arm_t, hinge_ear_w * 0.6, hinge_ear_w * 0.6],
                     center = true);
            translate([px, 0, pz])
                cube([hinge_arm_t, hinge_ear_w, hinge_ear_w], center = true);
        }

        // Oreja de la bisagra, con el agujero del pivote.
        difference() {
            translate([px - hinge_ear_t / 2, 0, pz])
                cube([hinge_ear_t, hinge_ear_w, hinge_ear_w], center = true);
            translate([px, 0, pz])
                rotate([0, 90, 0]) cylinder(d = hinge_screw_d, h = hinge_ear_t + 2,
                                            center = true);
        }
    }
}

if (part == "mount") mount();
else assert(false, str("part desconocida: ", part));
```

- [ ] **Step 2: Compilar y revisar el reporte de tornillería**

Run:
```bash
cd cad
"C:\Program Files\OpenSCAD\openscad.exe" -D 'part="mount"' -o out/mount.stl rim_mount.scad
```
Expected: código de salida 0, `out/mount.stl` generado, sin `ERROR`/`WARNING` de geometría no-manifold en stderr.

- [ ] **Step 3: Renderizar y verificar visualmente**

Run:
```bash
"C:\Program Files\OpenSCAD\openscad.exe" -o out/mount_preview.png --imgsize=1000,800 --camera=0,0,-20,55,0,25,200 -D 'part="mount"' rim_mount.scad
```
Leer `cad/out/mount_preview.png` con Read y confirmar: la pata interior y exterior salen del mismo punto de apriete, el brazo llega limpio hasta la oreja sin huecos ni intersecciones raras, y los dos agujeros hacia la caja quedan dentro del material de la pata exterior (no se salen por el canto). Si el `hull()` del brazo no conecta bien con la pata interior (es fácil que el primer intento deje un hueco porque el punto de partida del hull no toca la superficie real de la pata), ajustar la posición/tamaño del primer bloque del `hull()` hasta que el render se vea sólido, y repetir el render.

- [ ] **Step 4: Renderizar el ensamblaje completo (mount + pod + knob) para chequear que el pivote alinea**

Run:
```bash
"C:\Program Files\OpenSCAD\openscad.exe" -o out/full_assembly.png --imgsize=1200,900 --camera=0,0,-30,55,0,25,250 -D 'part="assembly"' sensor_head.scad
```
Modificar temporalmente `assembly()` en `sensor_head.scad` (o crear un archivo de vista aparte) para que también incluya `mount()` de `rim_mount.scad` vía `use`, y confirmar en el PNG que la oreja del pod y la oreja del mount coinciden en posición y tamaño (mismo `px`, `pz`, mismo `hinge_ear_w`).

Expected: las dos orejas se ven alineadas y del mismo tamaño en el render; si no, el desajuste casi seguro está en que `pod()` usa `-hinge_ear_t/2` como centro de su oreja en X mientras `mount()` la coloca en `px - hinge_ear_t/2` — revisar signos antes de tocar cualquier otra cosa.

- [ ] **Step 5: Commit**

```bash
git add cad/rim_mount.scad
git commit -m "cad: nueva pieza mount, fusiona clamp+hook en un solo punto de apriete"
```

---

### Task 4: Quitar `hook()` de `electronics_box.scad` sin tocar `box()`/`lid()`

**Files:**
- Modify: `cad/electronics_box.scad`

**Interfaces:**
- Consumes: nada nuevo.
- Removes: módulo `hook()`, la parte de `assembly_raw()` que lo dibuja, y `part == "hook"` de la selección final.
- Preserves exactamente: `box()`, `lid()`, y todas las constantes derivadas que ambos usan (`out_w`, `out_h`, `hook_cx`, `hook_hole_y`, `spine_*`, etc. — estas se quedan, porque `box()` las sigue necesitando para taladrar la espina; solo se deja de generar el `hook()` en sí).

- [ ] **Step 1: Quitar el módulo `hook()`**

Borrar el bloque completo:
```openscad
// ===========================================================================
//  GANCHO
// ===========================================================================

module hook() {
    ...
}
```

- [ ] **Step 2: Quitar la parte del gancho en `assembly_raw()`**

Reemplazar:
```openscad
module assembly_raw() {
    color("SteelBlue") box();
    color("Silver")    translate([0, 0, lid_z]) lid();

    // La celda, para ver que cabe.
    color("DimGray", 0.6)
        translate([cx, y0 + 1, cz]) rotate([-90, 0, 0])
            cylinder(d = cell_d, h = in_h - 3);

    // El gancho vive en otro marco ...
    multmatrix(...) {
        color("Goldenrod") hook();
        color("Tan", 0.25) translate(...) cube(...);
    }
}
```
por:
```openscad
module assembly_raw() {
    color("SteelBlue") box();
    color("Silver")    translate([0, 0, lid_z]) lid();

    // La celda, para ver que cabe.
    color("DimGray", 0.6)
        translate([cx, y0 + 1, cz]) rotate([-90, 0, 0])
            cylinder(d = cell_d, h = in_h - 3);
}
```

- [ ] **Step 3: Quitar `"hook"` de la selección de pieza**

```openscad
if      (part == "box")      box();
else if (part == "lid")      lid();
else if (part == "assembly") assembly();
else assert(false, str("part desconocida: ", part));
```

- [ ] **Step 4: Verificar que `box`/`lid` no cambiaron ni un mm**

Run:
```bash
cd cad
python build.py --report 2>&1 | grep -A3 "Caja de electronica"
```
Expected: exactamente igual que antes del cambio — `Exterior: 77.4 x 81 x 24.4 mm (orejas incluidas)`, `Hueco de 70 mm: acepta celdas de 62 a 69 mm`. Si algún número cambió, hay una regresión: revisar el diff, no debería haberse tocado ninguna constante que `box()` usa.

```bash
python build.py box lid
```
Expected: código 0, sin `ERROR`/`ASSERT`.

- [ ] **Step 5: Commit**

```bash
git add cad/electronics_box.scad
git commit -m "cad: quita hook de electronics_box, se muda a rim_mount.scad"
```

---

### Task 5: Actualizar `build.py`, borrar `lib/hirth.scad`, y confirmar el build completo

**Files:**
- Modify: `cad/build.py`
- Delete: `cad/lib/hirth.scad`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `MODELS` con las 5 piezas finales, `PARTS` derivado igual que antes.

- [ ] **Step 1: Confirmar que nada más usa `lib/hirth.scad`**

Run: `grep -rn "hirth" cad/ --include=*.scad`
Expected: cero resultados (Task 1 y 2 ya quitaron todos los usos).

- [ ] **Step 2: Borrar el archivo**

```bash
git rm cad/lib/hirth.scad
```

- [ ] **Step 3: Actualizar el diccionario `MODELS` en `cad/build.py`**

```python
MODELS = {
    "sensor_head.scad": ["pod", "knob"],
    "electronics_box.scad": ["box", "lid"],
    "rim_mount.scad": ["mount"],
}
```

- [ ] **Step 4: Correr el build completo**

Run: `cd cad && python build.py`
Expected: `5/5 piezas exportadas.`, código de salida 0, y en el reporte de tornillería previo ningún `ERROR`/`ASSERT`.

- [ ] **Step 5: Commit**

```bash
git add cad/build.py
git commit -m "cad: build.py exporta mount en vez de clamp/hook, borra lib/hirth.scad sin uso"
```

---

### Task 6: Actualizar documentación (`docs/bom.md` y nota en el spec de 2026-09-04)

**Files:**
- Modify: `docs/bom.md`
- Modify: `docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`

**Interfaces:** ninguna (solo documentación).

- [ ] **Step 1: Actualizar la tabla de tornillería en `docs/bom.md`**

Reemplazar:
```markdown
| Dónde | Tornillo | Tuerca | Cant. |
|---|---|---|---|
| Pivote de la articulación | M3×12 | 1, embutida en el pomo | 1 |
| Placa → mordaza | M3×30 | 2, embutidas en la placa | 2 |
| Apriete de los dos ganchos | M3×16 | 2, cautivas en el saliente | 2 |
| Caja → gancho | M3×14 | 2, embutidas en la espina | 2 |
| Tapa de la caja | M3×8 | 4, cautivas bajo la tapa | 4 |
| Módulo VL53L1X al pod | M2×8 | 2, sueltas por detrás del PCB | 2 |

**Total: 11 tornillos M3, 2 tornillos M2, 11 tuercas M3, 2 tuercas M2.**
```
por (ajustar las longitudes exactas al valor que imprima `python cad/build.py --report` en ese momento, no copiar los números de este plan a ciegas):
```markdown
| Dónde | Tornillo | Tuerca | Cant. |
|---|---|---|---|
| Pivote de la bisagra de fricción | M3×<ver build.py> | 1, en el pomo | 1 + 1 arandela suelta |
| Apriete del mount al borde | M3×<ver build.py> | 1, cautiva en el saliente | 1 |
| Mount → caja (interfaz heredada) | M3×14 | 2, embutidas en la espina de la caja | 2 |
| Tapa de la caja | M3×8 | 4, cautivas bajo la tapa | 4 |
| Módulo VL53L1X al pod | M2×<ver build.py> | 2, sueltas por detrás del PCB | 2 |

**Total: 8 tornillos M3, 2 tornillos M2, 8 tuercas M3, 2 tuercas M2, 1 arandela.**
```

- [ ] **Step 2: Actualizar la tabla de piezas impresas en `docs/bom.md`**

Reemplazar:
```markdown
| Pieza | Orientación |
|---|---|
| `clamp` | De canto |
| `plate` | Plana, dientes hacia arriba |
| `pod` | Plana, dientes hacia arriba |
| `knob` | Plana |
| `box` | Boca hacia arriba |
| `lid` | Plana |
| `hook` | De canto |
```
por:
```markdown
| Pieza | Orientación |
|---|---|
| `mount` | De canto |
| `pod` | (ver nota de orientación en `sensor_head.scad` tras el Task 2) |
| `knob` | Plana |
| `box` | Boca hacia arriba |
| `lid` | Plana |
```

Y actualizar la frase "Siete, ninguna necesita soportes." a "Cinco, ninguna necesita soportes." (confirmar antes que `pod()` reescrito de verdad no necesite soportes con la nueva forma; si el render del Task 2 mostró voladizos >45°, anotarlo aquí en vez de afirmar algo falso).

- [ ] **Step 3: Añadir nota en el spec de 2026-09-04**

En la sección "Diseño 3D" de `docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md`, justo antes de "### Cabeza del sensor: cuatro piezas *(implementada)*", añadir:

```markdown
> **Actualización 2026-09-18:** `clamp`+`hook` se fusionaron en una sola
> pieza (`mount`) y la bisagra Hirth se reemplazó por un pivote de fricción.
> Las secciones de abajo describen el diseño original; el estado actual vive
> en `docs/superpowers/specs/2026-09-18-cad-rim-mount-redesign-design.md`.
```

- [ ] **Step 4: Commit**

```bash
git add docs/bom.md docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md
git commit -m "docs: actualiza bom y spec original tras fusionar clamp+hook en mount"
```

---

### Task 7: Verificación final end-to-end

**Files:** ninguno nuevo, solo verificación.

- [ ] **Step 1: Build completo desde cero**

Run: `cd cad && rm -rf out && python build.py`
Expected: `5/5 piezas exportadas.`, código 0.

- [ ] **Step 2: Revisar el reporte de geometría completo una última vez**

Run: `python build.py --report`
Expected: el bloque de `geometry.scad` sigue mostrando `Posiciones utilizables: [8, 12, 16, 20] grados` (no cambió, porque `pod_arm` recalculado con la oreja en vez del Hirth debe seguir dando un valor razonable — si el rango de ángulos válidos se vació o quedó en 1 posición, `geometry.scad` aborta solo y hay que revisar `hinge_ear_w`/`pod_reach` en `params.scad`).

- [ ] **Step 3: Render final del ensamblaje para inspección visual**

Run:
```bash
"C:\Program Files\OpenSCAD\openscad.exe" -o out/final_check.png --imgsize=1400,1000 --camera=0,0,-30,55,0,25,300 -D 'part="assembly"' sensor_head.scad
```
Leer el PNG con Read. Confirmar que se ve un conjunto coherente: mordaza al borde, brazo hacia el pivote, pod apuntando hacia dentro, sin piezas flotantes ni intersecciones visualmente rotas.

- [ ] **Step 4: Reportar al usuario**

Resumir qué cambió, qué archivos se tocaron, y pedir confirmación de que el `mount` puede fabricarse (imprimirse) antes de dar la tarea por cerrada — es la primera vez que esta geometría existe, no hay impresión previa que la valide.
