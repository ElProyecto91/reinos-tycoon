# Licencias de terceros

| Componente | Dónde se usa | Licencia | Estado |
|---|---|---|---|
| Godot Engine 4.7.2 (motor y plantillas de exportación) | incluido en el APK | MIT | La licencia no se ha consultado en esta sesión. Su texto debe mostrarse en una pantalla de créditos antes de distribuir (fase 9) |
| KayKit: Medieval Hexagon Pack 1.0 (Kay Lousberg), subconjunto de 118 modelos 3D y su paleta, en `game/assets/kaykit/models/` | vista 3D (`game/scripts/view/diorama.gd`), incluido en el APK | CC0 1.0 (dominio público) | Leída la licencia el 2026-10-21 (copia en `game/assets/kaykit/LICENSE_KayKit.txt`). No exige atribución; se acredita igualmente (pantalla de créditos, fase 9). Detalle abajo |

Fuentes tipográficas y sonido: no hay recursos externos todavía. Se usa la fuente por defecto del motor, cubierta por los avisos de terceros de Godot.

Cada recurso externo que se añada debe registrarse aquí con origen, licencia y fecha de consulta (sección 26).

## KayKit: Medieval Hexagon Pack (1.0)

- Autor: Kay Lousberg (www.kaylousberg.com). Licencia **CC0 1.0**: se puede usar, modificar y distribuir, también con fines comerciales, sin obligación de atribución.
- Origen: https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 (commit `84fa4e91af6a88989be7c99e0891cede11f2ca38`, 2024-04-26). Consultado y copiado el 2026-10-21.
- Se copió solo lo que usa la vista 3D: 118 modelos `.gltf` con su `.bin` y la paleta `hexagons_medieval.png`, todo en `game/assets/kaykit/models/`. La lista sale de lo que usa `diorama.gd` (`tools/copiar_modelos.py` la copia y borra los sobrantes). No se incluyen los modelos sin usar, los ejemplos ni los plugins del paquete.
- Modificación: la paleta tiene el césped recoloreado de amarillo-verdoso a verde con `tools/recolor_paleta.py` (tono +34° y un 10 % más oscuro; solo cambia los píxeles de esa franja de color; trigo, tejados, piedra y árboles quedan igual). Los modelos no se han modificado. Dos paletas derivadas, también bajo CC0 por ser obras derivadas de una obra CC0 (`hexagons_seco.png` y `hexagons_norte.png`, hechas con `tools/recolor_paleta.py` a partir de la paleta original del paquete; recolorean el césped, el agua y los tres tonos del camino) las usa la vista de época (`ciudad_epoca.gd`).
- Antes de usar material de otras fuentes: comprobar su licencia, apuntarla aquí y no copiar nada de otros juegos (en especial del juego «Reinos» existente).
