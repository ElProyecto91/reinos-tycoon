# Prototipo del MVP (entrega E)

**Aprobado por el usuario el 2026-10-21**, al ordenar empezar la Fase 1 tras leer el borrador. La región sigue sin investigarse. Cualquier punto se puede corregir más adelante.

## Objetivo

Demostrar que el núcleo funciona (sección 27): una región pequeña con provincias seleccionables, economía, población, producción, construcción y guardado. No es el MVP completo (10–20 provincias, 2–3 poderes, 8–12 mercancías): es su primera parte.

## Región propuesta

Península Ibérica hacia el año 1000, con el Califato de Córdoba y los reinos cristianos del norte.

- Motivo: caben 10–20 provincias y 2–3 poderes, y hay contraste jugable entre regadío y ciudades al sur y ganadería y montaña al norte.
- **No está investigada.** Los nombres, fronteras y datos históricos se definirán después, con fuentes y nivel de confianza (sección 32).
- Mientras tanto, las pruebas usan datos de ejemplo marcados como tales ("provincia de prueba A"), sin pretensión histórica.

## Alcance del prototipo

- 5 provincias seleccionables (subconjunto del MVP).
- Mercancías: trigo, harina, pan, madera, leña, más moneda como recurso institucional.
- Edificios (6): granja, granero, molino, panadería, leñador, vivienda.
- Cadena: cultivo, granero, molino, harina, panadería, pan consumido por la población.
- Población agregada con trabajadores limitados.
- Guardado y carga, progreso offline e interfaz táctil básica.

Fuera del prototipo: comercio, guerra, diplomacia, IA de rivales, tecnología, eventos y dinastías.

## Datos y valores

Mercancías, edificios, costes, producciones y consumos son **parámetros de juego**, no estadísticas históricas (sección 33). Irán en tablas de datos, separadas de la lógica, y se ajustarán con pruebas. Este borrador no fija cifras.

El límite offline inicial propuesto es de 10 horas (parámetro de balance, dentro del rango 8–12 h de la sección 19).

## Criterios de aceptación

Cada criterio es medible y tiene una prueba asociada. [PC] se prueba sin Android; [APK] exige un móvil real.

| ID | Criterio | Prueba |
|---|---|---|
| A1 | Conservación: tras 10 000 pasos de simulación, para cada mercancía y provincia, existencias finales = iniciales + producción + importaciones − consumo − exportaciones − pérdidas, sin diferencias | [PC] |
| A2 | Ninguna existencia supera la capacidad; con el almacén lleno la producción se detiene y se muestra el motivo | [PC] |
| A3 | Un edificio sin insumos no produce y muestra qué falta | [PC] |
| A4 | Los trabajadores asignados nunca superan los disponibles; reclutar reduce los disponibles | [PC] |
| A5 | Una construcción no empieza sin recursos ni mano de obra; el coste se descuenta una sola vez; se ve el tiempo restante | [PC] |
| A6 | La población consume alimento en cada paso; sin alimento hay primero un aviso y después descontento gradual; una provincia nunca desaparece en un solo paso | [PC] |
| A7 | Escenario de crisis: una mala cosecha provoca escasez y la provincia se recupera con reservas o producción | [PC] |
| A8 | Guardar y cargar devuelve un estado idéntico; un archivo incompleto no destruye un guardado válido; una versión antigua se migra o se rechaza con mensaje | [PC] |
| A9 | Offline: un tiempo negativo no da recompensa; se respeta el límite; repetir la carga no duplica recursos; al volver se muestra un resumen | [PC] |
| A10 | Simulación de 30 días de juego sin errores, sin valores negativos ni no numéricos | [PC] |
| A11 | Se puede seleccionar una provincia con el dedo y ver su producción, consumo, almacén y alertas; botones grandes, nada depende de hover; usable en vertical | [APK] manual |
| A12 | Se mide el tiempo por paso de simulación en el móvil y se registra; no se fija un umbral hasta tener la medida (sección 30) | [APK] manual |

## Estado de A11 y A12 (2026-10-21)

- **A11**: confirmado por el usuario en su móvil («Sí, se puede»), sin más detalle. No se ha medido cuántos toques fallan.
- **A12**: medido en el Redmi Note 13 5G: ≈ 0,65 ms por paso con 5 provincias (captura del usuario).

## Cómo se construye

Orden de las tareas 1.1 a 1.10 del ROADMAP: primero la simulación sin pantalla (A1 a A10), después el mapa y la interfaz (A11, A12). Cada tarea termina con sus pruebas en verde en GitHub Actions.

## Pendiente

1. ~~Investigar la región con fuentes (sección 32).~~ Hecho en parte el 2026-10-21: ver `REGION_IBERIA_1000.md` y `HISTORICAL_SOURCES.md`. Quedan huecos (economía de León y Castilla, Pamplona y condados catalanes, cifras de población, minas) listados al final de la ficha.
2. Ajustar mercancías, edificios y criterios si las pruebas lo aconsejan.
