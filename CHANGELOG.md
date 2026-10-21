# Historial de versiones

## Sin versionar (2026-10-21, fase 1 en curso)

- Fase 1, tareas 1.1 a 1.7: datos validados, almacén con conservación, población, producción, obras, hambre gradual, guardado con versión de formato y suma de control. Cantidades enteras en milésimas (D-012); reglas de la simulación (D-013).
- D-014: el descontento ralentiza el trabajo en vez de recortar lo producido, y la población come antes de producir. Motivo: la provincia no se recuperaba de una mala cosecha.
- El APK se numera con el recuento de commits (`version/code`) para que un APK nuevo pueda instalarse sobre el anterior. Escrito en el flujo, **todavía no ejecutado** (el trabajo `apk` se omite si fallan las pruebas).
- Ejecución #10 de GitHub Actions: pruebas 140 de 140 y APK generado (`version/code` 13), firmado con la clave de depuración de la imagen de Docker; la imagen se fija por digest.
- Progreso offline (A9, D-016): `scripts/sim/offline.gd`, reglas `step_seconds` y `offline_limit_seconds`, hora del guardado en el sobre.
- Aviso de versión nueva sin red (D-015): `scripts/update/update_check.gd`.
- Mapa de ejemplo de 5 provincias con validación y selección táctil (1.8, D-017): `scripts/sim/game_map.gd`, `data/map.json`.
- Sesión de juego sin pantalla (`game_session.gd`): arranque, guardado con hora, reanudación, archivos dañados apartados sin borrarse.
- Interfaz táctil en vertical (1.9, D-018): mapa con selección por toque, ficha de provincia, construcción, velocidad, autoguardado y resumen al volver. Versión del proyecto 0.0.4. `tools/captura_ui.gd` para capturas.
- Menú: «Medir velocidad» (A12) y «Buscar actualización» (D-015; activa el permiso de Internet, solo se usa al pulsar el botón).
- Icono propio provisional.
- Estado de las pruebas: 200 de 200 en GitHub Actions (ejecución #16). APK de esa ejecución sin instalar todavía en un móvil.
- Tarea 1.10 [PC]: `tests/test_closure.gd` (2 años de juego con las 5 provincias, guardado y carga cada 97 pasos con resultado idéntico, 40 cierres y reaperturas con ausencias raras, un año a ×600 por la pantalla real). Hallazgo y cambio: tope de edificios por provincia, regla `max_buildings` = 30 provisional (D-020). Pruebas de guardado en plena crisis (antes un campo olvidado con valor cero pasaba sin que ninguna prueba fallase). 210 de 210 en GitHub Actions (ejecución #18, APK `version/code` 28).
- Versión 0.0.5 (D-021, D-024): investigación de la región con fuentes (`docs/HISTORICAL_SOURCES.md`, `docs/REGION_IBERIA_1000.md`) y mapa con provincias históricas (Toledo, Zaragoza, Castilla, Córdoba, León) en lugar de las de prueba. Un guardado de otro mapa se aparta sin borrarlo y se empieza una partida nueva. 213 pruebas en local; falta confirmar en GitHub Actions.
- D-019: el APK se sube como artefacto sin comprimir (`upload-artifact@v7`, `archive: false`) para descargarlo como `.apk` y no como zip. Escrito en el flujo, **todavía no ejecutado**.
- Maqueta de vista 3D (D-025): `game/scripts/view/diorama.gd` (diorama de casillas hexagonales definido por dos capas de texto, validado antes de construir) con 118 modelos CC0 de KayKit en `game/assets/kaykit/models/` (licencia en `THIRD_PARTY_LICENSES.md`), `tools/captura_diorama.gd` y `tools/recolor_paleta.py`. **Todavía no está conectada a la pantalla del juego**: el APK no la muestra. 8 pruebas nuevas (`tests/test_diorama.gd`, 221 en local); el flujo de CI importa los recursos antes de las pruebas. Ejecución #20 en GitHub Actions: 221 de 221 y APK de 32,9 MB (antes 28,4 MB), misma firma.
- Maqueta 3D, segunda versión (V1b, a petición del usuario: «más real, igual a la imagen o mejor»): suelo en capa fina de césped sobre pilares de roca (acantilados), río, caminos y orillas elegidos solos según los vecinos, muralla en anillo con esquinas, torres y puerta de cara hacia fuera, molino de agua, lago con nenúfares, puesto de mercancías, cielo con luz cálida, sombras y nubes (`scripts/view/stage.gd`). El diseño se escribe por coordenadas axiales (`layers_from_cells`) y se valida. 231 pruebas en local y en GitHub Actions (ejecución #21; APK de 32,7 MB); 9 sabotajes nuevos detectados. Sigue **sin estar conectada** a la pantalla del juego.
- Aspecto de época (V1c, D-026): edificios, murallas, puente, campos y bosques generados por código para la Península hacia el año 1000, con fuentes H-17 a H-27 (`docs/HISTORICAL_SOURCES.md`, `docs/REGION_IBERIA_1000.md`); paletas seca y norte; luz cálida y suelo continuo.
- **Vista 3D conectada al juego** (V2, D-026): la pantalla principal muestra el paisaje de la provincia elegida con lo construido (casas según población y viviendas, granjas, molinos, panaderías, graneros, aserraderos, obras en curso como andamios); botón «Mapa»/«Provincia» para alternar con el mapa 2D; colores de interfaz cálidos. Hallazgo de una prueba: al pulsar «Construir» el andamio no aparecía hasta que pasaba el tiempo; corregido. El ejecutor de pruebas espera un fotograma antes de empezar (las pruebas de pantalla necesitan el árbol en marcha). Rendimiento en el móvil **sin medir**.
- Versión 0.0.6: menú con interruptores «Vista 3D» y «Sombras de la vista 3D» (guardados en `user://ajustes.json`, aparte de la partida), por si el 3D va mal en el móvil. 265 pruebas en local; sabotajes S19 a S30 de la vista 3D detectados (12 de 12). Castillos y fortalezas: solo registro de fuentes (H-32 a H-38); **ninguno dibujado**; «todo lo existente» no se puede hacer sin inventar (ver D-026). Ejecución #22 en GitHub Actions: 266 de 266 y APK de 32,8 MB (`version/code` 38), misma firma.
- Versión 0.0.7 (V3a, a petición del usuario: «está vacío y quieto… quiero que se muestren aldeanos»): aldeanos que caminan por rutas de ida y vuelta (puente, calzada, campos, molino), obreros golpeando en cada obra, gente en el mercado y humo en los hornos (`scripts/view/epoca_gente.gd`; qué se ve lo decide `provincia_layout.gd`). Las figuras van exageradas de tamaño para verse en un móvil. La escena se redibuja a 15 fotogramas por segundo mientras haya gente en movimiento (antes, solo al cambiar algo): gasta más batería; interruptor «Gente en movimiento» en el menú. Rendimiento en el móvil **sin medir**. 276 pruebas en local.

## v0.0.3 (2026-10-21)

- Fase 0: proyecto de Godot mínimo en `game/`, ejecutor de pruebas nativo con una prueba de humo y un autotest de fallo, preset de exportación a Android y flujo de GitHub Actions (pruebas y APK de depuración).
- Nuevos documentos: `TEST_PLAN.md`, `FREE_OPERATION.md` y `THIRD_PARTY_LICENSES.md`. `ROADMAP.md` y `decisiones.md` actualizados (D-003 corregida; nuevas D-007 a D-010).
- `export_presets.cfg` deja de ignorarse.
- Primera ejecución del flujo en GitHub (#1, 2026-10-21): en verde. Registros sin revisar; el APK se instaló y abrió en un móvil real (captura del usuario). Antes de subirlo solo se había comprobado que el YAML es válido; el GDScript no tiene análisis de sintaxis automático.

## v0.0.2 (2026-10-21)

- Sustituida la copia cortada del documento maestro por la versión completa; original `.docx` guardado en `docs/fuente/`.
- Añadido `docs/ROADMAP.md` con el plan inicial.
- `docs/decisiones.md`: D-001 resuelta, D-002 retirada por error de lectura, añadidas D-003 (entorno) y D-006 (versión de Godot).
- Sin código. Sin proyecto de Godot. Nada ejecutado ni probado.

## v0.0.1 (2026-10-21)

- Estructura inicial del repositorio: `docs/` y `game/`.
- Copia del documento maestro (cortada en la sección 13).
- Registro de decisiones pendientes.
- Sin código. Sin proyecto de Godot. Nada ejecutado ni probado.
