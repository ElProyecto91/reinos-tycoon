# Reinos Tycoon

Juego de estrategia, economía y gestión territorial con progreso idle, ambientado hacia el año 1000 d. C.

- Motor: Godot 4.7.2-stable con GDScript (ver `docs/decisiones.md`, D-006)
- Plataforma prioritaria: Android
- Coste obligatorio de desarrollo, ejecución y juego: 0 €
- Debe funcionar sin conexión a Internet

## Estado actual

**v0.0.3: fase 0.** Hay un proyecto de Godot mínimo (una pantalla de arranque), un ejecutor de pruebas y un flujo de GitHub Actions que prueba y exporta un APK de depuración. Todavía no hay juego. El flujo salió en verde en su primera ejecución (2026-10-21) y el APK se instaló y abrió en un móvil real.

## Independencia

Este proyecto es independiente del juego "Reinos". No comparte código, archivos ni recursos con él, y nada de aquí debe copiarse hacia o desde ese repositorio sin autorización expresa.

## Estructura

| Ruta | Contenido |
|---|---|
| `docs/` | Documento maestro, plan, decisiones |
| `docs/fuente/` | Original `.docx` del documento maestro |
| `game/` | Proyecto de Godot. Los datos históricos irán en `game/data/`, separados de la lógica |
| `.github/workflows/` | Flujo de GitHub Actions: pruebas y APK de depuración |
| rama `ci-results` | La escribe solo el flujo con el resultado de la última ejecución. No editar |

## Documentos

- `docs/00-documento-maestro.md`: especificación completa (40 secciones).
- `docs/ROADMAP.md`: tareas por dependencia y prioridad, y qué se prueba sin Android.
- `docs/decisiones.md`: contradicciones, huecos y decisiones pendientes.
- `docs/MVP_PROTOTYPE.md`: borrador del prototipo y sus criterios de aceptación (pendiente de aprobación).
- `docs/TEST_PLAN.md`: cómo ejecutar las pruebas y qué comprobar a mano en el móvil.
- `docs/FREE_OPERATION.md`: herramientas, licencias y costes.
- `THIRD_PARTY_LICENSES.md`: licencias de terceros.
- `CHANGELOG.md`: historial de versiones.

El resto de documentos de la sección 31 se crearán cuando tengan contenido real.

## Obtener el APK de depuración (sin ordenador)

1. En GitHub, pestaña Actions, abre la última ejecución en verde de "Pruebas y APK de depuración".
2. Abajo, en Artifacts, descarga `reinos-tycoon-debug.apk`. Desde la ejecución posterior a la #16 el APK se sube **sin comprimir** (D-019): se descarga ya como `.apk`, sin zip. (Los artefactos de la #16 y anteriores sí son un zip.)
3. Abre el `.apk` descargado. Android pedirá permitir instalar apps desconocidas desde esa aplicación.
4. Si al actualizar dice "app no instalada", desinstala antes la versión anterior (la firma de depuración puede cambiar).

Es un APK de depuración, solo para pruebas: no sirve para publicar. El primero lo generó la ejecución #1 del flujo y se probó en un móvil real.
