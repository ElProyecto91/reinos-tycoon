#!/usr/bin/env python3
"""Genera game/data/map.json (formato 2) a partir de Natural Earth (dominio público) y tools/mapa/provincias.py.

Uso:  python3 tools/mapa/generar_mapa.py RUTA_A_natural-earth-vector/geojson  [--preview salida.png] [--salida otro_map.json]

No hace falta para jugar: el resultado (map.json) está guardado en el repositorio. Sirve para regenerarlo.
Qué hace: dibuja la tierra en una rejilla, reparte la tierra jugable entre las provincias por cercanía a su capital
(con un peso a ojo), saca los contornos de cada territorio y de cada reino, las orillas, los ríos grandes y las vecindades.
LAS FORMAS DE LOS TERRITORIOS SON UNA APROXIMACIÓN DE JUEGO, NO FRONTERAS HISTÓRICAS.
"""
import json, math, sys, os
import numpy as np
import cv2
sys.path.insert(0, os.path.dirname(__file__))
from provincias import REALMS, P, FRONTERA, START_PROTOTIPO, START_POR_TAMANO, ROTULOS, ENCLAVES, DE_FRANCIA

# --- Proyección: equirrectangular con el coseno de la latitud media ------------------------------------
LON0, LON1 = -10.0, 4.6
LAT0, LAT1 = 35.6, 45.0          # LAT1 arriba (0.2.0: ampliado desde 44,2 para que quepa Burdeos)
COS = math.cos(math.radians(39.8))
ANCHO = 1400                      # unidades de mapa
UNID_POR_GRADO_LON = ANCHO / (LON1 - LON0)
UNID_POR_GRADO_LAT = UNID_POR_GRADO_LON / COS
ALTO = int(round((LAT1 - LAT0) * UNID_POR_GRADO_LAT))
ESC = 2                           # píxeles de rejilla por unidad de mapa
W, H = ANCHO * ESC, ALTO * ESC


def a_unid(lon, lat):
    return ((lon - LON0) * UNID_POR_GRADO_LON, (LAT1 - lat) * UNID_POR_GRADO_LAT)


def a_px(lon, lat):
    x, y = a_unid(lon, lat)
    return (x * ESC, y * ESC)


def anillos(geom):
    if geom is None:
        return []
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return geom["coordinates"]
    return []


def dibujar(feats, filtro=None):
    m = np.zeros((H, W), np.uint8)
    for f in feats:
        if filtro and not filtro(f):
            continue
        for poly in anillos(f["geometry"]):
            ext = np.array([a_px(*c[:2]) for c in poly[0]], np.float64)
            cv2.fillPoly(m, [np.round(ext * 16).astype(np.int32)], 1, lineType=cv2.LINE_8, shift=4)
            for hole in poly[1:]:
                h = np.array([a_px(*c[:2]) for c in hole], np.float64)
                cv2.fillPoly(m, [np.round(h * 16).astype(np.int32)], 0, shift=4)
    return m


def contornos(mask, eps_px=1.2, min_area_px=60):
    cs, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    out = []
    for c in cs:
        if cv2.contourArea(c) < min_area_px:
            continue
        a = cv2.approxPolyDP(c, eps_px, True)[:, 0, :].astype(np.float64) / ESC
        if len(a) >= 3:
            out.append([[round(float(x), 1), round(float(y), 1)] for x, y in a])
    return out


