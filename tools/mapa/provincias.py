"""Datos de partida del mapa grande (M1/M2/M3). Ver docs/REGION_IBERIA_1000.md y docs/HISTORICAL_SOURCES.md.

QUÉ ES DATO Y QUÉ ES PARÁMETRO
- Dato histórico (con fuente): la entidad política de cada provincia hacia el año 1000, el nombre de la cora o
  condado y su capital (H-39 a H-43). Las coordenadas son las de la ciudad actual que lleva ese nombre.
- Aproximación de juego: la FORMA de cada territorio. Se reparte el suelo entre las capitales por cercanía
  (con un peso a ojo), NO son fronteras históricas.
- Parámetro de juego: `tier` (tamaño de partida), población, edificios y existencias iniciales.
"""

# Cada reino o entidad: nombre, color del mapa (RGB 0-255) y nota de confianza.
REALMS = {
    "califato": {"name": "Califato de Córdoba", "color": (96, 142, 84), "label": "CALIFATO DE CÓRDOBA",
                 "note": "H-01, H-04, H-39. Gobierna Almanzor en nombre de Hisham II."},
    "leon": {"name": "Reino de León", "color": (140, 98, 156), "label": "REINO DE LEÓN",
             "note": "H-09. Alfonso V, menor; regencia. Asturias y Galicia se tratan como parte de su corona: las fuentes leídas no aclaran el estatus de Galicia en 997-1000 (H-42)."},
    "portugal": {"name": "Condado de Portugal", "color": (96, 140, 176), "label": "COND. DE PORTUGAL",
                 "note": "H-42. Dentro del Reino de León con autonomía variable; Menendo González desde 997."},
    "castilla": {"name": "Condado de Castilla", "color": (176, 84, 72), "label": "CONDADO DE CASTILLA",
                 "note": "H-07, H-08. Conde Sancho García; bajo León de forma nominal."},
    "pamplona": {"name": "Reino de Pamplona", "color": (206, 142, 70), "label": "REINO DE PAMPLONA",
                 "note": "H-08, H-43. El condado de Aragón estaba incorporado a la corona de Pamplona."},
    "tolosa": {"name": "Condado de Tolosa", "color": (84, 150, 152), "label": "CONDADO DE TOLOSA",
               "note": "H-45. Los condes habían perdido casi todo su poder efectivo hacia fines del siglo X; la ciudad la regía un vizconde. Nominalmente bajo el rey de Francia."},
    "gascuna": {"name": "Ducado de Gascuña", "color": (190, 128, 148), "label": "DUCADO DE GASCUÑA",
                "note": "H-46. Duque Bernat I Guilhem (996-1009), de la línea ducal vasca; en la práctica independiente de los reyes francos. Su madre, o su padre, enlazaba con Pamplona por matrimonio (Urraca Garcés)."},
    "carcasona": {"name": "Condado de Carcasona", "color": (156, 122, 92), "label": "COND. DE CARCASONA",
                  "note": "H-50. Roger I, conde de Comminges desde 957, de Couserans desde 983 y de Carcasona hacia el 1000 (muere en 1012). Una sola casa con tres condados; la forma de cada uno es aproximación de juego."},
    "catalanes": {"name": "Condados catalanes", "color": (218, 188, 84), "label": "CONDADOS CATALANES",
                  "note": "H-41. Condados independientes entre sí; desde 987 los condes no rinden homenaje a la nueva dinastía francesa."},
}

