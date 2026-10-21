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

- Comprobado el 2026-10-21: Godot no está instalado; la descarga desde GitHub Releases devuelve 403 desde el proxy del entorno; no existe paquete de Godot en PyPI.
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
- Sin verificar: requisitos actuales de Android (JDK, SDK, build-tools, plantillas de exportación). La página de documentación que se pudo leer parecía una copia antigua (citaba OpenJDK 17), así que no se fija ningún requisito hasta confirmarlo en la documentación oficial vigente.
- Estado: **pendiente de confirmar en la tarea 0.2 del ROADMAP**.

## Orden de entregas

La sección 40 pedía empezar por las entregas A, B y C. Este repositorio nació con la D (archivos iniciales) porque el primer texto llegó cortado. Los archivos de la D son mínimos y reversibles; no condicionan el plan.
