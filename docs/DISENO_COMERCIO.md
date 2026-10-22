# Diseño: redes de comercio y distribución dentro de cada reino (borrador, sin código)

Petición del usuario (2026-10-22): «en cada reino exista redes de comercio y distribución de materiales o mercancías para cubrir déficit en algún pueblo o ciudad». Es la fase 4 del plan («Comercio»), adelantada. Todo lo que sigue son **parámetros de juego provisionales**, no datos históricos: no hay fuente leída sobre rutas ni volúmenes de comercio hacia el año 1000 en este repositorio.

## Qué hace (comportamiento visible)

- Cada **reino** del mapa (Califato, León, Portugal, Castilla, Pamplona, condados catalanes) tiene una **red**: sus provincias conectadas por las vecindades del mapa (las que ya existen en `map.json`).
- Cada día de juego (24 pasos) la red reparte: lo que sobra en unas provincias va a las que les falta, **sin que el jugador toque nada**. El jugador puede ver qué se mueve y por dónde; la gestión manual (prioridades, vetos) es una fase posterior.
- Las mercancías **tardan** en llegar (caravanas): salen de una provincia y llegan a otra pasados unos pasos según la distancia en provincias. Mientras viajan no están en ningún almacén.
- Mover cuesta **moneda** (la paga la provincia que recibe) y cada ruta tiene un **tope diario** de carga. El **Mercado** de una provincia sube el tope de sus rutas. Las provincias de un reino no comercian con las de otro: el comercio entre reinos queda para después.

## Cuándo una provincia «tiene déficit» o «tiene excedente»

Por mercancía física y provincia, con el límite del almacén `L` y las existencias `S`:
- **Déficit**: `S` por debajo de `deficit_percent` de `L` (por ejemplo 20 %) *y* hay consumo o producción que la necesita (hoy: alimento y lo que usan sus edificios). Pide hasta `target_percent` de `L` (por ejemplo 50 %).
- **Excedente**: `S` por encima de `surplus_percent` de `L` (por ejemplo 70 %). Ofrece lo que pase de `target_percent`.
- Primero se atiende a las provincias con **hambre** (alimento), después al resto por mayor falta relativa. Empates por orden estable del mapa (determinista, sin azar).

## Cómo encaja en la simulación (lo que hay que construir)

1. **Datos** (`trade.json`, validado): porcentajes, intervalo de reparto, pasos por salto, coste en moneda por unidad y salto, tope diario por ruta y su aumento por Mercado.
2. **Red**: grafo por reino a partir de `map.json`; recorrido más corto por número de saltos; desempate fijo.
3. **Envíos en tránsito**: `{origen, destino, mercancía, cantidad, llegada}` en el mundo, guardados con el resto de la partida. El libro del almacén ya tiene «exportado» e «importado», así que **la conservación sigue cumpliéndose**: lo que sale de A queda como «en tránsito» y se acredita en B al llegar. La comprobación de coherencia del mundo cuenta lo que viaja.
4. **Paso del mundo**: llegadas, luego (si toca) reparto nuevo. Si el destino ya no tiene sitio al llegar, el envío **vuelve a esperar** o se pierde con aviso (decisión abierta; propuesta: espera hasta 24 pasos y luego se devuelve al origen).
5. **Guardado**: lista de envíos con validación estricta como el resto (cantidades enteras, provincias existentes, sin duplicados). Un guardado anterior sin envíos se carga sin problemas.
6. **Interfaz con símbolos**: en el mapa, líneas entre provincias con puntos que se mueven y el icono de la mercancía; en la ficha, un icono de caravana con lo que entra y sale (números cortos), sin párrafos.
7. **Pruebas**: conservación con envíos en vuelo durante 2 años; determinismo; que una provincia con hambre reciba antes que una con déficit leve; que no se reparta entre reinos distintos; que con coste mayor que la moneda disponible no se envía; guardado y carga a mitad de viaje; rendimiento con 40 provincias.

## Riesgos y límites que conviene saber

- **[Probable]** El reparto automático puede **tapar** malos diseños de producción: una provincia sin granja sobrevivirá si sus vecinas sobran. Eso es lo que se pide, pero baja la tensión del juego; el coste en moneda y los topes deben ser lo bastante molestos.
- **[Probable]** Con 40 provincias, repartir cada día cuesta tiempo por paso en el móvil. Hay que medirlo (el menú ya tiene «Medir velocidad»); si pesa, el reparto se hace cada 48 pasos o solo por provincias con déficit.
- **[Suposición]** Todas las cifras (porcentajes, costes, topes) son inventadas para jugar. Sin fuente histórica no pretenden serlo.
- **[Certeza]** No hay comercio entre reinos en esta pieza.

## Orden propuesto

1. Fase 2.1 y 2.2 (calendario y cosechas por estación): crean los déficits y excedentes reales del año.
2. Esta pieza (red de distribución dentro de cada reino).
3. Resto de la fase 2 (leña, cadena forestal, mantenimiento, mejoras) y su interfaz.
4. Comercio entre reinos y gestión manual (fase 4 propiamente dicha).
