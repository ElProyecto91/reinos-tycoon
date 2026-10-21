# Plan de pruebas

Regla (sección 29): ninguna prueba se marca como superada si no se ha ejecutado. **A fecha de hoy no se ha ejecutado ninguna.**

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
| test_basic_arithmetic | test_smoke.gd | que el ejecutor corre una prueba trivial | sin ejecutar |
| test_project_version_defined | test_smoke.gd | que `project.godot` define la versión | sin ejecutar |
| test_intentional_failure | selftest_fail.gd | que el ejecutor devuelve código distinto de 0 ante un fallo (el flujo lo exige) | sin ejecutar |

Ninguna prueba cubre todavía reglas del juego: no hay reglas implementadas.

## Comprobaciones manuales en móvil (tarea 0.7)

Todas sin ejecutar.

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
| (aún no hay ejecuciones) | | | |
