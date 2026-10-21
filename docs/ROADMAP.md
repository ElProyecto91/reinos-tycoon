# Plan de trabajo (entrega C)

Estado a 2026-10-21 (v0.0.3):

- 0.1 hecha: repositorio creado y `main` subido. Las etiquetas no pudieron subirse (403); queda crearlas a mano.
- 0.2 hecha con salvedades: versión confirmada (4.7.2-stable); los requisitos de Android solo se leyeron en resúmenes (D-006).
- 0.3 hecha: GitHub Actions.
- 0.4, 0.5 y 0.6 escritas, **sin ejecutar**: se prueban en la primera ejecución del flujo en GitHub.
- 0.7 escrita, **sin ejecutar**: falta que el flujo genere el APK y abrirlo en un móvil.
- 0.8 pendiente: falta la región del MVP (D-005).
- Fase 1 en adelante: pendiente.

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
