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

Desde la fase 1 hay además pruebas de reglas del juego, una por comportamiento, en: `test_game_data.gd` (datos y reglas), `test_store.gd` (almacén y conservación), `test_population.gd`, `test_production.gd`, `test_construction.gd`, `test_scarcity.gd` (A6/A7, crisis y recuperación), `test_long_run.gd` (A1: 10 000 pasos; A10: 30 días; determinismo) y `test_save.gd` (A8: ida y vuelta, archivo truncado, suma de control alterada, versión nueva, escritura interrumpida, copia `.bak`) `test_update_check.gd` (aviso de versión nueva, D-015) y `test_offline.gd` (A9, D-016). Total actual: 161 pruebas.

Cómo se comprobó que no pasan por vacío: se desactivó a propósito la comprobación de la suma de control en una copia y `test_tampered_content_is_detected_by_the_checksum` falló; el autotest (`-- --selftest-fail`) devuelve código 1. Esa comprobación se hizo una vez, a mano; no está automatizada.

## Comprobaciones manuales en móvil (tarea 0.7)

Estado: los puntos 1 a 3 se comprobaron con una captura del usuario (2026-10-21, pantalla en vertical, Redmi Note 13 5G). Los puntos 4 a 6 siguen sin ejecutar.

1. Descargar y descomprimir el artefacto del flujo; instalar el APK.
2. La app abre y no se cierra sola.
3. Se ve centrado el texto "Reinos Tycoon / v0.0.3 (fase 0) / Arranque correcto".
4. Al girar el móvil el texto sigue centrado.
5. Cerrar la app y volver a abrirla funciona.
6. La app no pide ningún permiso (Ajustes del sistema, Apps, Reinos Tycoon, Permisos).

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
