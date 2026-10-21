**REINOS**

**TYCOON**

**DOCUMENTO MAESTRO DEL PROYECTO**

Especificación de producto, diseño, historia, arquitectura,  
implementación, pruebas y estrategia de coste cero

Versión 1.0 • Preparado para trabajar con Claude

# Cómo utilizar este documento

Este documento contiene las instrucciones maestras para desarrollar Reinos Tycoon como un proyecto independiente. Pégalo en Claude o utilízalo como especificación de referencia. La implementación debe realizarse por fases verificables, no en una única generación masiva de código.

Importante: Reinos Tycoon es independiente del videojuego existente llamado Reinos. No modificar ni sobrescribir el repositorio original.

## Flujo recomendado

1.  Crear un repositorio independiente llamado reinos-tycoon.

2.  Pegar el documento en Claude y solicitar primero la verificación del entorno, la auditoría del repositorio nuevo y el plan de ejecución.

3.  Crear la documentación y la estructura inicial antes de implementar sistemas complejos.

4.  Construir un MVP de 10–20 provincias con economía, población, construcción, guardado y progreso offline.

5.  Añadir comercio, guerra, diplomacia y ampliación histórica solo cuando la base sea estable.

6.  Probar cada entrega y exportar versiones de Android regularmente.

## Sobre el objetivo de coste cero

El objetivo es que desarrollar, ejecutar y jugar no requiera servicios de pago: Godot, GDScript, almacenamiento local y recursos con licencias compatibles. Los planes gratuitos de herramientas externas pueden tener límites y la publicación en tiendas puede tener condiciones o tasas propias; no debe asumirse que todo servicio es gratuito para siempre.

# 1. TU PAPEL COMO DESARROLLADOR

Actúa como un equipo multidisciplinar formado por un director técnico de videojuegos, programador sénior de Godot/GDScript, diseñador de juegos de estrategia y gestión Idle, especialista en economía de simulación, historiador medieval, diseñador de interfaces Android y responsable de pruebas y documentación.

Tu responsabilidad es ayudarme a construir el videojuego completo Reinos Tycoon, no solo diseñarlo. Convierte esta especificación en un proyecto real, implementable, documentado, probado y ampliable.

## Reglas fundamentales

- El proyecto debe ser independiente y llamarse Reinos Tycoon.

- El coste obligatorio de desarrollo, ejecución y juego debe ser 0 €.

- El juego debe funcionar sin conexión a Internet y Android es la plataforma prioritaria.

- La simulación debe ser profunda, pero el código debe seguir siendo mantenible.

- Los datos históricos deben estar separados de la lógica del juego.

- No construyas todos los sistemas a la vez ni sacrifiques estabilidad por añadir funciones.

- No inventes hechos históricos ni resultados de pruebas.

- Cada sistema debe tener criterios de aceptación verificables.

- Si trabajas sin acceso al repositorio, no afirmes que has modificado archivos; solicita los archivos necesarios.

# 2. IDENTIDAD Y SEPARACIÓN DE PROYECTOS

Ya existe otro videojuego llamado Reinos. Ese proyecto es independiente y debe permanecer intacto. El nuevo videojuego se llama exclusivamente Reinos Tycoon y tendrá su propio repositorio, recomendado: reinos-tycoon.

No reutilices, sobrescribas, renombres ni elimines archivos del proyecto Reinos. No asumas que sus sistemas son reutilizables. Si identificas alguna posibilidad de reutilización, presenta una propuesta separada y espera autorización.

Antes de programar, confirma el repositorio correcto, comprueba la estructura, verifica el motor y las herramientas disponibles, crea o documenta una copia de seguridad inicial y evita cambios destructivos sin autorización.

# 3. VISIÓN DEL VIDEOJUEGO

Reinos Tycoon será un juego de estrategia, construcción, economía, gestión territorial y progreso Idle ambientado aproximadamente alrededor del año 1000 d. C. El jugador comenzará con un territorio pequeño y podrá convertirlo en una potencia regional, un reino extenso o una federación.

La experiencia combinará gestión económica, asentamientos, agricultura, industria, población, trabajadores, almacenamiento, comercio, logística, tecnología, administración, diplomacia, ejércitos, guerra, conquista, automatización, progreso offline y objetivos a largo plazo.

## Bucle principal

Producción → recursos → población → necesidades → excedentes → comercio → ingresos → infraestructura → tecnología → capacidad militar y administrativa → expansión → integración → automatización → nuevas oportunidades.

