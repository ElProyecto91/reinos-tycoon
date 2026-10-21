"""Recolorea la paleta de los modelos KayKit: el césped original es amarillo-verdoso
(tono ~62°) y aquí se lleva a un verde natural (~96°, algo más oscuro). Solo toca los colores de esa franja
(con saturación alta); trigo, tejados, piedra, madera y árboles quedan como estaban.

Uso: python3 -I tools/recolor_paleta.py PALETA_ORIGINAL.png game/assets/kaykit/models/hexagons_medieval.png
La paleta original está en el repositorio del paquete (licencia CC0, ver docs/THIRD_PARTY_LICENSES.md).
Necesita Pillow; no se ejecuta durante la compilación: el resultado ya está en el repositorio.
"""
import colorsys
import sys

from PIL import Image

HUE_FROM = (56.0, 68.0)   # grados: franja amarillo-verdosa del césped
SAT_MIN = 0.55
HUE_SHIFT = 34.0          # 62° -> 96°
VALUE_SCALE = 0.90        # un poco más oscuro y menos chillón


def main(src: str, dst: str) -> None:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    cache = {}
    changed = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            key = (r, g, b)
            if key not in cache:
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                hd = h * 360.0
                if HUE_FROM[0] <= hd <= HUE_FROM[1] and s >= SAT_MIN:
                    nr, ng, nb = colorsys.hsv_to_rgb(((hd + HUE_SHIFT) % 360.0) / 360.0, s, v * VALUE_SCALE)
                    cache[key] = (round(nr * 255), round(ng * 255), round(nb * 255))
                else:
                    cache[key] = None
            if cache[key] is not None:
                px[x, y] = cache[key] + (a,)
                changed += 1
    im.save(dst, optimize=True)
    print("píxeles recoloreados:", changed, "de", im.width * im.height)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
