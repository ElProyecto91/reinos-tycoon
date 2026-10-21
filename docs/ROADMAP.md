# Plan de trabajo (entrega C)

Estado a 2026-10-21 (v0.0.3):

- 0.1 hecha: repositorio creado y `main` subido. Las etiquetas no pudieron subirse (403); queda crearlas a mano.
- 0.2 hecha con salvedades: versión confirmada (4.7.2-stable); los requisitos de Android solo se leyeron en resúmenes (D-006).
- 0.3 hecha: GitHub Actions.
- 0.4, 0.5 y 0.6 hechas: el flujo salió en verde en su primera ejecución (2026-10-21, #1). Registros sin revisar.
- 0.7 hecha con salvedades: el APK instala y abre en un móvil real (captura del usuario, 2026-10-21). Faltan los puntos 4 a 6 de `TEST_PLAN.md`. Móvil de pruebas: Redmi Note 13 5G (versión de Android sin indicar).
- 0.8 hecha: `docs/MVP_PROTOTYPE.md` aprobado por el usuario el 2026-10-21 (al ordenar empezar la Fase 1). La región no está investigada.
- Fase 1: en curso desde 2026-10-21.
- Fase 1: cerrada con salvedades el 2026-10-21 (ver más abajo).
- Fase 2: en curso desde 2026-10-21 (2.1 empezada).
- Fase 3 en adelante: pendiente.

Leyenda de pruebas:
- **[DOC]** no se ejecuta nada; se revisa un documento.
- **[PC]** prueba automática sin Android (Godot en modo sin ventana). Como no hay ordenador, se ejecuta en GitHub Actions.
- **[APK]** exige exportar un APK y abrirlo en un móvil real.

Idea de orden: la simulación (economía, población, almacén, guardado, offline) no depende de la pantalla, así que se construye y se prueba primero sin Android. El móvil se necesita para táctil, zoom, reanudación de la app, rendimiento, memoria, batería y rutas reales de archivo.

## Fase 0 — Preparación

| ID | Tarea | Depende de | Prueba | Listo cuando |
|---|---|---|---|---|
| 0.1 | Subir el repositorio a GitHub (usuario) | — | [DOC] | repositorio visible con el contenido de la versión actual |
| 0.2 | Confirmar versión de Godot y requisitos de Android en la documentación oficial vigente | — | [DOC] | D-006 cerrada con versiones y enlaces |
| 0.3 | Elegir vía de pruebas (D-003) | — | [DOC] | decidido: GitHub Actions, porque el usuario no tiene ordenador |
| 0.4 | Escribir el flujo de GitHub Actions que instala Godot, plantillas, JDK y Android SDK en la nube | 0.2, 0.3 | [PC] | el flujo termina en verde y muestra la versión de Godot |
| 0.5 | Proyecto vacío en `game/` que arranque | 0.4 | [PC] | arranca sin errores en consola |
| 0.6 | Elegir herramienta de pruebas (nativa antes que bibliotecas, sección 24); una prueba que pasa y otra que falla a propósito | 0.5 | [PC] | ambas dan el resultado esperado sin ventana |
| 0.7 | Exportar el proyecto vacío a APK y abrirlo en un móvil | 0.5 | [APK] | abre en el móvil; procedimiento documentado paso a paso |
| 0.8 | Definir región del MVP, criterios de aceptación y pruebas del prototipo (entrega E) | D-005 | [DOC] | criterios medibles aprobados por el usuario |

Prioridad máxima: 0.3 y 0.4, porque sin Godot ejecutable no se puede probar nada. 0.8 debe estar aprobada antes de empezar la Fase 1.

## Fase 1 — Núcleo jugable

| ID | Tarea | Depende de | Prueba | Listo cuando |
|---|---|---|---|---|
| 1.1 | Carga de datos con validación e IDs estables (recursos, edificios) | 0.6 | [PC] | datos inválidos se rechazan con mensaje |
| 1.2 | Almacén con capacidad y balance de existencias (fórmula de la sección 10) | 1.1 | [PC] | nada aparece de la nada ni se duplica |
| 1.3 | Población agregada, consumo y trabajadores | 1.2 | [PC] | trabajadores nunca superan la población; la población consume |
| 1.4 | Edificios y producción con insumos | 1.2, 1.3 | [PC] | no produce sin insumos y muestra por qué se detiene |
| 1.5 | Construcción con costes y tiempo | 1.4 | [PC] | no se inicia si faltan recursos |
| 1.6 | Escasez gradual y recuperación | 1.3, 1.4 | [PC] | el hambre tiene consecuencias graduales y se puede revertir |
| 1.7 | Guardado y carga con versión de formato | 1.2 a 1.5 | [PC] | cargar tras guardar da el mismo estado; un archivo incompleto no destruye un guardado válido |
| 1.8 | Mapa de 10–20 provincias seleccionables | 0.5, 0.8 | [PC] lógica, [APK] táctil | seleccionar una provincia muestra su ficha |
| 1.9 | Interfaz provincial táctil | 1.4, 1.8 | [APK] | botones grandes, nada depende de hover, usable en el móvil |
| 1.10 | Cierre de fase: partida prolongada sin errores críticos de economía, guardado o interfaz (sección 27) | todo lo anterior | [PC] y [APK] | simulación larga sin fallos y sesión en móvil |

Las tareas 1.1 a 1.7 no necesitan pantalla. Se pueden hacer antes del mapa.

**Estado (2026-10-21):** 1.1 a 1.9 escritas y con las pruebas en verde en GitHub Actions (ejecución #16, 200 de 200): simulación, guardado, progreso offline (A9, D-016), mapa (D-017), interfaz táctil (D-018), medir velocidad (A12) y aviso de versión (D-015). **En el móvil real**: A12 medido (0,65 ms por paso, captura del usuario); **A11 (toque en provincias) sin confirmar** (lista en `TEST_PLAN.md`). 1.10: parte [PC] escrita (ver más abajo; 210 de 210 en GitHub Actions, ejecución #18) y parte [APK] pendiente. Criterios A1 a A10 cubiertos en pruebas de PC.

## Fase 1.10 — cierre (parte [PC] hecha; falta la parte [APK])

- [PC] `tests/test_closure.gd`: 2 años de juego con las 5 provincias y un jugador automático; 12 guardados y cargas en 6000 pasos con resultado idéntico al de la partida sin interrupciones; 40 cierres y reaperturas con ausencias de 0 s a 24 h y con el reloj hacia atrás, comparados paso a paso con una partida de referencia; un año de juego a ×600 a través de la pantalla real (autoguardado incluido); ajuste de ratón desde el toque. Hallazgo: D-020 (tope de edificios).
- [APK] A11 confirmado por el usuario el 2026-10-21 («Sí, se puede») y A12 medido (0,65 ms por paso). Quedan sin confirmar en el móvil los puntos 3, 4, 6, 8 y 9 de la lista de `TEST_PLAN.md`; ninguno ha dado un fallo.
- **Fase 1 cerrada con salvedades el 2026-10-21**: criterio de cierre cumplido (A11 confirmado y sin fallos críticos comunicados), pero con esos puntos pendientes de ver. Los puntos pendientes se comprobarán cuando el usuario pruebe las siguientes versiones.
- El usuario pide un **rediseño visual** («no me gusta cómo se ve… todo en general») y está pendiente de recibir su imagen de referencia; no cambia el cierre de la fase 1 (que es de funcionamiento) pero hay que hacerlo.

## Fase 2 — borrador para aprobar (NO empezada)

Según la sección 28 del documento maestro: estacionalidad, cadenas agrícola/forestal/minera, mantenimiento, necesidades, escasez y mejoras. Troceado propuesto (cada tarea con sus pruebas en verde antes de seguir). Los datos siguen siendo parámetros de juego provisionales, sin pretensión histórica; la región sigue sin investigarse.

| ID | Tarea | Prueba | Listo cuando |
|---|---|---|---|
| 2.1 | Calendario derivado del contador de pasos: día, mes, estación y año (un paso = una hora; año de 365 días = 8760 pasos y estaciones por mes, D-022) | [PC] | la estación se calcula solo desde el paso (no se guarda) y se muestra en la barra superior |
| 2.2 | Estacionalidad agrícola por mes y por cultivo (trigo: siembra de septiembre a diciembre, cosecha de mayo a julio según el calendario de Córdoba, D-022), en datos validados | [PC] | A1 (conservación) y A10 siguen en verde; la cosecha varía con la estación; la crisis A7 sigue recuperándose |
| 2.3 | Necesidad estacional de leña (calefacción) con escasez gradual como la del hambre | [PC] | sin leña hay aviso y después descontento gradual; se recupera |
| 2.4 | Cadena forestal ampliada (la minera queda aplazada hasta tener fuentes, D-023) | [PC] | no producen sin insumos y muestran por qué |
| 2.5 | Mantenimiento en mercancías además de moneda (por ejemplo herramientas) | [PC] | un edificio sin mantenimiento se detiene y lo dice (el estado `no_upkeep` ya existe) |
| 2.6 | Mejoras de edificio (nivel 2) con coste y efecto visibles | [PC] | no se mejora sin recursos; el efecto se aplica una sola vez |
| 2.7 | Interfaz de la fase 2: estación, necesidades y mejoras en la ficha | [APK] | se ve y se toca bien en el móvil |
| 2.8 | Cierre de la fase 2: partida larga con estaciones | [PC] y [APK] | como 1.10, sin errores críticos |

Las tres decisiones previas (año, estaciones por cultivo y minería) se tomaron con la investigación del 2026-10-21: D-022 y D-023. La fase 1 se cerró con salvedades el 2026-10-21; la 2.1 empieza en esa fecha.

## Fases 2 a 9

| Fase | Depende de | Qué exige APK |
|---|---|---|
| 2 Economía avanzada | 1 completa | solo la interfaz nueva |
| 3 Progreso offline | 1.7 | reanudar de verdad tras cerrar la app; la lógica se prueba en PC con un reloj simulado |
| 4 Comercio | 2 | solo la interfaz de rutas |
| 5 Mundo político | 2 | solo la interfaz |
| 6 Guerra | 4, 5 | solo la interfaz |
| 7 Ampliación histórica | 1 completa | medir rendimiento y memoria con 20, 100 y más provincias también en el móvil |
| 8 Automatización y progresión | 4 | solo la interfaz |
| 9 Pulido | todas | rendimiento, batería, accesibilidad, tutorial y distribución |

Las fases 3 a 8 se detallarán en tareas pequeñas al terminar la anterior, no antes. Cada fase termina con pruebas ejecutadas, documentación actualizada y versión identificable (sección 37).