Conquistar un territorio no debe equivaler a obtener inmediatamente todos sus beneficios. La expansión debe generar nuevas necesidades de logística, administración y estabilidad.

## Experiencia objetivo

- Progreso perceptible en los primeros minutos.

- Decisiones interesantes durante las primeras horas.

- Automatización progresiva y desarrollo territorial a medio plazo.

- Objetivos que puedan prolongarse durante meses de juego.

- Partidas interesantes tanto jugando activamente como regresando tras varias horas.

# 4. PRINCIPIOS DE DISEÑO

- Profundidad con reglas comprensibles: explicar por qué una fábrica no produce, qué recurso falta o por qué una ruta no es rentable.

- Especialización territorial: las provincias deben diferenciarse por geografía, recursos, población, infraestructura y política.

- Consecuencias reales: reclutar afecta al trabajo civil; la guerra interrumpe rutas; los puentes reducen costes; las conquistas aumentan los costes administrativos.

- Automatización progresiva: desbloquear tareas automáticas como recompensa, con límites y prioridades.

- Evitar complejidad inútil: utilizar modelos agregados en vez de simular cada persona u objeto.

# 5. AMBIENTACIÓN HISTÓRICA Y CRONOLOGÍA

La fecha de referencia será aproximadamente el año 1000 d. C. El conjunto inicial de datos debe utilizar una fecha explícita y no mezclar entidades de siglos diferentes.

Distingue hechos documentados, reconstrucciones históricas, inferencias geográficas, simplificaciones jugables y decisiones de diseño. No inventes fuentes, fronteras, asentamientos ni recursos. Representa la incertidumbre política mediante control directo, vasallaje, influencia y fronteras no consolidadas.

## Poderes políticos que investigar

- Islas británicas: Inglaterra, Escocia, Gales e Irlanda.

- Península ibérica: Califato de Córdoba y poderes cristianos ibéricos.

- Europa occidental y central: Francia, Sacro Imperio e Italia.

- Balcanes y mundo bizantino.

- Rus de Kiev, Polonia y Hungría.

- Norte de África, Califato abasí y poderes regionales de Oriente Próximo e Irán.

- Samaníes, Karajánidas, Gaznávidas y otros poderes centroasiáticos, verificando cronología.

- Song del Norte, Liao, Goryeo, Japón del periodo Heian y poderes regionales de India.

Esta lista es un plan de investigación, no una lista definitiva de entidades simultáneas. Verifica cada entidad y su situación política en la fecha seleccionada.

# 6. GEOGRAFÍA Y MAPA DEL MUNDO

El mundo final debe extenderse desde Europa occidental hasta Asia oriental, incluyendo islas británicas, Iberia, Europa central y oriental, Escandinavia, Balcanes, Mediterráneo, norte de África, Anatolia, Cáucaso, Mesopotamia, Persia, Arabia, Asia Central, India, China, Corea y Japón.

Representa montañas, llanuras, bosques, estepas, desiertos, ríos, lagos, costas, islas, pasos, oasis, tierras agrícolas y puertos. La geografía debe afectar al transporte, la producción, el abastecimiento y la defensa.

El objetivo final puede incluir cientos de provincias, si rendimiento y calidad lo permiten. El MVP comienza con 10–20. La ampliación debe hacerse mediante datos, no reescribiendo la lógica.

## Capas de información

- Política.

- Geografía.

- Recursos.

- Producción.

- Comercio.

- Rutas y abastecimiento.

- Militar.

- Seguridad y lealtad.

- Población.

- Infraestructura.

Cada capa debe poder activarse y desactivarse.

# 7. IDENTIDAD VISUAL

Dirección artística: atlas medieval de alta calidad con pergamino envejecido, tinta, relieve, montañas y bosques ilustrados, ríos reconocibles, fronteras pintadas, símbolos de ciudades y fortalezas, emblemas originales y rutas.

Paleta: sepias, ocres, marrones, verdes apagados, azules grisáceos, colores diferenciados para los poderes y tonos intensos para alertas críticas.

Evita estética infantil o futurista, interfaz excesivamente recargada y efectos que perjudiquen el rendimiento.

## Niveles de zoom

- Continental: reinos, regiones, ciudades y rutas principales.

- Provincial: límites, recursos, asentamientos, caminos, puentes y fortalezas.

- Local: edificios, campos y talleres cuando sea viable.

No es obligatorio crear una vista 3D. La prioridad es claridad, rendimiento y coherencia visual.

# 8. PROVINCIAS Y TERRITORIOS

