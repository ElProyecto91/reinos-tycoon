# Diseño: conquista de territorios colindantes de otros reinos (CQ1–CQ6 en versión mínima, 0.4.0 y 0.5.0; ver D-038 y D-040)

Petición del usuario (2026-10-22): «quiero que sea un juego en el que puedas ir conquistando territorio colindantes de otros reinos». En el plan ya estaba como **fase 6 (Guerra)**, que depende de comercio (4) y mundo político (5). Todo lo que sigue son **parámetros de juego provisionales**: no hay fuente leída sobre tamaños de ejércitos ni resultados de campañas hacia el año 1000 en este repositorio.

## Qué existe hoy y qué no [Certeza]

- Existe: 40 provincias en 6 entidades con vecindades en `map.json`, reclutamiento (cuartel, armas, moneda por paso), soldados visibles en la vista 3D.
- **No existe**: propietario de una provincia distinto de su reino inicial, movimiento de ejércitos, combate, asedio, conquista, reinos rivales que decidan algo. Hoy los soldados solo cuestan.

## Comportamiento visible (propuesta)

1. **Propiedad**: cada provincia tiene un propietario (reino). La partida empieza con el jugador en **una provincia** de un reino; el resto pertenece a los demás. El color del mapa sigue al propietario.
2. **Objetivos**: solo se puede atacar una provincia **colindante** con una propia (símbolo de espadas en la tarjeta de la provincia enemiga; sin texto largo).
3. **Ejército en marcha**: se envían soldados de una provincia propia a la colindante; tardan pasos según la distancia, comen del almacén de origen mientras marchan y siguen cobrando.
4. **Resolución determinista** (sin azar, para poder probarla): fuerza de ataque = soldados × factor de equipo; fuerza de defensa = guarnición del defensor × factor de terreno/fortificación. El asedio dura varios pasos; cada paso ambos bandos pierden soldados en proporción; gana quien deja al otro sin soldados o el atacante cuando la defensa cae por debajo del umbral de rendición.
5. **Integración** (documento maestro, sec. 16: conquistar no da todo de golpe): la provincia conquistada empieza con descontento alto, sus edificios siguen pero la producción se ralentiza por descontento (mecanismo ya existente, D-014), y cada provincia propia sube un **coste administrativo** en moneda para todas.
6. **Rivales**: al principio los reinos rivales solo **defienden** (guarnición según su cuartel y armas). Después, un comportamiento mínimo de IA (reclutar, defender, atacar a un vecino débil).
7. **Interfaz con símbolos**: en el mapa, resaltado de las provincias atacables; flecha de ejército en marcha; comparación casco/escudo con barras antes de atacar; informe de batalla con iconos y números cortos.

## Piezas (cada una pequeña y con pruebas)

| Pieza | Qué | Pruebas clave |
|---|---|---|
| CQ1 | Propietario por provincia (guardado con validación, color del mapa, un guardado sin propietarios se carga) | propietarios válidos; el mapa sigue al propietario; carga retrocompatible |
| CQ2 | Ejército en marcha entre provincias colindantes (salida, llegada, comida, paga) | conservación de comida y soldados; no se marcha a una no colindante; guardar a mitad de marcha |
| CQ3 | Resolución del asedio y la batalla, determinista | mismo resultado con mismos datos; más soldados no pierde con menos; bajas conservan la población |
| CQ4 | Conquista e integración (cambio de propietario, descontento, coste administrativo) | el propietario cambia solo al ganar; el coste sube con provincias propias |
| CQ5 | Interfaz con símbolos (atacables, flechas, informe) | prueba de lógica + capturas |
| CQ6 | Rivales: defensa y, después, IA mínima | los rivales defienden con su guarnición real; sin IA no hay ataques |

## Riesgos y límites

- **[Probable]** Sin IA y sin propiedad dinámica, la conquista es un solitario trivial; el interés real llega con CQ6, que es lo más difícil de equilibrar.
- **[Probable]** Con 40 provincias simuladas a la vez, los ejércitos en marcha añaden coste por paso; hay que medirlo (menú «Medir velocidad»).
- **[Suposición]** Todas las cifras (factores, umbrales, costes) son inventadas para jugar. No se presentarán como históricas.
- **[Certeza]** El comercio entre reinos y las relaciones políticas (tregua, tributo, alianzas) quedan fuera de esta pieza.

## Decisiones abiertas

- ¿Se puede **perder** una provincia (el rival ataca al jugador)? Propuesta: sí desde CQ6, no antes.
- ¿El jugador elige reino/provincia inicial? Propuesta: provincia de partida elegible en el mapa.
- ¿Se puede jugar sin conquista? Propuesta: la economía no depende de la guerra; los rivales no atacan hasta que el jugador los ataque o se active la IA.

## Orden propuesto

Fase 2 (2.2 a 2.8) → red de comercio dentro de cada reino → CQ1 a CQ4 como «corte vertical» mínimo jugable → CQ5 → CQ6. No se adelanta sobre la fase 2 que el usuario pidió terminar antes.