def main(carpeta, preview=None, salida_json=None):
    land = json.load(open(os.path.join(carpeta, "ne_50m_land.geojson")))["features"]
    paises = json.load(open(os.path.join(carpeta, "ne_50m_admin_0_countries.geojson")))["features"]
    tierra = dibujar(land)
    # Componentes conexos: la península (con el sur de Francia) es la mayor; África y las islas quedan fuera.
    n, lab = cv2.connectedComponents(tierra, connectivity=8)
    cuentas = np.bincount(lab.ravel())
    cuentas[0] = 0
    peninsula = lab == int(np.argmax(cuentas))
    # Suelo jugable: España, Portugal, Andorra y la Francia que cae dentro del mapa (el Rosellón, Tolosa y Gascuña).
    codigos = {"ESP", "PRT", "AND"}
    jug = dibujar(paises, lambda f: f["properties"]["ADM0_A3"] in codigos)
    fra = dibujar(paises, lambda f: f["properties"]["ADM0_A3"] == "FRA")
    ys, xs = np.mgrid[0:H, 0:W]
    lon = LON0 + (xs / ESC) / UNID_POR_GRADO_LON
    lat = LAT1 - (ys / ESC) / UNID_POR_GRADO_LAT
    # La Francia que no es el Rosellón solo la reparten las provincias de DE_FRANCIA; ninguna otra provincia entra en ella.
    francesa = (fra > 0) & ~((lat < 42.85) & (lon > 1.8))
    jug = (jug > 0) | (fra > 0)
    jug &= peninsula
    del xs, ys

    # Lado de la frontera: lo que queda al norte de la línea es de los reinos cristianos y lo que queda al sur, del califato.
    pol = [a_px(LON0 - 1, FRONTERA[0][1])] + [a_px(*c) for c in FRONTERA] + [a_px(LON1 + 1, FRONTERA[-1][1]), a_px(LON1 + 1, 50), a_px(LON0 - 1, 50)]
    norte = np.zeros((H, W), np.uint8)
    cv2.fillPoly(norte, [np.round(np.array(pol) * 16).astype(np.int32)], 1, shift=4)
    norte = norte > 0
    cristiana = np.array([p[3] != "califato" for p in P])
    # Reparto: cada píxel jugable va a la capital con menor (distancia − peso), solo entre las de su lado de la frontera.
    semillas = np.array([a_px(p[5], p[6]) for p in P])
    pesos = np.array([p[7] for p in P]) * UNID_POR_GRADO_LAT * ESC * 0.55   # peso en píxeles
    enclave_idx = [i for i, p in enumerate(P) if p[0] in ENCLAVES]
    de_francia = np.array([p[0] in DE_FRANCIA for p in P])
    yy, xx = np.nonzero(jug)
    etiqueta = np.full((H, W), -1, np.int16)
    for i in range(0, len(xx), 400000):
        sx, sy = xx[i:i + 400000], yy[i:i + 400000]
        d = np.hypot(sx[:, None] - semillas[None, :, 0], sy[:, None] - semillas[None, :, 1]) - pesos[None, :]
        lado = norte[sy, sx][:, None]
        d = np.where(lado == cristiana[None, :], d, 1e9)
        d[:, enclave_idx] = 1e9        # los enclaves no entran en el reparto por cercanía
        fr = francesa[sy, sx][:, None]
        d = np.where(fr == de_francia[None, :], d, 1e9)
        etiqueta[sy, sx] = np.argmin(d, axis=1)

    # Enclaves: la tierra (fuera de la península) que cae dentro de su caja.
    for i, p in enumerate(P):
        if p[0] in ENCLAVES:
            lo0, lo1, la0, la1 = ENCLAVES[p[0]]["caja"]
            caja = (lon >= lo0) & (lon <= lo1) & (lat >= la0) & (lat <= la1) & (tierra > 0) & (etiqueta < 0)
            etiqueta[caja] = i
    prov = []
    for i, p in enumerate(P):
        m = (etiqueta == i)
        # Se queda con los trozos mayores (un territorio partido por una ría no debe perder su mitad).
        polys = contornos(m, eps_px=1.4, min_area_px=200)
        if not polys:
            raise SystemExit("provincia sin territorio: " + p[0])
        x, y = a_unid(p[5], p[6])
        prov.append({
            "id": p[0], "name": p[1], "short": p[2], "realm": p[3], "look": p[4],
            "x": int(round(x)), "y": int(round(y)), "lon": p[5], "lat": p[6],
            "polygons": polys, "source": p[9],
            "start": START_PROTOTIPO.get(p[0]) or START_POR_TAMANO[p[8]],
        })
    # Vecindades: dos territorios son vecinos si comparten al menos 8 píxeles de lindero.
    pares = {}
    for dy, dx in ((0, 1), (1, 0)):
        a = etiqueta[: H - dy, : W - dx]
        b = etiqueta[dy:, dx:]
        sel = (a != b) & (a >= 0) & (b >= 0)
        for u, v in zip(a[sel].tolist(), b[sel].tolist()):
            k = (min(u, v), max(u, v))
            pares[k] = pares.get(k, 0) + 1
    vec = {p["id"]: [] for p in prov}
    for (u, v), c in pares.items():
        if c >= 8:
            vec[prov[u]["id"]].append(prov[v]["id"])
            vec[prov[v]["id"]].append(prov[u]["id"])
    ids = {p["id"] for p in prov}
    for pid, e in ENCLAVES.items():
        for otro in e["enlaces"]:
            assert otro in ids, otro
            if otro not in vec[pid]:
                vec[pid].append(otro)
            if pid not in vec[otro]:
                vec[otro].append(pid)
    for p in prov:
        p["neighbors"] = sorted(vec[p["id"]])

    # Reinos: contorno de cada uno y un punto bien dentro para su rótulo (máximo de la transformada de distancia).
    reinos = {}
    for rid, r in REALMS.items():
        idx = [i for i, p in enumerate(P) if p[3] == rid]
        m = np.isin(etiqueta, idx).astype(np.uint8)
        dist = cv2.distanceTransform(m, cv2.DIST_L2, 5)
        py, px = np.unravel_index(int(np.argmax(dist)), dist.shape)
        reinos[rid] = {
            "name": r["name"], "label": r["label"], "color": list(r["color"]), "note": r["note"],
            "outline": contornos(m, eps_px=1.6, min_area_px=200),
            "label_x": round(px / ESC, 1), "label_y": round(py / ESC, 1),
            "label_room": round(float(dist[py, px]) / ESC, 1),
        }

    # Orillas y tierra ajena (todo lo que no es jugable pero es tierra: Francia, África, islas).
    ajena = (tierra > 0) & ~jug & (etiqueta < 0)
    rios = []
    nombres = {"Duero", "Tajo", "Tejo", "Ebro", "Guadiana", "Guadalquivir", "Minho", "Segre"}
    for f in json.load(open(os.path.join(carpeta, "ne_10m_rivers_lake_centerlines.geojson")))["features"]:
        nm = f["properties"].get("name")
        if nm not in nombres or f["geometry"] is None:
            continue
        g = f["geometry"]
        lineas = [g["coordinates"]] if g["type"] == "LineString" else g["coordinates"]
        for l in lineas:
            pts = [a_unid(c[0], c[1]) for c in l if LON0 <= c[0] <= LON1 and LAT0 <= c[1] <= LAT1]
            if len(pts) >= 2:
                a = cv2.approxPolyDP(np.array(pts, np.float32).reshape(-1, 1, 2), 0.8, False)[:, 0, :]
                rios.append({"name": nm, "points": [[round(float(x), 1), round(float(y), 1)] for x, y in a]})
    km_por_unidad = 111.19 / UNID_POR_GRADO_LAT
    salida = {
        "format_version": 2,
        "status": "Mapa grande (M2–M5, 47 provincias). Las ENTIDADES POLÍTICAS y las capitales son históricas y aproximadas, hacia julio del año 1000 "
                  "(docs/REGION_IBERIA_1000.md; fuentes H-39 a H-44). La FORMA de cada territorio es una aproximación de juego (reparto por "
                  "cercanía a la capital), NO son fronteras históricas. Costas y ríos: Natural Earth (dominio público). Las poblaciones, edificios y "
                  "existencias de partida son PARÁMETROS DE JUEGO provisionales, no datos históricos. Cantidades en milésimas de unidad.",
        "width": ANCHO, "height": ALTO,
        "touch_slop": 24,
        "projection": {"lon0": LON0, "lat1": LAT1, "units_per_degree_lon": round(UNID_POR_GRADO_LON, 4),
                       "units_per_degree_lat": round(UNID_POR_GRADO_LAT, 4), "km_per_unit": round(km_por_unidad, 4)},
        "land": contornos(tierra, eps_px=1.0, min_area_px=40),
        "foreign_land": contornos(ajena.astype(np.uint8), eps_px=1.2, min_area_px=80),
        "rivers": rios,
        "labels": [{"text": t, "x": round(a_unid(lo, la)[0], 1), "y": round(a_unid(lo, la)[1], 1), "kind": k} for t, lo, la, k in ROTULOS],
        "realms": reinos,
        "provinces": prov,
    }
    json.dump(salida, open(salida_json or os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "map.json"), "w"), ensure_ascii=False, separators=(",", ":"))
    if preview:
        previa(salida, etiqueta, preview)
    print("provincias:", len(prov), "alto:", ALTO, "ríos:", len(rios))


def previa(s, etiqueta, ruta):
    img = np.full((ALTO, ANCHO, 3), (150, 120, 90), np.uint8)
    for ring in s["land"]:
        cv2.fillPoly(img, [np.array(ring, np.int32)], (200, 215, 225))
    for p in s["provinces"]:
        col = s["realms"][p["realm"]]["color"]
        for ring in p["polygons"]:
            cv2.fillPoly(img, [np.round(np.array(ring)).astype(np.int32)], (col[2], col[1], col[0]))
            cv2.polylines(img, [np.round(np.array(ring)).astype(np.int32)], True, (40, 40, 40), 1)
        cv2.circle(img, (p["x"], p["y"]), 3, (0, 0, 0), -1)
        cv2.putText(img, p["short"], (p["x"] + 4, p["y"] - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 0, 0), 1)
    for r in s["rivers"]:
        cv2.polylines(img, [np.round(np.array(r["points"])).astype(np.int32)], False, (200, 120, 40), 1)
    cv2.imwrite(ruta, img)


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    sj = sys.argv[sys.argv.index("--salida") + 1] if "--salida" in sys.argv else None
    a = [x for x in a if x != pv and x != sj]
    main(a[0], pv, sj)
