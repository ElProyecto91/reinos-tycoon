# Plan de pruebas

Regla (sección 29): ninguna prueba se marca como superada si no se ha ejecutado. **Primera ejecución real: 2026-10-21, GitHub Actions, ejecución #1 (commit `10431e0`), en verde. Los registros no se han revisado: el resultado es el estado que comunicó el usuario.**

## Cómo se ejecutan

- En GitHub: automáticamente en cada subida a `main` (pestaña Actions, flujo "Pruebas y APK de depuración"). Primero corre el trabajo `pruebas` y, si pasa, el trabajo `apk`.
- A mano, para quien tenga Godot: `godot --headless --path game -s res://tests/run_tests.gd`.

## Convenciones

- Un archivo por sistema en `game/tests/`, con `extends "res://tests/test_case.gd"`.
- Cada prueba es un método cuyo nombre empieza por `test_` y usa `assert_true` o `assert_eq`.
- Cada archivo nuevo se añade a la lista `TEST_FILES` de `run_tests.gd`.
- Código de salida 0: todo pasó. Código 1: algún fallo, o no se ejecutó ninguna prueba.
- `selftest_fail.gd` no está en `TEST_FILES`: solo se ejecuta con `-- --selftest-fail`, para comprobar que el ejecutor detecta fallos.

## Pruebas definidas

