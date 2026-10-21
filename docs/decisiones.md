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
- Estado: **borrador de propuesta (Iberia hacia el año 1000) en `docs/MVP_PROTOTYPE.md`; pendiente de aprobación del usuario**.

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
- Estado: **confirmada en la práctica**: el flujo salió en verde (2026-10-21, #1) y el APK exportado se instaló y abrió en un móvil real. El registro del paso de diagnóstico no se ha revisado. Más adelante, fijar la imagen por huella (digest).

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

## D-011. Informe de CI en la rama `ci-results`

- Problema: el asistente no puede leer la pestaña Actions (el token de `gh` del entorno es inválido), así que cada fallo exigía capturas del usuario.
- Decisión: el flujo guarda sus registros como artefactos y un último trabajo publica un resumen y los registros en la rama `ci-results` (una sola confirmación, sobrescrita en cada ejecución). El asistente la lee con `git fetch`. Esa rama la escribe solo el flujo.
- Riesgos: el trabajo usa permiso de escritura sobre el repositorio (solo ese trabajo); los registros son públicos si el repositorio lo es. No hay secretos en los registros.
- Estado: **verificada el 2026-10-21 con la ejecución #4 (commit 730010a)**: la rama `ci-results` se creó, contiene `RESUMEN.txt` y los registros, y se leen desde aquí con `git fetch origin ci-results`.
- Lo que ese registro confirmó de D-006 y D-007: Godot 4.7.2.stable.official en la imagen; plantillas `4.7.2.stable`; JDK 17.0.19; SDK en `/usr/lib/android-sdk`; clave de depuración en `/root/debug.keystore`; las rutas y variables supuestas eran correctas. Dato nuevo: Godot no encontró Build-Tools que coincidieran con el SDK objetivo y firmó con **33.0.2**, no con 35.0.1; el APK salió firmado y pesa unos 28 MB. Aviso inocuo en todas las ejecuciones: falta `libfontconfig.so.1` (no afecta al modo sin ventana).
- Prueba de que el ejecutor detecta fallos (con `--selftest-fail`): 3 pruebas, 1 fallo, código de salida 1.

## D-012. Cantidades enteras en milésimas

- Decisión: toda cantidad de la simulación (existencias, costes, producción, consumo, capacidad) es un entero en milésimas de unidad: 1000 = 1 unidad. Los tiempos son enteros en pasos de simulación. No se usan decimales (`float`) en la economía.
- Motivo: con decimales, la conservación (existencias finales = iniciales + producción + importaciones - consumo - exportaciones - pérdidas) solo se cumpliría "más o menos" y el criterio A1 no se podría comprobar de forma exacta. Con enteros se comprueba con igualdad.
- Consecuencias conocidas: (1) JSON entrega todos los números como decimales (`1000` llega como `1000.0`); el cargador los acepta solo si son enteros exactos y los convierte a `int`. Lo mismo habrá que hacer al leer partidas guardadas (tarea 1.7). (2) La interfaz tendrá que dividir entre 1000 para mostrar. (3) Un `int` de Godot es de 64 bits: no hay riesgo de desbordamiento con estas magnitudes.
- Estado: **adoptada; verificada por las pruebas de las tareas 1.1 y 1.2 cuando pasen en CI**.

## D-013. Reglas de la simulación de la fase 1

- Un paso de simulación equivale a una hora de juego; un día son 24 pasos y los "30 días" del criterio A10 son 720 pasos. Es una convención de pruebas, no una decisión de ritmo real: cuántos segundos reales dura un paso se decidirá con el progreso offline y la medición en el móvil (A9, A12).
- Cada mercancía física puede ocupar como mucho una parte de la capacidad (`storage_share_percent` en `goods.json`), y la suma de las partes no puede pasar de 100. Motivo: sin ese tope, una mercancía que sobra (madera, harina) llena el almacén, los productores de alimento se bloquean y la provincia muere de hambre con el almacén lleno. Pasó en el diseño sobre el papel antes de escribir una línea.
- Cuando el resultado no cabe: si no cabe **ninguno** de los productos, el ciclo espera con el trabajo hecho y el edificio muestra `storage_full`. Si caben unos y otros no (un leñador con la madera al tope sigue entregando leña), lo que no cabe **se desperdicia** y se anota en `wasted` con un aviso, para que un subproducto sobrante no bloquee el principal. Los insumos se gastan al empezar el ciclo y solo si algún resultado cabría. Corrección: la primera versión de esta decisión decía que la producción nunca se pierde; la prueba larga (10 000 pasos) mostró que eso hacía que la madera sobrante bloqueara la leña y, con ella, el pan.
- Hambre: primero aviso (3 pasos), después descontento que sube según la falta de alimento, y solo tras 24 pasos seguidos de hambre se pierde población (2 % por paso, mínimo 1, sin bajar de 10). El descontento ralentiza el trabajo (ver D-014) y baja 15 por paso cuando hay comida. No hay azar.
- Los números (raciones, impuestos, costes, ciclos) son provisionales y se ajustarán con partidas reales; ninguno es un dato histórico.
- Estado: **provisional**; el comportamiento queda cubierto por las pruebas, el equilibrio no.

## D-014. El descontento ralentiza el trabajo y la gente come antes de que se produzca

- Qué pasó: la prueba de crisis (A7: una mala cosecha provoca escasez y la provincia se recupera) falló en la ejecución #9 de CI. Con la regla anterior el descontento recortaba la cantidad producida en cada ciclo; en una cadena trigo → harina → pan el recorte se multiplica en cada eslabón (30 % × 30 % × 30 %), el pan no alcanzaba para dejar de pasar hambre y la provincia se quedaba en descontento ≈ 900–1000 sin salir (observado en el rastro, hasta el paso 800).
- Cambio 1: el descontento ya no reduce lo producido sino la **velocidad**: el progreso de un ciclo avanza en centésimas de paso y cada paso suma la productividad (100 sin descontento; mínimo `min_productivity_percent`, ahora 50). Un ciclo tarda más, pero no se desperdician insumos.
- Cambio 2: en el orden del paso, la población come **antes** de las obras y de la producción, de modo que un molino no se lleva el trigo que la gente iba a comer ese mismo paso.
- Resultado medido (Godot 4.7.2, en el entorno del asistente, no todavía en CI): con las mismas pruebas de crisis, hambre máxima 50 pasos, descontento máximo 1000, población mínima 72, recuperación completa en el paso 172 con población final 100. Las 140 pruebas pasan.
- Lo que NO está probado: que 50 % y 172 pasos sean un buen equilibrio de juego. Son valores provisionales; la prueba solo exige que la provincia se pueda recuperar. Se probó una sola mala cosecha (trigo a 0 durante 40 pasos); otras crisis más largas pueden no ser recuperables y eso es una decisión de diseño pendiente.
- Estado: **provisional**.

## D-015. Actualización del juego: avisar y descargar, no instalar en silencio

- Petición del usuario: que el juego sea autoactualizable.
- Límite técnico [Probable, conocimiento de Android; no se ha probado en el móvil del usuario]: fuera de Google Play, una app no puede reemplazarse a sí misma sin que el usuario confirme la instalación, y para instalar un APK descargado necesita el permiso «instalar apps desconocidas». Google Play no se usa (coste 0 €, D-001/FREE_OPERATION).
- Decisión: el juego **avisa** cuando hay una versión nueva y abre la página de descarga del repositorio; el usuario descarga el APK y Android pide confirmar. Sin instalación automática.
- Fuente de las versiones: las *releases* de GitHub del repositorio (`releases/latest`, que ignora borradores y versiones de prueba). Formato verificado en la documentación de GitHub; el repositorio aún no tiene ninguna release, así que **la consulta real nunca se ha ejecutado**.
- Hecho y probado (en local): `scripts/update/update_check.gd` interpreta la respuesta, compara versiones numéricamente y solo acepta direcciones del propio repositorio (7 pruebas en `test_update_check.gd`; una de ellas cazó un error real en la comparación de versiones).
- Hecho (2026-10-21): permiso `INTERNET` activado en `export_presets.cfg` y botón **Menú → Buscar actualización** conectado (solo consulta al pulsarlo, nunca sola; 10 s de tiempo máximo; cancelable; sin conexión avisa y el juego sigue igual). Probado: toda la lógica de respuestas (200 con versión nueva / al día / basura, 404, 403/429, otros códigos, sin conexión) y la ruta de error real en el entorno del asistente, donde Internet pasa por un proxy. **No probado**: una respuesta real 200 de GitHub dentro del juego; el repositorio aún no tiene ninguna release (la API responde 404), así que en el móvil debería salir «Todavía no hay versiones publicadas».
- Pendiente: (1) —hecho arriba—; (2) clave de firma estable: sin ella Android rechaza instalar un APK sobre otro con otra firma. Observado en la ejecución #10: el APK se firma con la clave de depuración que trae la imagen de Docker (`CN=Android Debug`, SHA-256 `f3e6ecc4…48d5`); para que no cambie, la imagen se fija por su digest en el flujo. Sigue siendo una clave de depuración, pública y sin valor de identidad: sirve para actualizar a mano entre APK de este proyecto, no para publicar en una tienda. No se ha comprobado que el APK de la ejecución #1 (instalado en el móvil) tuviera esa misma firma; (3) la primera release la publica el usuario o se publica con su aprobación expresa (sección 37 del documento maestro): la CI **no** publica sola.
- Consecuencia a conocer: `INTERNET` es un permiso visible al instalar. Se activó junto con el botón que lo usa; la app no hace ninguna otra petición de red.
- Estado: **provisional**.

## D-016. Progreso offline (criterio A9)

- El tiempo ausente se convierte en pasos y se ejecutan los **mismos** pasos de la simulación (no hay una versión aproximada aparte). Prueba: 250 pasos offline dan un estado idéntico a 250 pasos jugados.
- Parámetros provisionales en `rules.json`: `step_seconds` = 60 (un paso por minuto real, es decir, una hora de juego por minuto) y `offline_limit_seconds` = 36 000 (10 h, dentro del 8–12 h de la sección 19). **El valor de 60 s es una suposición**: la duración real del paso se decide tras medir en el móvil (A12).
- Tiempo negativo (reloj atrasado) u hora de guardado desconocida: cero pasos, sin recompensa, y se informa del motivo.
- Tope: la ausencia que pase de 10 h se descarta; no se acumula para después.
- El resto de tiempo que no llega a un paso se conserva en la marca nueva; así repartir una ausencia en varias cargas da exactamente el mismo resultado que una sola, y cargar de nuevo con la misma hora no da pasos.
- La hora del guardado (`saved_at`, segundos Unix) va en el sobre del archivo, fuera del estado de la simulación: la simulación no depende del reloj. El archivo sigue en el formato 1 porque aún no existe ningún guardado real de usuario; un guardado sin hora se lee como «hora desconocida».
- El resumen por provincia (población antes/después, variación de existencias, edificios antes/después, peor hambre y peor descontento durante la ausencia, avisos finales) lo devuelve `Offline.settle`; mostrarlo es tarea de la interfaz (1.9).
- Límites conocidos: no hay eventos, comercio ni automatizaciones que simular offline (todavía no existen). El reloj lo aporta quien llama; leer la hora del móvil y guardarla se conecta en la interfaz. Quien adelante el reloj del móvil gana como máximo 10 h por carga (juego de un jugador, sin servidor).
- Estado: **provisional**.

## D-017. Mapa de ejemplo y selección con el dedo (tarea 1.8)

- `data/map.json` define 5 provincias de **ejemplo** («Provincia de prueba A…E»): nombres, posiciones y vecindades inventados para el prototipo, sin pretensión histórica; la región real (D-005) sigue sin investigarse. El formato admite hasta 20 provincias (límite del MVP).
- Se valida al cargar: ids únicos, posiciones dentro del mapa, vecindad mutua y sin bucles, mapa conexo y estado inicial coherente (edificios y mercancías existentes, población mínima). Un mapa inválido no se carga a medias.
- Selección táctil: cada provincia tiene una zona circular de toque (radio 110 unidades de mapa, de 1000×1600). Se exige que los centros estén al menos a dos radios para que un toque nunca sea ambiguo. Prueba: barrido de toda la cuadrícula del mapa sin ningún punto en dos zonas.
- La partida nueva se crea desde el mapa (`GameMap.new_world`); si una existencia inicial no cabe en el almacén se rechaza con un mensaje, sin devolver un mundo a medias.
- Observado en una simulación de 4 meses de juego (2880 pasos): las 5 provincias de ejemplo se mantienen estables, sin descontento. B, C y E no tienen panadería y comen trigo directamente; es un reparto provisional, no un equilibrio de diseño.
- Estado: **provisional**. El dibujo del mapa y la ficha de provincia son la tarea 1.9.

## D-018. Interfaz táctil del prototipo (tarea 1.9)

- Vertical fijo: base de 720×1280 con estiramiento «expand» (en un móvil 20:9 la pantalla gana altura) y orientación bloqueada en vertical. Antes estaba en horizontal/sensor; el documento de criterios (A11) pide «usable en vertical». Si prefieres poder girarlo, es un cambio de una línea, pero la interfaz actual no está pensada para horizontal.
- Pantalla: barra superior (título, día y hora de juego, menú), cuatro velocidades (Pausa, ×1, ×60, ×600), mapa y ficha desplazable de la provincia elegida (población, trabajo, consumo de alimento, descontento, avisos, existencias, edificios con su estado y lo que falta, obras en curso y botones para construir).
- Botones de al menos 88 px de alto en la base de 720 (≈ 132 px físicos en un móvil de 1080 de ancho, unos 48 dp). Los textos se actualizan en su sitio para que un botón no desaparezca bajo el dedo.
- La zona de toque de cada provincia es mayor que su círculo visible (75 %); se comprobó por cálculo que mide más de 88 px base (prueba), no con un dedo real.
- Avisos: «almacén lleno» y «se desperdicia producción» son **informativos** (se listan en la ficha, no marcan el mapa ni entran en el resumen offline), porque en una economía sana aparecen a las pocas horas y llenaban el mapa de alarmas. Hambruna se marca grave (rojo, «!!») y hambre/descontento/sin trabajadores como atención (ámbar, «!»); no se depende solo del color.
- Velocidad por defecto ×60 (un paso por segundo, para poder ver cosas pasar). **Pregunta de diseño abierta**: el progreso offline cuenta un paso por minuto, así que jugar a ×60 rinde 60 veces más que estar fuera. Hay que decidir el ritmo real tras medir en el móvil (A12).
- Se guarda cada 15 s, al pausar la aplicación y al cerrarla; al volver tras una pausa se aplica la ausencia y se muestra un resumen. Si el guardado no se puede leer, se aparta con otro nombre (no se borra) y se empieza una partida nueva avisando.
- Cantidades mostradas exactas (milésimas sin ceros sobrantes). En el resumen offline resulta algo ruidoso («Moneda +123,656»); pendiente de pulir.
- Menú → «Medir velocidad» (criterio A12): simula 600 pasos de una partida aparte y muestra los milisegundos por paso en ese dispositivo; no toca la partida en curso. En el entorno del asistente (no un móvil) salió ≈ 0,3 ms por paso con 5 provincias: es una referencia del PC, **no** el dato del móvil. El valor del móvil lo tiene que dar la propia app. **Medido en el Redmi Note 13 5G (captura del usuario, 2026-10-21): 600 pasos en 393 ms ≈ 0,65 ms por paso**, con 5 provincias y partida casi nueva. Extrapolación lineal a 20 provincias (el máximo validado, 4 veces las 5 medidas): ≈ 2,6 ms por paso, que a ×600 (10 pasos por segundo) serían ≈ 26 ms por segundo (≈ 3 % de un núcleo) [Suposición: linealidad, y una partida avanzada con más edificios y población sin medir].
- Icono: el registro de exportación avisaba «No project icon specified»; se añade `game/icon.svg` (torre dorada sobre círculo verde, diseño propio y provisional) como icono del proyecto y de la app. Comprobado: Godot lo importa y lo dibuja; cómo queda como icono en tu pantalla de inicio no se ha visto.
- Los archivos `.uid` que Godot genera junto a cada script no se versionan (`.gitignore`): el proyecto carga por ruta y la CI funciona sin ellos.
- Qué NO está probado: nada de esto se ha visto en un móvil real. Las capturas se generan en un entorno Linux con dibujado por software (`tools/captura_ui.gd`).
- Estado: **provisional**.

## D-019. El APK se entrega como `.apk` suelto, no como zip

- Petición del usuario (estable, «siempre»): el APK debe obtenerse como archivo instalable, no dentro de un `.zip`.
- Causa: GitHub comprimía todo artefacto de Actions en un zip. Desde febrero de 2026 `actions/upload-artifact` v7 admite `archive: false`, que sube un único archivo tal cual y lo deja descargar sin descomprimir. Con esa opción el parámetro `name` se ignora y el artefacto se llama como el archivo: `reinos-tycoon-debug.apk`. Fuentes: anuncio de GitHub (26-02-2026) y README de la acción.
- Cambio: el paso que guarda el APK usa `upload-artifact@v7` con `archive: false`. Los registros (`ci-log-*`) siguen con v4 y comprimidos, y el trabajo `informe` sigue leyéndolos con `download-artifact@v4`; no se tocan.
- Límite conocido: sigue siendo un artefacto de Actions, así que hay que iniciar sesión en GitHub para bajarlo y caduca a los 30 días. Una página de versión (Release) con el APK adjunto evitaría la caducidad, pero publica en un repositorio público: **solo con permiso explícito del usuario** (sec. 37).
- Comprobado (ejecución #17, `version/code` 24, misma firma `f3e6ecc4…48d5`): la API de GitHub lista el artefacto como `reinos-tycoon-debug.apk` (28 380 221 bytes), ya no `reinos-tycoon-debug-apk`. Eso no prueba por sí solo que el navegador del móvil lo baje sin zip ni que se instale: falta verlo en el móvil.
- Estado: **provisional hasta descargarlo e instalarlo en el móvil**.

## Orden de entregas

La sección 40 pedía empezar por las entregas A, B y C. Este repositorio nació con la D (archivos iniciales) porque el primer texto llegó cortado. Los archivos de la D son mínimos y reversibles; no condicionan el plan.
