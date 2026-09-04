#!/usr/bin/env python3
"""Exporta los STL del proyecto con el CLI de OpenSCAD.

    python build.py                 # todas las piezas
    python build.py pod knob        # solo esas
    python build.py --report        # solo el informe de geometria, sin STL

Los STL salen a cad/out/, que esta en .gitignore: son generados, no fuente.
"""

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"

# En que archivo vive cada pieza. Los nombres de pieza son unicos en todo el
# proyecto a proposito, para poder pedirlas por nombre sin decir el archivo.
MODELS = {
    "sensor_head.scad": ["clamp", "plate", "pod", "knob"],
    "electronics_box.scad": ["box", "lid", "hook"],
}
PART_MODEL = {p: HERE / m for m, ps in MODELS.items() for p in ps}
PARTS = list(PART_MODEL)

# Rutas donde suele estar OpenSCAD si no esta en el PATH.
FALLBACKS = [
    r"C:\Program Files\OpenSCAD\openscad.exe",
    r"C:\Program Files (x86)\OpenSCAD\openscad.exe",
    "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD",
    "/usr/bin/openscad",
]


def find_openscad() -> str:
    found = shutil.which("openscad") or shutil.which("openscad.exe")
    if found:
        return found
    for path in FALLBACKS:
        if Path(path).exists():
            return path
    sys.exit("No encuentro OpenSCAD. Instalalo o ponlo en el PATH.")


def run(openscad: str, args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [openscad, *args], capture_output=True, text=True, encoding="utf-8",
        errors="replace",
    )


def report(openscad: str) -> None:
    """Imprime los ECHO de los modelos: angulos utiles y tornilleria."""
    echo_file = OUT / "report.echo"
    for model in MODELS:
        run(openscad, ["-o", str(echo_file), "--export-format=echo",
                       str(HERE / model)])
        if echo_file.exists():
            for line in echo_file.read_text(encoding="utf-8").splitlines():
                print(line.removeprefix('ECHO: ').strip('"'))


def build(openscad: str, part: str) -> bool:
    target = OUT / f"{part}.stl"
    start = time.monotonic()
    proc = run(openscad, ["-D", f'part="{part}"', "-o", str(target),
                          str(PART_MODEL[part])])
    elapsed = time.monotonic() - start

    # OpenSCAD manda los assert y los WARNING a stderr y devuelve != 0 si fallan.
    problems = [
        line for line in proc.stderr.splitlines()
        if "WARNING" in line or "ERROR" in line or "ASSERT" in line
    ]
    ok = proc.returncode == 0 and target.exists()

    print(f"  {'OK ' if ok else 'FALLO'} {part:<6} {elapsed:5.1f} s"
          f"{'' if ok else '  <-- revisa'}")
    for line in problems[:8]:
        print(f"        {line.strip()}")
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("parts", nargs="*", default=None,
                    help=f"piezas a exportar (por defecto: {', '.join(PARTS)})")
    ap.add_argument("--report", action="store_true",
                    help="solo el informe de geometria, sin exportar STL")
    args = ap.parse_args()

    openscad = find_openscad()
    OUT.mkdir(exist_ok=True)

    report(openscad)
    if args.report:
        return 0

    wanted = args.parts or PARTS
    unknown = [p for p in wanted if p not in PARTS]
    if unknown:
        sys.exit(f"Pieza desconocida: {', '.join(unknown)}. "
                 f"Validas: {', '.join(PARTS)}")

    print(f"\nExportando a {OUT}")
    results = [build(openscad, p) for p in wanted]
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} piezas exportadas.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