Cada provincia debe tener un identificador estable y una ficha ampliable con nombre, variantes históricas, región, terreno, clima, superficie útil, fertilidad, agua, bosques, recursos, población, vivienda, mano de obra, seguridad, lealtad, infraestructura, edificios, almacenes, producción, consumo, comercio, rutas, gobernador, guarnición, control político, impuestos, costes administrativos, fuentes y confianza.

## Especialización

Ejemplos: granero regional, centro ganadero, zona forestal, distrito minero, ciudad artesanal, puerto comercial, paso militar, oasis, centro religioso o capital administrativa. Una provincia puede combinar funciones y la especialización debe surgir de la geografía, infraestructura y decisiones del jugador.

# 9. SISTEMA DE RECURSOS

## Categorías

- Alimentos: trigo, cebada, centeno, avena, arroz cuando corresponda, legumbres, verduras, frutas, pescado, carne, huevos, leche, queso y miel.

- Agua: pozos, ríos aprovechables, cisternas y canales; puede modelarse como capacidad local, no siempre como mercancía.

- Bosques: troncos, madera, leña y carbón vegetal.

- Minerales: hierro, cobre, estaño, plomo, plata y oro, distribuidos según geología y evidencia.

- Construcción: piedra, arcilla, ladrillos, cal y tejas.

- Textiles: lana, lino, algodón, seda, tintes y tejidos.

- Ganadería: caballos, bueyes, ovejas, cabras, cerdos y camellos cuando sean apropiados.

- Manufacturas: harina, pan, herramientas, cuero, cerámica, vidrio y papel cuando corresponda.

- Comercio especializado: especias, incienso, perfumes, pieles y bienes de lujo documentados.

- Institucionales: moneda, conocimiento, legitimidad e influencia; no todos son mercancías físicas.

Cada recurso tendrá ID, nombre traducible, categoría, unidad abstracta, fuentes de producción, usos, requisitos de almacenamiento, durabilidad si procede, distribución regional, valor de referencia, fuente y grado de confianza.

El catálogo final puede contener decenas de recursos. El MVP debe comenzar con 8–12 mercancías esenciales.

# 10. ECONOMÍA Y CADENAS DE PRODUCCIÓN

La economía debe respetar la conservación de recursos. Balance: existencias finales = iniciales + producción + importaciones − consumo − exportaciones − pérdidas. Las transferencias internas deben registrarse para evitar duplicaciones.

## Cadenas principales

- Agrícola: cultivo → cosecha → granero → molino → harina → panadería → consumo o mercado.

- Forestal: bosque → tala → troncos → transformación → madera o leña → construcción y consumo.

- Metalúrgica: mineral → combustible → fundición → metal trabajado → herrería → herramientas y armas.

- Textil: materia prima apropiada → transformación → tejido → mercado o consumo.

Cada edificio define coste inicial, requisitos, mano de obra, insumos, producción base, intervalo, mantenimiento, almacenamiento, mejoras, efectos y condiciones de parada.

La agricultura tiene temporadas; las minas pueden agotarse; los bosques se regeneran; pastos y animales requieren capacidad, alimento y agua; los productos perecederos pueden deteriorarse.

# 11. POBLACIÓN Y TRABAJO

La población se modela de forma agregada por provincia y categoría: campesinos, artesanos, comerciantes y transportistas, funcionarios, nobles, clero según contexto y soldados.

Necesidades: alimentación, agua, combustible, vivienda, seguridad, vestimenta, empleo y estabilidad. Variables: población, trabajadores disponibles y asignados, capacidad residencial, bienestar, seguridad, descontento, crecimiento, migración y mortalidad abstracta cuando sea necesaria.

El sistema de prioridades laborales debe ser configurable y visible. Las necesidades esenciales, producción alimentaria, agua y mantenimiento deben competir con industria, comercio, administración y ejército. Reclutar demasiado reduce la disponibilidad civil.

Las crisis deben ser graduales: hambre, emigración, menor productividad y descontento. Deben existir alertas y posibilidades de recuperación.

# 12. ASENTAMIENTOS Y CONSTRUCCIÓN

Tipos: aldea, pueblo, ciudad, capital regional, puerto, castillo, fortaleza, puesto comercial y puesto caravanero. No todas las provincias necesitan una gran ciudad.

Familias de edificios: residenciales, agrícolas, almacenamiento, agua, forestales, mineros, industriales, comerciales, administrativos, culturales/religiosos, militares e infraestructura.

Cada construcción debe mostrar precio, recursos necesarios, tiempo restante, efecto esperado, requisitos, mano de obra y mantenimiento. No permitir construcciones imposibles. Las mejoras deben ser comprensibles y no crear inflación descontrolada.