# id, nombre, nombre corto, reino, aspecto 3D, lon, lat, peso del reparto (a ojo), tamaño de partida, fuente
# tier: 5 capital, 4 ciudad grande, 3 ciudad, 2 villa, 1 frontera/rural
P = [
    # --- Califato de Córdoba: coras del interior ------------------------------------------------
    ("cordoba", "Córdoba", "Córdoba", "califato", "cordoba", -4.78, 37.88, 0.55, 5, "H-01 capital; H-39 cora"),
    ("sevilla", "Cora de Sevilla", "Sevilla", "califato", "cordoba", -5.98, 37.39, 0.5, 4, "H-39 Ishbiliya"),
    ("jaen", "Cora de Jaén", "Jaén", "califato", "cordoba", -3.79, 37.77, 0.1, 2, "H-39 Yayyán"),
    ("elvira", "Cora de Elvira", "Elvira", "califato", "cordoba", -3.60, 37.18, 0.1, 3, "H-39 Elvira (Granada)"),
    ("rayya", "Cora de Rayya", "Rayya", "califato", "cordoba", -4.42, 36.72, 0.0, 3, "H-39 Rayya (Málaga)"),
    ("algeciras", "Cora de Algeciras", "Algeciras", "califato", "cordoba", -5.45, 36.13, -0.1, 2, "H-39 Algeciras"),
    ("ecija", "Cora de Écija", "Écija", "califato", "cordoba", -5.08, 37.54, 0.3, 2, "H-39 Écija"),
    ("ronda", "Cora de Ronda", "Ronda", "califato", "cordoba", -5.17, 36.74, 0.1, 1, "H-39 Ronda"),
    ("niebla", "Cora de Niebla", "Niebla", "califato", "cordoba", -6.68, 37.35, 0.1, 2, "H-39 Niebla"),
    ("pechina", "Cora de Pechina", "Pechina", "califato", "zaragoza", -2.46, 36.84, 0.0, 3, "H-39 Pechina (Almería)"),
    ("tudmir", "Cora de Tudmir", "Tudmir", "califato", "zaragoza", -1.13, 37.98, 0.2, 3, "H-39 Tudmir (Murcia)"),
    ("valencia", "Cora de Valencia", "Valencia", "califato", "zaragoza", -0.38, 39.47, 0.3, 4, "H-39 Balansiya"),
    ("tortosa", "Cora de Tortosa", "Tortosa", "califato", "zaragoza", 0.52, 40.81, 0.0, 2, "H-39 Tortosa"),
    # --- Califato: marcas fronterizas -----------------------------------------------------------
    ("merida", "Marca Inferior (Mérida)", "Mérida", "califato", "cordoba", -6.34, 38.92, 0.9, 3, "H-39 Marca Inferior"),
    ("mertola", "Cora de Mértola", "Mértola", "califato", "cordoba", -7.66, 37.64, 0.0, 1, "H-39 Mértola"),
    ("coimbra", "Coímbra", "Coímbra", "califato", "cordoba", -8.43, 40.21, 0.0, 2, "H-42 recuperada por Almanzor en 987"),
    ("toledo", "Toledo", "Toledo", "califato", "toledo", -4.02, 39.86, 0.7, 4, "H-04, H-06 Marca Media"),
    ("medinaceli", "Marca Media (Medinaceli)", "Medinaceli", "califato", "toledo", -2.43, 41.17, 0.9, 2, "H-06 centro administrativo"),
    ("santaver", "Cora de Santaver", "Santaver", "califato", "toledo", -2.13, 40.08, 0.3, 1, "H-39 Santaveria"),
    ("lisboa", "Cora de Lisboa", "Lisboa", "califato", "cordoba", -9.14, 38.72, 0.15, 3, "H-55 antes de 1022 el estado anterior a la taifa de Lisboa es el califato (fuente en confianza media: no describe el año 1000)"),
    ("denia", "Dénia", "Dénia", "califato", "cordoba", 0.11, 38.84, 0.1, 2, "H-56 la taifa de Dénia se creó en 1010 tras la desintegración del califato; en 1000 seguía en él (inferencia)"),
    ("madrid", "Fortaleza de Mayrit (Madrid)", "Madrid", "califato", "toledo", -3.70, 40.42, 0.1, 1, "H-57 fortaleza de la Marca Media levantada en tiempos de Muhammad I (852-886)"),
    ("zaragoza", "Zaragoza", "Zaragoza", "califato", "zaragoza", -0.88, 41.65, 0.6, 3, "H-05 Marca Superior"),
    ("huesca", "Cora de Huesca", "Huesca", "califato", "zaragoza", -0.41, 42.14, -0.1, 2, "H-05, H-39 Washka"),
    ("lleida", "Cora de Lérida", "Lérida", "califato", "zaragoza", 0.62, 41.62, 0.0, 2, "H-05, H-39 Lleida"),
    ("tudela", "Cora de Tudela", "Tudela", "califato", "zaragoza", -1.61, 42.06, 0.0, 2, "H-05, H-39 Tudela"),
    # --- Reino de León y Condado de Portugal ----------------------------------------------------
    ("leon", "Reino de León", "León", "leon", "norte", -5.57, 42.60, 0.9, 3, "H-09"),
    ("asturias", "Asturias", "Asturias", "leon", "norte", -5.85, 43.36, 0.0, 2, "H-09"),
    ("galicia", "Galicia", "Galicia", "leon", "norte", -8.54, 42.88, 0.7, 2, "H-42 estatus no aclarado"),
    ("zamora", "Frontera del Duero", "Zamora", "leon", "norte", -5.75, 41.50, 0.0, 1, "H-42 ruta de Almanzor 997"),
    ("portugal", "Condado de Portugal", "Portugal", "portugal", "norte", -8.61, 41.15, 0.5, 2, "H-42"),
    # --- Condado de Castilla --------------------------------------------------------------------
    ("castilla", "Condado de Castilla", "Castilla", "castilla", "norte", -3.70, 42.34, 0.9, 3, "H-07"),
    # --- Reino de Pamplona ----------------------------------------------------------------------
    ("pamplona", "Reino de Pamplona", "Pamplona", "pamplona", "norte", -1.64, 42.82, 0.5, 2, "H-08"),
    ("aragon", "Condado de Aragón", "Aragón", "pamplona", "norte", -0.55, 42.57, 0.0, 1, "H-43"),
    # --- Condados catalanes ---------------------------------------------------------------------
    ("ribagorza", "Condado de Ribagorza", "Ribagorza", "catalanes", "norte", 0.55, 42.28, 0.0, 1, "H-41"),
    ("pallars", "Condado de Pallars", "Pallars", "catalanes", "norte", 0.89, 42.17, -0.1, 1, "H-41"),
    ("urgell", "Condado de Urgell", "Urgell", "catalanes", "norte", 1.46, 42.36, 0.0, 1, "H-41"),
    ("cerdanya", "Condado de Cerdaña", "Cerdaña", "catalanes", "norte", 1.93, 42.43, -0.1, 1, "H-41"),
    ("barcelona", "Condado de Barcelona", "Barcelona", "catalanes", "norte", 2.17, 41.39, 0.5, 3, "H-41, H-01"),
    ("osona", "Condado de Osona", "Osona", "catalanes", "norte", 2.25, 41.93, 0.0, 1, "H-41"),
    ("besalu", "Condado de Besalú", "Besalú", "catalanes", "norte", 2.70, 42.20, 0.0, 1, "H-41"),
    ("empuries", "Condado de Ampurias", "Ampurias", "catalanes", "norte", 3.10, 42.13, -0.1, 1, "H-41"),
    ("rosello", "Condado de Rosellón", "Rosellón", "catalanes", "norte", 2.97, 42.60, -0.1, 1, "H-41"),
    # --- Ampliación M4 (versión 0.2.0): sur de Francia y enclaves ---------------------------------------
    ("tolosa", "Condado de Tolosa", "Tolosa", "tolosa", "norte", 1.44, 43.60, 0.4, 3, "H-45"),
    ("gascuna", "Ducado de Gascuña", "Gascuña", "gascuna", "norte", -0.58, 44.84, 0.5, 2, "H-46 capital Burdeos según el artículo (no confirmada para el año 1000)"),
    # --- Ampliación M5 (versión 0.3.0): el Mediodía entre Tolosa y los Pirineos ------------------------------
    ("carcasona", "Condado de Carcasona", "Carcasona", "carcasona", "norte", 2.35, 43.21, 0.45, 2, "H-50 Roger I hereda Carcasona de su madre hacia el 1000"),
    ("cominges", "Condados de Cominges y Coserans", "Cominges", "carcasona", "norte", 0.72, 43.11, 0.35, 1, "H-50 Cominges desde 957 y Coserans desde 983 (ubicación aproximada de juego)"),
    ("bearn", "Vizcondado de Béarn", "Béarn", "gascuna", "norte", -0.37, 43.30, 0.0, 1, "H-51 vizconde Centule III (984-1004), de la casa de Gascuña; la fuente no da capital: ubicación aproximada de juego"),
    # --- Ampliación M6 (versión 0.4.0) ---------------------------------------------------------------------
    ("narbona", "Vizcondado de Narbona", "Narbona", "tolosa", "norte", 3.00, 43.18, 0.15, 1, "H-53 vizconde Raimundo I (h. 969-1019/23), «nominalmente sujeto a los condes de Tolosa pero gobernado casi siempre con autonomía»"),
    ("alava", "Álava y Vizcaya", "Álava", "pamplona", "norte", -2.80, 43.00, 0.2, 1, "H-54 CONFIANZA BAJA: la fuente solo dice que Vizcaya estaba bajo control navarro en el siglo X y que Munio Velaz era conde de Álava; no dice quién mandaba en el 1000"),
    ("baleares", "Islas Baleares", "Baleares", "califato", "cordoba", 2.65, 39.57, 0.0, 2, "H-47 SIN CONFIRMAR: no se encontró qué estatus tenían hacia el 1000; la taifa propia es de 1018"),
    ("ceuta", "Ceuta", "Ceuta", "califato", "cordoba", -5.31, 35.89, 0.0, 1, "H-48 plaza omeya bajo Córdoba hasta al menos 984; hacia el 1000 sin confirmar"),
]

