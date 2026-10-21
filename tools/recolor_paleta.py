"""Recolorea la paleta de los modelos KayKit para que la vista 3D no parezca un juguete.

El césped original es amarillo-verdoso (tono ~62°) y el agua un cian muy saturado (~198°). Solo se tocan
esas dos franjas (con saturación alta) y los tres tonos del camino (crema casi blanco); piedra, madera,
tejados y el resto quedan como estaban. Modos:
  verde: césped a un verde natural (~96°, algo más oscuro). Agua intacta. Reproduce exactamente
         game/assets/kaykit/models/hexagons_medieval.png (la vista KayKit original).
  seco:  césped a un ocre-tostado apagado, agua a un verde-azulado turbio y camino a tierra batida
         — sur y centro peninsular.
  norte: césped a un verde apagado, el mismo agua turbia y el mismo camino — norte cristiano.
Los colores son suposición de diseño apoyada en el clima actual (ver docs/REGION_IBERIA_1000.md).

Uso: python3 -I tools/recolor_paleta.py MODO PALETA_ORIGINAL.png SALIDA.png
La paleta original está en el repositorio del paquete (licencia CC0, ver THIRD_PARTY_LICENSES.md).
Necesita Pillow; no se ejecuta durante la compilación: el resultado ya está en el repositorio.
"""
import colorsys
import sys

from PIL import Image

# Una regla: (tono mínimo, tono máximo, saturación mínima, ("desplaza" | "fija", grados), factor de saturación, factor de valor)
CESPED = (56.0, 68.0, 0.55)
AGUA = (190.0, 206.0, 0.60)

# Los tres colores exactos que solo usan los tramos de camino (medidos en las coordenadas UV de hex_road_*.gltf).
CAMINO = {(223, 183, 135), (219, 176, 127), (212, 164, 113)}
CAMINO_SATURACION = 0.80
CAMINO_VALOR = 0.74

MODOS = {
    "verde": [CESPED + (("desplaza", 34.0), 1.00, 0.90)],
    "seco": [
        CESPED + (("desplaza", -16.0), 0.60, 0.80),
        AGUA + (("fija", 174.0), 0.46, 0.58),
    ],
    "norte": [
        CESPED + (("desplaza", 30.0), 0.50, 0.60),
        AGUA + (("fija", 174.0), 0.46, 0.58),
    ],
}


def main(modo: str, src: str, dst: str) -> None:
    reglas = MODOS[modo]
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
                cache[key] = None
                if modo != "verde" and key in CAMINO:
                    nr, ng, nb = colorsys.hsv_to_rgb(h, s * CAMINO_SATURACION, v * CAMINO_VALOR)
                    cache[key] = (round(nr * 255), round(ng * 255), round(nb * 255))
                    px[x, y] = cache[key] + (a,)
                    changed += 1
                    continue
                for lo, hi, smin, (tipo, grados), fs, fv in reglas:
                    if lo <= hd <= hi and s >= smin:
                        nh = (hd + grados) % 360.0 if tipo == "desplaza" else grados
                        nr, ng, nb = colorsys.hsv_to_rgb(nh / 360.0, min(1.0, s * fs), v * fv)
                        cache[key] = (round(nr * 255), round(ng * 255), round(nb * 255))
                        break
            if cache[key] is not None:
                px[x, y] = cache[key] + (a,)
                changed += 1
    im.save(dst, optimize=True)
    print("píxeles recoloreados:", changed, "de", im.width * im.height)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