# 13. ALMACENAMIENTO Y DISTRIBUCIÓN

Las provincias y edificios respetan su capacidad. Si un almacén se llena, la producción se detiene, reduce o dirige a otro destino permitido. Las transferencias nunca deben duplicar recursos.

La interfaz muestra existencias, capacidad, producción, consumo, importaciones, exportaciones, tiempo estimado hasta agotamiento, excedentes y déficits. El jugador debe identificar qué recurso limita el desarrollo.

# 14. COMERCIO Y LOGÍSTICA

El comercio utiliza una red de conexiones entre provincias y nodos. Incluye caminos, puentes, ríos navegables, puertos, caravanas, carros, animales de carga, camellos en zonas apropiadas, rutas marítimas, oasis y puestos caravaneros.

Coste y duración dependen de distancia, terreno, infraestructura, transporte, capacidad, seguridad, peajes, estación, guerra e interrupciones.

Los precios responden a oferta, demanda y transporte, usando un modelo acotado y estable.

## Órdenes automáticas

- Mantener reservas mínimas.

- Exportar excedentes.

- Importar recursos bajo umbral.

- Priorizar abastecimiento urbano.

- Abastecer ejércitos.

- Limitar gastos.

- Suspender rutas no rentables.

Cada ruta muestra origen, destino, mercancía, cantidad, capacidad, tiempo, coste, ingresos previstos, estado, riesgo y rentabilidad. Una ruta interrumpida no transporta mercancías.

# 15. DIPLOMACIA

Relaciones posibles: paz, guerra, no agresión, acuerdo comercial, alianza, permiso de paso, tributo, vasallaje, reclamación territorial, indemnización, devolución territorial y negociación de paz.

Las opciones dependen de la situación política y reglas del juego. No todas las entidades deben compartir títulos o instituciones. La diplomacia tiene costes, condiciones y consecuencias. Las alianzas no garantizan participación automática en todas las guerras.

# 16. GUERRA, EJÉRCITOS Y CONQUISTA

Unidades progresivas: milicias, infantería, arqueros, caballería, ingenieros, guarniciones, mercenarios y fuerzas navales cuando el alcance lo justifique. Disponibilidad variable por región y época.

Las tropas requieren población reclutable, moneda, equipamiento, alimento, transporte, mantenimiento y tiempo de preparación.

Las batallas consideran tamaño, composición, equipo, experiencia, moral, general, terreno, fortificaciones, abastecimiento, fatiga, tecnología, refuerzos y situación estratégica.

Los asedios consideran fortificaciones, suministros, duración, desgaste, refuerzos, crisis abstractas, negociación y rendición.

Conquistar cambia el control político, pero no elimina población, costes administrativos, inseguridad, necesidades logísticas ni tiempo de integración. La guerra debe poder resultar costosa.

# 17. ADMINISTRACIÓN, GOBERNADORES Y DINASTÍAS

La administración provincial podrá priorizar producción, seguridad, recaudación, comercio, desarrollo y lealtad.

Los gobernadores pueden tener rasgos y capacidades sin exigir centenares de personajes complejos. La legitimidad puede depender de seguridad, fiscalidad, estabilidad, relaciones políticas, sucesión, trato territorial, resultados militares y contexto cultural.

La diversidad cultural no debe penalizarse automáticamente. En una fase avanzada pueden incorporarse personajes, edad, rasgos, relaciones, sucesión, reclamaciones y alianzas matrimoniales cuando sean históricamente apropiadas. No retrasar el MVP por estos sistemas.

# 18. TECNOLOGÍA Y PROGRESIÓN

Árboles: agricultura y población; industria y construcción; comercio y logística; administración y cultura; guerra y diplomacia.

Cada mejora tiene un efecto concreto. Evita tecnologías anacrónicas y distingue el progreso abstracto del año exacto de invención. La progresión debe desbloquear capacidades y decisiones relevantes, no limitarse a porcentajes.

# 19. SISTEMA IDLE Y PROGRESO OFFLINE

El juego progresa con la aplicación cerrada sin servidor. Al guardar, registra una marca temporal; al cargar, calcula el tiempo transcurrido y simula los sistemas relevantes por intervalos controlados.

Comienza con un límite configurable de 8–12 horas, como decisión de balance. Simula producción, consumo, almacenamiento, construcciones, comercio sencillo, crecimiento agregado, mantenimiento, eventos y automatizaciones autorizadas.

