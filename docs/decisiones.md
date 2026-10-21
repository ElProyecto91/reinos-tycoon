# Decisiones y contradicciones

Formato según la regla 15 del documento maestro: problema, propuesta más sencilla y segura, estado.

## D-001. Documento maestro cortado

- Problema: el primer texto recibido terminaba a mitad de la sección 13.
- Resolución: se recibió el `.docx` completo (40 secciones, más anexo y checklist). Ahora `docs/00-documento-maestro.md` es la versión completa y el original está en `docs/fuente/`.
- Estado: **resuelta (2026-10-21)**.

## D-002. "0 €" frente a Google Play

- Estado: **retirada. Fue un error de lectura del asistente.**
- Motivo: la sección 26 ya separa desarrollo, exportación APK, distribución directa y tienda, y manda comprobar las tasas vigentes antes de recomendar canales. No hay contradicción.
- Nota práctica: el objetivo es generar y probar APK sin pagar. Si algún día se publica en una tienda, comprobar entonces las tasas vigentes.

## D-003. Godot no está disponible en el entorno del asistente

- Comprobado el 2026-10-21: Godot no está instalado; la descarga desde GitHub Releases y desde el servidor oficial (downloads.godotengine.org) devuelve 403 desde el proxy del entorno.
- Corrección: una versión anterior de esta nota decía que no existe paquete de Godot en PyPI. Esa comprobación no valía: pip no puede llegar a PyPI desde este entorno (el nombre pypi.org no se resuelve). Por la misma razón no se pueden instalar herramientas de Python, y el GDScript no tiene ni análisis de sintaxis automático aquí.
- Consecuencia: el asistente puede escribir y revisar archivos, pero no ejecutar el juego, ni sus pruebas, ni exportar APK. Todo código irá marcado "sin probar" hasta que se ejecute en un entorno real (sección 29: no marcar una prueba como superada si no se ejecutó).
- Opciones: (a) instalar Godot en un ordenador del usuario; (b) pruebas y exportación con GitHub Actions. La opción (b) no está verificada y requiere configuración.
- Decisión (2026-10-21): el usuario no tiene ordenador y necesita Android, así que se usa la opción (b), GitHub Actions. Sin verificar: que el flujo funcione y que siga siendo gratuito en repositorios públicos (comprobar condiciones vigentes).
- Estado: **decidida, sin verificar en la práctica**.

## D-004. Datos dentro del proyecto de Godot

- Problema: la regla 7 pide datos separados de la lógica, pero Godot solo empaqueta recursos dentro de la carpeta del proyecto (`res://`).
- Propuesta: separar por carpetas dentro del proyecto (`game/data/` frente a `game/scripts/`).
- Estado: **norma provisional**.

## D-005. Región y fecha del MVP

- Problema: el MVP (10–20 provincias, 2–3 poderes, 8–12 mercancías) necesita una región concreta; de ella depende toda la investigación histórica de la sección 32.
- Propuesta: una sola región pequeña y bien documentada, fecha de referencia 1000.
- Estado: **pendiente del usuario**.

## D-006. Versión de Godot

- Dato: el archivo oficial de descargas (consultado el 2026-10-21) lista 4.7.2-stable, del 18/08/2026, como la última estable. 4.8 solo aparece en beta (beta1, 15/10/2026).
- Propuesta: candidata 4.7.2-stable; no usar la beta.
- Resultado de la tarea 0.2 (2026-10-21): versión elegida, 4.7.2-stable. El resumen visible de la documentación oficial de exportación a Android (versión estable) indica OpenJDK 17. Un resumen de terceros de esa documentación (DeepWiki, sin versión de Godot indicada) menciona SDK Platform 35, Build-Tools 35.0.1, Platform-Tools 35.0.0 o posterior y Command-line Tools "latest". No se pudo leer la página oficial completa (el lector la devolvía truncada), así que esos números son orientativos y no están contrastados con la 4.7.2.
- Estado: **hecha con salvedades; la comprobación real es la primera ejecución del flujo (D-007)**.

## D-007. Imagen de contenedor para compilar

- Decisión: el flujo usa `barichello/godot-ci:4.7.2`, una imagen comunitaria con Godot, plantillas, SDK de Android y JDK, en lugar de instalarlo todo a mano.
- Motivo: desde aquí no se pueden verificar las URL de descarga de Godot ni las versiones exactas del SDK. La etiqueta existe en Docker Hub (vista el 2026-10-21, subida hace unos 2 meses).
- Riesgos: es un tercero y la etiqueta es mutable; límites de descarga anónima de Docker Hub; las rutas internas (`/root/.config/godot`, `/root/.local/share/godot/export_templates`, `/root/debug.keystore`) y las variables `GODOT_ANDROID_KEYSTORE_DEBUG_*` se dan por buenas según lo que se recuerda de su documentación, sin comprobar. El flujo imprime un diagnóstico para verlo en la primera ejecución.
- La firma de depuración es la de la imagen. Si cambia, instalar una versión nueva sobre la anterior puede fallar y habrá que desinstalar antes.
- Estado: **el flujo salió en verde en la primera ejecución (2026-10-21, #1)**. Los supuestos sobre rutas internas quedan confirmados en la práctica solo si el APK instala y abre en un móvil; el registro del paso de diagnóstico no se ha revisado. Más adelante, fijar la imagen por huella (digest).

## D-008. `export_presets.cfg` dentro del repositorio

- Problema: la versión 0.0.1 lo excluía en `.gitignore`, pero la compilación en la nube lo necesita.
- Decisión: se versiona. No contiene secretos: la firma de depuración va por variables de entorno y la de publicación irá por secretos de GitHub (fase 9, con una clave propia de Reinos Tycoon, nunca la de Reinos).
- Estado: **adoptada**.

## D-009. Convención provisional de código

- Identificadores en inglés, como la API de Godot. Comentarios, mensajes y documentación en español. Sangría con tabuladores.
- Estado: **provisional**; se fijará en `ARCHITECTURE.md` al empezar la fase 1.

## D-010. Ajustes de arranque

- Renderizador Compatibility (juego 2D, mejor compatibilidad con móviles modestos); orientación según el sensor, sin forzar (sección 23); solo arquitectura arm64-v8a; permiso de Internet desactivado; `version/code` a mano, la versión visible sale de `application/config/version`.
- ID de paquete `io.github.elproyecto91.reinostycoon`, pensado para no coincidir con el de Reinos. No se ha consultado el ID de Reinos.
- Estado: **provisional**; medir rendimiento en la fase 9.

## Orden de entregas

La sección 40 pedía empezar por las entregas A, B y C. Este repositorio nació con la D (archivos iniciales) porque el primer texto llegó cortado. Los archivos de la D son mínimos y reversibles; no condicionan el plan.