| Prueba | Archivo | Qué comprueba | Estado |
|---|---|---|---|
| test_basic_arithmetic | test_smoke.gd | que el ejecutor corre una prueba trivial | superada en CI (#1), de forma indirecta* |
| test_project_version_defined | test_smoke.gd | que `project.godot` define la versión | superada en CI (#1), de forma indirecta* |
| test_intentional_failure | selftest_fail.gd | que el ejecutor devuelve código distinto de 0 ante un fallo (el flujo lo exige) | cumplida en CI (#1), de forma indirecta* |

\*Indirecta: el flujo exige que el ejecutor devuelva 0 con las dos pruebas normales y un código distinto de 0 con el fallo intencionado, y todo salió en verde. No se han leído los registros de cada prueba.

Desde la fase 1 hay además pruebas de reglas del juego, una por comportamiento, en: `test_game_data.gd` (datos y reglas), `test_store.gd` (almacén y conservación), `test_population.gd`, `test_production.gd`, `test_construction.gd`, `test_scarcity.gd` (A6/A7, crisis y recuperación), `test_long_run.gd` (A1: 10 000 pasos; A10: 30 días; determinismo) y `test_save.gd` (A8: ida y vuelta, archivo truncado, suma de control alterada, versión nueva, escritura interrumpida, copia `.bak`) `test_update_check.gd` (aviso de versión nueva, D-015) `test_offline.gd` (A9, D-016), `test_map.gd` (mapa y selección, D-017), `test_session.gd` (arranque, guardado y archivos dañados) y `test_ui_logic.gd` (textos, toque en el mapa, botones, velocidad, autoguardado, pausa/reanudación; D-018). Total actual: 200 pruebas.

Cómo se comprobó que no pasan por vacío: se desactivó a propósito la comprobación de la suma de control en una copia y `test_tampered_content_is_detected_by_the_checksum` falló; el autotest (`-- --selftest-fail`) devuelve código 1. Esa comprobación se hizo una vez, a mano; no está automatizada.

La interfaz se prueba sin ventana, llamando a sus métodos con eventos fabricados; **no** se prueba el dibujado. Para eso hay capturas a ojo (`tools/captura_ui.gd`, ver su cabecera) y la comprobación manual A11 en el móvil.

## Comprobaciones manuales en móvil

### Fase 0 (tarea 0.7)

Estado: los puntos 1 a 3 se comprobaron con una captura del usuario (2026-10-21, pantalla en vertical, Redmi Note 13 5G). Los puntos 4 a 6 quedaron sin ejecutar y **han cambiado**: desde la fase 1 la app está bloqueada en vertical (4 ya no aplica) y pide el permiso de Internet (6 ya no aplica tal cual; ver abajo).

1. Descargar el artefacto del flujo e instalar el APK (hasta la ejecución #16 era un zip que había que descomprimir; después se sube como `.apk` suelto, D-019).
2. La app abre y no se cierra sola.
3. Se ve centrado el texto de arranque.

### Fase 1 (APK de la ejecución #16 o posterior) — parcialmente ejecutada por el usuario (ver registro de resultados)

Instalación: si Android rechaza instalar encima del anterior, desinstalar primero (aún no hay partidas que perder).

1. Se ve el mapa con 5 provincias y los botones de velocidad, en vertical y sin recortes (comparar con las capturas). Anotar si algo queda tapado por la cámara o la barra inferior.
2. Tocar cada provincia con el dedo: se marca y aparece su ficha debajo. ¿Se acierta a la primera? (A11)
3. Desplazar la ficha con el dedo: se ven existencias, edificios y botones de construir.
4. Pulsar «Construir» en una provincia con recursos: aparece la obra y baja el tiempo restante.
5. Cambiar la velocidad a ×600 y ver pasar los días; volver a ×60.
6. Cerrar la app del todo y volver a abrirla: debe seguir la partida y mostrar «Mientras estabas fuera» con el tiempo real que estuvo cerrada (un paso por minuto, máximo 10 h).
7. Menú → «Medir velocidad»: anotar los milisegundos por paso (A12).
8. Menú → «Buscar actualización» con Internet: debe decir «Todavía no hay versiones publicadas…» (el repositorio no tiene ninguna release). Sin Internet: debe decir que no pudo conectar.
9. Ajustes del sistema → Apps → Reinos Tycoon → Permisos: solo debería figurar Internet (a veces Android no lo lista, por ser un permiso normal).

Al ejecutarlas, anotar fecha, modelo de móvil, versión de Android y qué pasó.

## Registro de resultados

| Fecha | Qué se ejecutó | Resultado | Notas |
|---|---|---|---|
| 2026-10-21 | Flujo completo, ejecución #1 (commit 10431e0): pruebas y APK | Verde, 1 min 57 s (según el estado comunicado por el usuario) | Registros sin revisar. El APK se generó y se subió como artefacto |
| 2026-10-21 | Comprobaciones manuales 1 a 3 (instalar, abrir, ver el texto) con el APK de la ejecución #1 | Superadas según la captura del usuario: se ve centrado «Reinos Tycoon / v0.0.3 (fase 0) / Arranque correcto» en vertical | Móvil: Redmi Note 13 5G; versión de Android sin indicar. Puntos 4 a 6 sin ejecutar |
| 2026-10-21 | Ejecución #9 de CI (commit bc9b0f9), fase 1 tareas 1.1–1.7 | **Fallo** | 124 OK. Falló A7 (la provincia no se recuperaba) y todas las pruebas de guardado (error de nombre: una función propia llamada `wrap` choca con la integrada de GDScript). El trabajo `apk` se omitió |
| 2026-10-21 | Las 140 pruebas con Godot 4.7.2 ejecutado en el entorno del asistente (sin CI), tras los arreglos de D-014 y el cambio de nombre `wrap` → `pack` | 140 de 140 superadas, código de salida 0 | No es CI: el resultado en GitHub está pendiente. Mismo número de versión de Godot que la CI, pero otro sistema |
| 2026-10-21 | Ejecución #10 de CI (commit b339805): pruebas y APK | **Verde**: 140 de 140 pruebas; APK generado con `version/code=13`, firmado con la clave de depuración de la imagen (SHA-256 `f3e6ecc4…48d5`) | Los resultados de las pruebas coinciden con los locales (crisis recuperada en el paso 172). Primera vez que se ejecutan la numeración y la comprobación de firma. APK **no instalado todavía** en el móvil |
| 2026-10-21 | Las 161 pruebas en local (Godot 4.7.2 en el entorno del asistente) con progreso offline (A9) | 161 de 161 superadas | Sabotajes hechos a mano en una copia, uno cada vez: quitar el tope, aceptar tiempo negativo, perder el resto de tiempo, no avanzar la marca. Las pruebas de `test_offline.gd` fallaron en los cuatro casos. Pendiente de CI |
| 2026-10-21 | Las 172 pruebas en local con el mapa (tarea 1.8) | 172 de 172 superadas | Sabotajes a mano: aceptar vecindad no mutua, zonas de toque solapadas, provincias aisladas y un radio de toque ampliado; las pruebas fallaron en los cuatro. Pendiente de CI |
| 2026-10-21 | Ejecución #13 de CI (commit 0b2800a): mapa y sesión | **Verde**: 180 de 180; APK generado | Primera vez con el mapa de ejemplo y la sesión en CI |
| 2026-10-21 | Las 195 pruebas en local con la interfaz (1.9) | 195 de 195 superadas | Sabotajes a mano: sin autoguardado, toque que no selecciona, botón que no construye y ausencia no aplicada al volver, detectados por aserción; quitar el tope de 30 pasos por fotograma lo detecta el límite de tiempo (la prueba se queda calculando). Capturas a 1080×2400 revisadas a ojo; defectos encontrados y corregidos: nombres cortados, provincias solapadas, avisos ámbar en todo el mapa, cantidad redondeada a cero. Pendiente de CI y del móvil |
| 2026-10-21 | Ejecución #17 (commit d4ec0b0): APK sin comprimir (D-019) | Verde; `version/code` 24; firma idéntica; el artefacto se llama `reinos-tycoon-debug.apk` según la API | **No descargado ni instalado en el móvil todavía** (no consta qué ejecución instaló el usuario; ver la fila siguiente) |
| 2026-10-21 | Tarea 1.10 [PC] en local (Godot 4.7.2): `test_closure.gd` (5 pruebas), 2 de guardado en crisis y 1 de tope de edificios en interfaz, 1 de construcción y 1 de reglas | **210 de 210** en local (≈ 80 s). Sabotajes (copias del proyecto con un fallo puesto a propósito): guardado que olvida el descontento → falla (2 pruebas de guardado y 2 comprobaciones del cierre); guardado que olvida los pasos de hambre → falla (3); guardado que olvida los efectos activos → falla (9 pruebas); ausencia con un paso de menos → falla (11); tope con `>` en vez de `>=` → falla (1); ajuste de ratón desde toque desactivado → falla (1) | **Hallazgos**: (1) sin tope de edificios la simulación se hacía cada vez más lenta (D-020); (2) las pruebas de guardado existentes no detectaban un campo olvidado si valía cero (descontento, hambre): el primer sabotaje pasó sin fallos hasta añadir `_crisis_world` y comparar también los campos leídos directamente. La ejecución en GitHub Actions se anota en la fila siguiente |
| 2026-10-21 | Ejecución #18 de CI (commit d240f69): cierre 1.10 [PC] y D-020 | **Verde: 210 de 210**; APK `reinos-tycoon-debug.apk` con `version/code` 28 y la misma firma (`f3e6ecc4…48d5`) | APK sin instalar todavía en el móvil. Misma salida que en local en las trazas de las pruebas largas |
| 2026-10-21 | Ejecución #19 de CI (commit 9bca458): mapa histórico, guardados de otro mapa, versión 0.0.5 | **Verde: 213 de 213**; APK `reinos-tycoon-debug.apk` con `version/code` 31 y la misma firma (`f3e6ecc4…48d5`). Sabotaje: sin la comprobación de mapa fallan las pruebas de sesión | APK sin instalar todavía. Antes de instalarlo, el móvil tenía una partida del mapa de prueba (captura del usuario, día 143): con este APK se aparta como `partida.json.mapa-anterior-…` y empieza una nueva con aviso. **Ese aviso no se ha visto en el móvil** |
| 2026-10-21 | Respuesta del usuario sobre A11 (Redmi Note 13 5G, versión 0.0.5 o anterior: no consta) | **A11 confirmado por el usuario**: «Sí, se puede» seleccionar provincias con el dedo y ver su ficha | Confirmación breve, sin detalle (no dijo cuántos toques fallaron). Sigue **sin confirmar** de la lista: 3 (desplazar la ficha), 4 (construir en el móvil), 6 (cerrar y reabrir con «Mientras estabas fuera»), 8 (buscar actualización), 9 (permisos) y el aviso de «partida de otro mapa». Punto 5 apoyado por la captura del día 143 a ×600. **Opinión del usuario sobre el aspecto: «no me gusta cómo se ve… todo en general»**, con una imagen de referencia que no llegó; es una petición de rediseño, no un fallo de A11 |
| 2026-10-21 | Captura del usuario en el Redmi Note 13 5G (versión 0.0.4; ejecución del APK no identificada): menú «Medir velocidad» (A12) | **Registrado (A12)**: 600 pasos de 5 provincias en 393 ms ≈ **0,65 ms por paso** en el móvil (≈ el doble que los 0,3 ms medidos en el entorno del asistente). En la captura se ve además la app abierta en vertical sin recortes, la velocidad ×600 marcada y «Día 17, 23:00» | Una sola medición, con 5 provincias y partida casi nueva. Sin ver todavía: toque en provincias (A11), construir, resumen al volver, buscar actualización, permisos. En la captura el cuadro de diálogo tapa parte del mapa (provincia D): cosmético |
| 2026-10-21 | Ejecuciones #14 (commit 43d23e0), #15 (4e9bef6) y #16 (9ecd143) de CI | **Verdes**: 195, 200 y 200 de 200; APK con `version/code` 19, 21 y 22 | Interfaz, medir velocidad, buscar actualización e icono. La firma del APK es la misma en todas (SHA-256 `f3e6ecc4…48d5`). En #16 desaparece el aviso «No project icon specified». APK final: artefacto `reinos-tycoon-debug-apk` de la ejecución #16 (28 MB). **No instalado ni visto todavía en el móvil** |
