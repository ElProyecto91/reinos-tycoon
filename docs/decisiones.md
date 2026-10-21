# Decisiones y contradicciones abiertas

Formato según la regla 15 del documento maestro: problema, solución más sencilla y segura, estado.

## D-001. El documento maestro está cortado

- Problema: el texto recibido termina en la sección 13 ("Debe existir una vista que muestre: - Exist"). Faltan el resto de la logística, comercio, tecnología, diplomacia, guerra, fases, MVP y criterios de aceptación.
- Propuesta: no inventar fases. Pedir el texto restante antes de planificar más allá de la base.
- Estado: **pendiente del usuario**.

## D-002. "Coste obligatorio 0 €" frente a publicar en Google Play

- Problema: publicar en Google Play exige una cuota de registro de desarrollador (pago único, 25 USD). Contradice la regla 3.
- Propuesta: distribuir como APK por instalación directa (gratis). Tratar Google Play como opcional y fuera del coste obligatorio.
- Estado: **pendiente de confirmar**.

## D-003. No se puede verificar nada en el entorno actual

- Problema: Godot no está instalado en el entorno de trabajo del asistente, y no hay repositorio previo. Las reglas 12 y 13 exigen versiones ejecutables y probadas.
- Propuesta: hasta tener Godot disponible, todo código se marca como "sin probar". Opciones para probar de verdad: instalar Godot en un ordenador del usuario, o automatizar pruebas y exportación con GitHub Actions (gratis en repositorios públicos).
- Estado: **pendiente de decidir** según el equipo que tenga el usuario.

## D-004. Los datos deben vivir dentro del proyecto de Godot

- Problema: la regla 7 pide separar datos históricos de la lógica, pero Godot solo empaqueta en el juego los recursos dentro de la carpeta del proyecto (`res://`).
- Propuesta: separar por carpetas dentro del proyecto (`game/data/` frente a `game/scripts/`), no por repositorios ni carpetas externas.
- Estado: **adoptada como norma provisional**.

## D-005. Región y fecha del MVP

- Problema: el MVP (10–20 provincias, 8–12 mercancías) necesita una región concreta, y de ella depende toda la investigación histórica.
- Propuesta: elegir una sola región pequeña y bien documentada para el año 1000. No empezar por Eurasia completa.
- Estado: **pendiente del usuario**.