# Provincias que se reparten la tierra francesa (el resto de provincias no entra en ella).
DE_FRANCIA = {"tolosa", "gascuna", "carcasona", "cominges", "bearn", "narbona"}

# Enclaves: territorios que no son una parte continua de la península. Su suelo no sale del reparto por cercanía sino de la
# tierra que cae dentro de una caja (lon0, lon1, lat0, lat1); `enlaces` son vecindades por mar (no comparten lindero).
ENCLAVES = {
    "baleares": {"caja": (1.1, 4.5, 38.5, 40.2), "enlaces": ["valencia", "tortosa", "barcelona"]},
    "ceuta": {"caja": (-5.75, -5.05, 35.60, 35.98), "enlaces": ["algeciras"]},
}

# Línea de frontera APROXIMADA entre los reinos cristianos (al norte) y el califato (al sur), de oeste a este, en (lon, lat).
# Sigue el Duero y luego el pie del Pirineo; está dibujada a mano a partir del dato de H-07 («el condado llega al Duero») y de lo
# que se sabe en general; NO tiene fuente propia. Cualquier territorio cristiano queda al norte y cualquiera del califato al sur.
FRONTERA = [
    (-10.5, 40.55), (-8.7, 40.55), (-7.6, 41.05), (-6.6, 41.25), (-5.9, 41.40), (-5.0, 41.55), (-4.2, 41.55),
    (-3.3, 41.55), (-2.9, 41.75), (-2.3, 42.15), (-1.9, 42.35), (-1.2, 42.30), (-0.7, 42.30), (0.0, 42.20), (0.4, 42.05),
    (0.8, 41.95), (1.3, 41.85), (1.8, 41.55), (2.0, 41.35), (2.3, 41.0), (3.5, 41.0),
]