Controla tiempos negativos, cambios extremos de reloj, operaciones repetidas y límites máximos. Si existe incoherencia temporal, usa un comportamiento seguro.

Al regresar, muestra tiempo transcurrido, recursos producidos y consumidos, construcciones terminadas, cambios de existencias, alertas, incidentes y estado provincial.

# 20. AUTOMATIZACIÓN

Desbloquea progresivamente capataces de producción, responsables de almacenes, maestros de caravanas, gobernadores, administradores fiscales y responsables militares.

Cada automatización debe tener órdenes, límites y prioridades. Evita que venda todas las reservas o consuma todo el tesoro sin advertencia. El jugador puede suspender, editar y revisar órdenes.

# 21. EVENTOS Y MUNDO VIVO

Eventos: mala cosecha, cosecha excepcional, inundación, sequía, descubrimiento de recurso, interrupción de ruta, bandolerismo, disputa sucesoria, oportunidad comercial, alianza, amenaza fronteriza, rebelión y crisis de abastecimiento.

Cada evento tiene condiciones, consecuencias y opciones. No depende de API de IA. Utiliza reglas, datos históricos y aleatoriedad controlada. Evita una frecuencia excesiva de crisis.

# 22. IA DE REINOS RIVALES

La IA funciona mediante reglas locales y decisiones deterministas o semialeatorias, sin modelos de lenguaje obligatorios.

Puede desarrollar economía, construir, mantener reservas, comerciar, mejorar infraestructura, proteger fronteras, reclutar, evaluar amenazas, buscar alianzas, atacar con ventaja y negociar cuando la guerra sea costosa.

La IA respeta las reglas económicas del jugador y no genera recursos o ejércitos gratuitos. En el MVP se limita a decisiones económicas y territoriales sencillas.

# 23. INTERFAZ Y EXPERIENCIA ANDROID

Android es la plataforma prioritaria. Requisitos: botones grandes, paneles adaptables, texto legible, zoom y desplazamiento fluidos, selección fiable, información sin hover, navegación clara, alertas, gestión de errores, guardado y consumo razonable de batería.

Valora modo horizontal y conserva un diseño usable en vertical cuando sea viable. No fuerces orientación sin justificarla.

## Pantallas progresivas

- Mapa del mundo.

- Vista y ficha provincial.

- Economía y recursos.

- Población y trabajadores.

- Edificios y construcción.

- Comercio y rutas.

- Ejército.

- Diplomacia.

- Tecnología.

- Administración.

- Eventos y alertas.

- Resumen offline.

- Opciones y guardado.

Las alertas prioritarias incluyen hambre, falta de agua, almacenes llenos, falta de insumos, rutas interrumpidas, ejército sin suministros, construcción bloqueada, tesoro insuficiente y provincia insegura. Las alertas importantes deben abrir la pantalla pertinente.

# 24. ARQUITECTURA TÉCNICA

Utiliza Godot 4.x estable y GDScript salvo razón técnica demostrable para otra tecnología. Verifica la versión adecuada para Android y las herramientas disponibles antes de fijarla.

Separa aplicación, interfaz, mapa, estado de partida, economía, recursos, población, edificios, producción, almacenamiento, comercio, logística, guerra, diplomacia, administración, IA, progresión, persistencia, datos históricos y pruebas.

Principios: datos separados de lógica, IDs estables, evitar reglas duplicadas y dependencias circulares, simulación por intervalos, no recalcular rutas innecesariamente, evitar reconstrucciones globales de interfaz, validar datos y versionar guardados.

Evalúa soluciones nativas de Godot antes de incorporar bibliotecas. Los recursos, edificios, recetas, provincias, rutas, tecnologías y poderes políticos deben definirse mediante datos siempre que sea razonable.

# 25. GUARDADO, CARGA Y RECUPERACIÓN

Utiliza almacenamiento local gratuito. Guarda versión del formato, marca temporal, estado del jugador, provincias, inventarios, población, edificios, trabajadores, producción, consumo, construcciones, rutas, órdenes, tecnología, diplomacia, ejércitos, eventos relevantes y semilla aleatoria cuando corresponda.

Requisitos: guardar manualmente y automáticamente, recuperarse de interrupciones, validar archivos, evitar destruir guardados válidos, mostrar errores, permitir copias anteriores cuando existan y migrar formatos antiguos de forma segura.

No añadas cuentas, sincronización en la nube ni servidores obligatorios.

# 26. OBJETIVO DE COSTE CERO

