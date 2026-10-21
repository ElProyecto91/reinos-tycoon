"""Copia al juego solo los modelos KayKit que usa la vista 3D (game/scripts/view/diorama.gd).

Uso: python3 -I tools/copiar_modelos.py CARPETA_gltf_DEL_PAQUETE game/assets/kaykit/models
  CARPETA_gltf_DEL_PAQUETE es ".../addons/kaykit_medieval_hexagon_pack/Assets/gltf" del repositorio
  https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 (licencia CC0).
Borra del destino los .gltf y .bin que ya no se usan; no toca la paleta ni las licencias.
La paleta recoloreada se genera aparte con tools/recolor_paleta.py.
"""
import os
import re
import shutil
import sys

DIORAMA = os.path.join(os.path.dirname(__file__), "..", "game", "scripts", "view", "diorama.gd")
FACTIONS = ["blue", "green", "red"]


def used_files() -> set:
    text = open(DIORAMA, encoding="utf-8").read()
    files = set()
    # MODELS: "clave": "nombre" (con %s para el bando)
    block = text[text.index("const MODELS := {"):text.index("# Conexiones de cada casilla")]
    for name in re.findall(r'"[a-z_]+": "([A-Za-z_%]+)"', block):
        if "%s" in name:
            for f in FACTIONS:
                files.add(name % f)
        else:
            files.add(name)
    # Tablas de casillas automáticas: "hex_xxx": [...]
    for name in re.findall(r'"(hex_[A-Za-z_]+)":', text):
        files.add(name)
    return files


def main(src_root: str, dst: str) -> None:
    index = {}
    for folder, _dirs, names in os.walk(src_root):
        for n in names:
            if n.endswith(".gltf"):
                index[n[:-5]] = folder
    wanted = used_files()
    missing = sorted(f for f in wanted if f not in index)
    if missing:
        sys.exit("Faltan en el paquete: " + ", ".join(missing))
    os.makedirs(dst, exist_ok=True)
    for name in sorted(wanted):
        for ext in (".gltf", ".bin"):
            shutil.copy(os.path.join(index[name], name + ext), os.path.join(dst, name + ext))
    removed = 0
    for n in os.listdir(dst):
        base, ext = os.path.splitext(n)
        if ext in (".gltf", ".bin") and base not in wanted:
            os.remove(os.path.join(dst, n))
            removed += 1
        elif n.endswith((".gltf.import", ".bin.import")) and n.rsplit(".", 2)[0] not in wanted:
            os.remove(os.path.join(dst, n))
    print("modelos usados:", len(wanted), "| archivos sobrantes borrados:", removed)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
