# Reinos Tycoon

Juego de estrategia, economía y gestión territorial con progreso idle, ambientado hacia el año 1000 d. C.

- Motor previsto: Godot 4 (GDScript). Versión candidata: 4.7.2-stable, sin confirmar (ver `docs/decisiones.md`, D-006)
- Plataforma prioritaria: Android
- Coste obligatorio de desarrollo, ejecución y juego: 0 €
- Debe funcionar sin conexión a Internet

## Estado actual

**v0.0.2: solo documentación y plan.** Todavía no existe el proyecto de Godot ni código. Nada se ha ejecutado ni probado.

## Independencia

Este proyecto es independiente del juego "Reinos". No comparte código, archivos ni recursos con él, y nada de aquí debe copiarse hacia o desde ese repositorio sin autorización expresa.

## Estructura

| Ruta | Contenido |
|---|---|
| `docs/` | Documento maestro, plan, decisiones |
| `docs/fuente/` | Original `.docx` del documento maestro |
| `game/` | Proyecto de Godot (pendiente de crear). Los datos históricos irán en `game/data/`, separados de la lógica |

## Documentos

- `docs/00-documento-maestro.md`: especificación completa (40 secciones).
- `docs/ROADMAP.md`: tareas por dependencia y prioridad, y qué se prueba sin Android.
- `docs/decisiones.md`: contradicciones, huecos y decisiones pendientes.
- `CHANGELOG.md`: historial de versiones.

El resto de documentos de la sección 31 se crearán cuando tengan contenido real.