Prioriza Godot, GDScript, GitHub gratuito, herramientas gratuitas, recursos propios o con licencia compatible, almacenamiento local y exportación Android local.

No añadas API de IA de pago, servidores, backend o bases de datos remotas obligatorias, suscripciones para jugar, servicios facturables, recursos comerciales de pago, analítica o telemetría obligatoria, anuncios obligatorios, compras necesarias ni DRM.

Registra procedencia y licencias de recursos externos. No asumas que cualquier imagen de Internet es reutilizable.

Distingue desarrollo, exportación APK, distribución directa, publicación en tienda y alojamiento web. Comprueba tasas y condiciones vigentes antes de recomendar canales. El objetivo es generar y probar APK sin infraestructura o herramientas de pago obligatorias.

# 27. ALCANCE DEL MVP

El primer objetivo es demostrar que el núcleo funciona, no construir toda Eurasia.

- 10–20 provincias y dos o tres poderes políticos.

- Mapa seleccionable y dos o tres tipos de asentamiento.

- Población abstracta, trabajadores y 8–12 recursos.

- Entre 4 y 6 edificios productivos esenciales.

- Construcción, producción, consumo, almacenamiento y necesidades.

- Escasez y recuperación, mejoras, guardado y carga.

- Progreso offline e interfaz Android.

- Datos históricos iniciales documentados.

El prototipo debe incluir una explotación agrícola, reservas de alimentos, población que consume, transformación de materia prima, construcción con costes, trabajadores limitados, una crisis de escasez, posibilidad de recuperación, guardado y progreso offline.

Solo se considera funcional si puede ejecutarse y jugarse durante un periodo prolongado sin errores críticos de economía, guardado o interfaz.

# 28. FASES COMPLETAS DEL PROYECTO

- Fase 0 — Preparación: repositorio, documentación, versión Godot, estructura, convenciones, pruebas, exportación Android y coste cero.

- Fase 1 — Núcleo jugable: estado, mapa, selección provincial, recursos, almacenes, población, trabajadores, edificios, producción, consumo, construcción y guardado.

- Fase 2 — Economía avanzada: estacionalidad, cadenas agrícola/forestal/minera, mantenimiento, necesidades, escasez y mejoras.

- Fase 3 — Progreso offline: marca temporal, simulación por intervalos, límite, resumen, control de inconsistencias y pruebas.

- Fase 4 — Comercio: conexiones, costes, capacidad, precios, importaciones, exportaciones, reservas, automatización e interrupciones.

- Fase 5 — Mundo político: rivales, relaciones, IA económica, fronteras, reclamaciones, acuerdos y conflictos.

- Fase 6 — Guerra: reclutamiento, mantenimiento, movimiento, abastecimiento, batallas, asedios, conquista e integración.

- Fase 7 — Ampliación histórica: regiones, provincias, entidades, recursos, asentamientos, rutas y capas del mapa.

- Fase 8 — Automatización y progresión: encargados, gobernadores, mejoras, tecnología, especialización, eventos, objetivos y dinastías.

- Fase 9 — Pulido: rendimiento, accesibilidad, tutorial, equilibrio, interfaz, sonido, errores, pruebas y distribución.

Las fases pueden subdividirse. No deben convertirse en grandes cambios imposibles de revisar.

# 29. PRUEBAS OBLIGATORIAS

## Economía

- Edificios respetan costes y no producen sin insumos.

- Trabajadores no superan la población disponible.

- Recursos no aparecen de la nada ni se duplican.

- Almacenes respetan capacidad.

- Déficits afectan a la economía y la producción puede recuperarse.

## Población

- La población consume recursos.

- Asignación laboral válida.

- La escasez tiene consecuencias.

- Las reservas ayudan a superar crisis.

- El reclutamiento reduce disponibilidad laboral.

## Comercio y guerra

- El vendedor tiene mercancías y el comprador fondos.

- El transporte respeta capacidad y coste.

- Las rutas interrumpidas no operan.

- Reclutar cuesta recursos.

- Los ejércitos necesitan mantenimiento y suministros.

- La conquista cambia el control y conserva costes de integración.

## Persistencia y offline

- Guardar y cargar conserva estado.

- Archivos incompletos no destruyen automáticamente guardados válidos.

- Versiones antiguas se migran o rechazan de forma segura.

- Tiempos negativos no producen recompensas.

- El progreso respeta el límite y no duplica recursos.

## Android

- Inicio, interfaz táctil, zoom, desplazamiento y selección.

- Paneles, guardado y reanudación.

- Rendimiento y memoria controlados.

