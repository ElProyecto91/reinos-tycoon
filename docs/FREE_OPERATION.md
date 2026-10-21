# Funcionamiento gratuito

Última revisión: 2026-10-21. Objetivo: 0 € obligatorios para desarrollar, ejecutar y jugar (sección 26).

"Verificado" significa comprobado en una fuente oficial el día indicado. "No" significa que es lo esperado pero no se ha comprobado.

| Elemento | Para qué | Condiciones esperadas | Coste | Verificado |
|---|---|---|---|---|
| Godot Engine 4.7.2-stable | motor y plantillas de exportación | licencia MIT | 0 € | No. Sí se comprobó que la 4.7.2 es la última estable (archivo oficial, 2026-10-21) |
| GitHub, repositorio público | código y documentación | plan gratuito | 0 € | No |
| GitHub Actions en repositorios públicos | pruebas y APK en la nube | minutos gratuitos en repositorios públicos | 0 € | No |
| Imagen `barichello/godot-ci:4.7.2` (Docker Hub) | Godot, SDK de Android y JDK ya preparados | licencia de código abierto (esperada MIT) | 0 € | No. Sí se vio que la etiqueta existe (2026-10-21) |
| Android SDK y OpenJDK 17 | exportar el APK | licencias propias del SDK y de OpenJDK | 0 € | No |
| Móvil Android | probar los APK | el del usuario | 0 € | no aplica |

## Dependencias obligatorias al jugar

Ninguna. El juego no usa servidores, cuentas, anuncios ni conexión a Internet.

## Puntos a vigilar

- Las condiciones vigentes de GitHub Actions para repositorios públicos. Si cambian, hay que buscar otra vía de compilación sin PC.
- Docker Hub limita las descargas anónimas. Si el flujo falla al descargar la imagen, reintentar más tarde o cambiar de origen.
- Los artefactos de GitHub caducan (aquí, a los 30 días). El APK hay que descargarlo antes.
- Publicar en una tienda queda fuera del coste cero obligatorio: se comprueban las tasas vigentes cuando llegue el momento (sección 26).