# Estado inicial (PARÁMETROS DE JUEGO, no históricos). Todas las provincias empiezan con 1,8 de herramientas (el tope
# del almacén): la mina y la herrería gastan herramientas de mantenimiento y sin reserva no podrían arrancar. Las cinco provincias del prototipo conservan sus cifras;
# el resto las toma de su tamaño (`tier`).
START_PROTOTIPO = {
    "toledo": {"population": 100, "buildings": ["granary", "farm", "farm", "mill", "bakery", "woodcutter"], "stock": {"bread": 12000, "wheat": 6000, "firewood": 5000, "wood": 5000, "coin": 20000, "tools": 1800}},
    "zaragoza": {"population": 80, "buildings": ["granary", "farm", "farm", "farm", "mill"], "stock": {"bread": 9000, "wheat": 4000, "wood": 2000, "coin": 15000, "tools": 1800}},
    "castilla": {"population": 60, "buildings": ["granary", "woodcutter", "woodcutter", "farm"], "stock": {"bread": 9000, "wheat": 2000, "wood": 6000, "firewood": 4000, "coin": 12000, "tools": 1800}},
    "cordoba": {"population": 140, "buildings": ["granary", "farm", "farm", "mill", "bakery", "woodcutter", "house", "house"], "stock": {"bread": 15000, "wheat": 6000, "firewood": 6000, "wood": 8000, "coin": 25000, "tools": 1800}},
    "leon": {"population": 40, "buildings": ["farm", "woodcutter"], "stock": {"bread": 6000, "wood": 3000, "firewood": 2000, "coin": 8000, "tools": 1800}},
}
START_POR_TAMANO = {
    4: {"population": 100, "buildings": ["granary", "farm", "farm", "mill", "bakery", "woodcutter"], "stock": {"bread": 12000, "wheat": 5000, "firewood": 4000, "wood": 4000, "coin": 18000, "tools": 1800}},
    3: {"population": 70, "buildings": ["granary", "farm", "farm", "mill"], "stock": {"bread": 9000, "wheat": 3000, "wood": 2500, "coin": 12000, "tools": 1800}},
    2: {"population": 50, "buildings": ["granary", "farm", "woodcutter"], "stock": {"bread": 7000, "wheat": 1500, "wood": 3000, "firewood": 1500, "coin": 8000, "tools": 1800}},
    1: {"population": 35, "buildings": ["farm", "woodcutter"], "stock": {"bread": 5000, "wood": 2000, "firewood": 1500, "coin": 5000, "tools": 1800}},
}

# Rótulos del mapa (texto, lon, lat, clase). Solo orientan: mares y tierras fuera de la partida.
ROTULOS = [
    ("OCÉANO ATLÁNTICO", -9.4, 36.3, "mar"),
    ("MAR CANTÁBRICO", -4.6, 44.0, "mar"),
    ("MAR MEDITERRÁNEO", -0.2, 37.0, "mar"),
    ("ÁFRICA", 0.5, 35.75, "ajena"),
]