No marques una prueba como superada si no se ha ejecutado. Si no hay dispositivo o entorno de exportación, documenta la limitación y proporciona instrucciones manuales.

# 30. RENDIMIENTO Y ESCALABILIDAD

Diseña para cientos de provincias sin sobredimensionar el MVP. No simules cada habitante, no actualices la economía cada fotograma, no recalcules todas las rutas si nada ha cambiado y evita reconstruir todas las provincias ante un cambio local.

Mide rendimiento antes de optimizar. Prueba conjuntos progresivos de 20, 100 y más provincias. No declares que el juego admite cientos hasta haberlo comprobado.

# 31. DOCUMENTACIÓN DEL REPOSITORIO

- README.md: descripción, requisitos, instalación, ejecución, exportación Android y estado.

- docs/MASTER_DESIGN.md: visión, sistemas, mecánicas y alcance final.

- docs/HISTORICAL_DATA.md: entidades, cronología, geografía, recursos, fuentes e incertidumbre.

- docs/SIMULATION_SPEC.md: economía, población, producción, comercio, guerra y offline.

- docs/ARCHITECTURE.md: estructura, módulos, dependencias y flujo de datos.

- docs/DATA_SCHEMA.md: provincias, recursos, edificios, recetas, rutas y poderes.

- docs/ROADMAP.md: fases, dependencias y estado.

- docs/TEST_PLAN.md: pruebas, resultados, errores y pendientes.

- docs/FREE_OPERATION.md: herramientas, licencias, costes y dependencias.

- CHANGELOG.md: cambios por versión.

- THIRD_PARTY_LICENSES.md: recursos y licencias de terceros.

Adapta la estructura si existe una razón técnica, pero conserva la información necesaria. No crees documentos vacíos; deben ser útiles y mantenerse actualizados.

# 32. INVESTIGACIÓN HISTÓRICA Y FUENTES

Prioriza publicaciones académicas, instituciones patrimoniales, museos, proyectos de investigación, atlas especializados, fuentes arqueológicas, universidades y UNESCO cuando sea relevante.

Fuentes iniciales para investigar conexiones y rutas:

- UNESCO Silk Roads: https://www.unesco.org/en/silk-roads/about-silk-roads

- UNESCO Chang'an–Tian Shan: https://whc.unesco.org/en/list/1442/

- UNESCO Zarafshan–Karakum: https://whc.unesco.org/en/list/1675/

Estas fuentes no bastan para verificar todas las fronteras, recursos y asentamientos del año 1000. Para cada conjunto de datos registra fuente, URL, fecha de consulta, afirmación respaldada, alcance de evidencia, confianza y simplificaciones.

No confundas una ruta comercial documentada con la existencia de un recurso en todas las provincias que atraviesa. No inventes cifras precisas cuando solo existan estimaciones.

# 33. DATOS Y EQUILIBRIO

Distingue datos históricos —cronología, entidades, geografía, cultivos, rutas y tecnologías— de parámetros de juego —velocidad de producción, costes, duración, capacidad, límite offline y fórmulas de balance—.

No presentes parámetros de juego como estadísticas históricas. Usa tablas y pruebas. Evita inflación infinita, producción exponencial sin límites, recursos imposibles, crisis inevitables, guerras sin coste, conquistas sin administración, edificios inútiles y tecnologías que eliminen todas las decisiones.

# 34. USABILIDAD Y TUTORIAL

El tutorial debe enseñar progresivamente a seleccionar provincias, consultar recursos, construir, asignar trabajadores, producir, mantener reservas, satisfacer necesidades, mejorar edificios, resolver escasez, guardar, regresar tras una ausencia y más adelante comerciar y expandirse.

No muestres todas las explicaciones de golpe. Introduce complejidad cuando sea relevante y explica los efectos antes de confirmar decisiones importantes.

# 35. ACCESIBILIDAD Y CALIDAD DE VIDA

Incluye progresivamente texto legible, contraste suficiente, iconos coherentes, información que no dependa solo del color, pausa cuando corresponda, confirmación de acciones destructivas, indicadores de carga, mensajes claros, registro de acontecimientos, resumen económico, comparación de provincias y velocidades de simulación seguras.

No añadas notificaciones externas obligatorias ni permisos innecesarios.

# 36. REGLAS PARA MODIFICAR EL CÓDIGO

- Explicar objetivo y archivos implicados.

- Comprobar dependencias y proponer el cambio mínimo.

- Implementar y ejecutar pruebas disponibles.

- Corregir errores y revisar impacto en guardado y Android.

- Documentar resultados reales y lo no probado.

- Proporcionar instrucciones de validación manual.

- No reemplazar archivos enteros si basta un cambio localizado.

- No duplicar sistemas ni cambiar dependencias sin razón.

- No dejar botones ficticios sin identificarlos como pendientes.

# 37. CONTROL DE VERSIONES

Usa Git y commits pequeños con mensajes claros. Cada fase termina con cambios revisados, pruebas ejecutadas, documentación actualizada, versión identificable, resumen y problemas conocidos. No realices borrados masivos ni reescrituras del historial sin autorización. No publiques automáticamente.

# 38. CRITERIOS DE FINALIZACIÓN

El producto final debe tener un juego Idle funcional, mundo ampliable, economía, población, construcción, producción, almacenamiento, comercio, logística, diplomacia, guerra, conquista, administración, progresión, automatización, eventos, offline y guardado fiable.

El contenido debe estar documentado y cronológicamente coherente. La técnica debe incluir arquitectura modular, datos separados, rendimiento medido, persistencia segura, pruebas reproducibles y exportación Android comprobada.

No debe haber servidores, APIs, suscripciones, compras o telemetría obligatorios. Las licencias deben estar verificadas.

No declares terminado el proyecto solo porque existan documentos. Debe haber una versión jugable y verificable.

# 39. PRIMER ENCARGO A CLAUDE

## Entrega A — Confirmación

Resume lo entendido sobre Reinos Tycoon, su independencia del otro proyecto, el coste cero y la prioridad Android.

## Entrega B — Verificación del entorno

Determina si tienes acceso real al repositorio, archivos y Godot. Si no, explica qué puedes hacer y qué debo realizar yo.

## Entrega C — Plan

Desglosa el proyecto en tareas pequeñas, por dependencia y prioridad. Identifica qué se puede probar sin Android y qué requiere APK.

## Entrega D — Archivos iniciales

Prepara documentación y estructura inicial sin complejidad innecesaria.

## Entrega E — Primer prototipo

Define un prototipo de región pequeña con provincias seleccionables, economía, población, producción, construcción y guardado. Establece aceptación y pruebas antes de implementar.

## Entrega F — Validación

Presenta resultados reales y solicita autorización antes de acciones destructivas o de ampliar alcance. Recomienda la siguiente tarea concreta cuando una entrega esté terminada.

# 40. INSTRUCCIÓN FINAL

Mi objetivo es crear Reinos Tycoon, un juego histórico Idle Tycoon profundo, atractivo, estable, ampliable y jugable en Android, ambientado en Eurasia alrededor del año 1000 d. C.

Quiero un proyecto que pueda mantener a largo plazo sin pagar servicios obligatorios. No quiero una demostración visual vacía, un documento sin código, una economía rota ni cientos de sistemas incompletos.

Prioriza: 1) correctitud, 2) estabilidad, 3) coste cero obligatorio, 4) jugabilidad, 5) calidad histórica, 6) mantenimiento, 7) rendimiento Android, 8) escalabilidad, 9) calidad visual y 10) ampliación progresiva.

Empieza con las entregas A, B y C. No inventes resultados, no afirmes tener herramientas que no tienes y no inicies una reescritura completa sin verificar el entorno. Convierte esta especificación en un videojuego real mediante entregas comprobables.

# ANEXO — INSTRUCCIÓN DE SEGURIDAD PARA CADA ENTREGA

Añade este bloque al final de cada solicitud de implementación para mantener el trabajo acotado y verificable:

Trabaja en una entrega pequeña y verificable.

Antes de modificar código, indica los archivos que vas a cambiar y el motivo.

Después, resume los cambios y ejecuta las pruebas disponibles.

Comunica los resultados reales; no inventes pruebas.

No continúes si quedan errores críticos.

No reescribas archivos completos cuando baste con un cambio localizado.

Conserva las funcionalidades existentes.

No introduzcas ningún coste obligatorio.

Si te falta información, pide el archivo concreto que necesites.

# Checklist antes de empezar

- [ ] He creado o voy a crear un repositorio independiente llamado reinos-tycoon.

- [ ] El proyecto original Reinos permanecerá intacto.

- [ ] Claude ha confirmado qué herramientas puede usar realmente.

- [ ] La versión de Godot y los requisitos de Android están documentados.

- [ ] Los primeros documentos están creados y no vacíos.

- [ ] El MVP tiene criterios de aceptación y pruebas.

- [ ] No hay dependencias de pago obligatorias.

- [ ] Los recursos externos tienen licencias compatibles.
