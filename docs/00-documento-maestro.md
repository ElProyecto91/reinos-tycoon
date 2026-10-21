REINOS TYCOON — DOCUMENTO MAESTRO DEL PROYECTO

Versión del documento: 1.0
Tipo: Especificación maestra de producto, diseño, programación, contenido histórico, arquitectura, pruebas y publicación.
Prioridad: Juego funcional, escalable, históricamente fundamentado, compatible con Android y sin costes obligatorios.
Responsable del proyecto: Usuario no programador que necesita instrucciones claras y resultados verificables.

---

1. TU PAPEL COMO DESARROLLADOR

Actúa como un equipo multidisciplinar formado por:

- Director técnico de videojuegos.
- Programador sénior de Godot y GDScript.
- Diseñador de juegos de estrategia, gestión y Idle Tycoon.
- Especialista en simulaciones económicas.
- Diseñador de sistemas de población, logística y comercio.
- Historiador especializado en Eurasia medieval.
- Diseñador de interfaces táctiles para Android.
- Especialista en rendimiento, persistencia y pruebas automatizadas.
- Responsable de documentación y control de calidad.

Tu responsabilidad es ayudarme a construir el videojuego completo Reinos Tycoon, no solo diseñarlo.

Debes convertir esta especificación en un proyecto real, implementable, documentado, probado y ampliable.

No te limites a explicar cómo se programaría. Cuando dispongas de acceso efectivo al repositorio y las herramientas necesarias, crea y modifica los archivos, ejecuta las pruebas disponibles, corrige errores y prepara entregas funcionales.

Si trabajas desde un chat que no permite modificar archivos directamente, genera los archivos completos por entregas pequeñas y explica dónde guardarlos.

Nunca afirmes haber creado, modificado, ejecutado o probado algo si realmente no lo has hecho.

Reglas fundamentales

1. El proyecto debe ser independiente.
2. El nombre oficial es Reinos Tycoon.
3. El coste obligatorio de desarrollo, ejecución y juego debe ser 0 €.
4. El juego debe funcionar sin conexión a Internet.
5. Android es la plataforma prioritaria.
6. La simulación debe ser profunda, pero el código debe seguir siendo mantenible.
7. Los datos históricos deben estar separados de la lógica del juego.
8. No construyas todos los sistemas a la vez.
9. No sacrifiques la estabilidad para añadir funciones.
10. No elimines ni sustituyas funcionalidades existentes de otro proyecto.
11. No inventes hechos históricos ni resultados de pruebas.
12. Todo sistema debe tener criterios de aceptación verificables.
13. Cada versión debe poder ejecutarse y probarse.
14. No avances a la siguiente fase si quedan errores críticos en la anterior.
15. Si detectas una contradicción en esta especificación, documenta el problema y propone la solución más sencilla y segura.

---

2. IDENTIDAD Y SEPARACIÓN DE PROYECTOS

Ya existe otro videojuego llamado Reinos.

Ese proyecto es independiente y debe permanecer intacto.

El nuevo videojuego se llama exclusivamente Reinos Tycoon.

Repositorio previsto: "reinos-tycoon".

No reutilices, sobrescribas, renombres ni elimines archivos del proyecto Reinos. No asumas que sus sistemas, código o recursos son reutilizables.

Si se identifica alguna posibilidad de reutilización, presenta una propuesta separada y espera autorización antes de aplicarla.

Todo lo creado en este encargo pertenece a Reinos Tycoon.

Antes de programar:

1. Confirma que estás trabajando en el repositorio correcto.
2. Comprueba la estructura real del proyecto.
3. Verifica el motor y las herramientas disponibles.
4. Crea o documenta una copia de seguridad inicial.
5. Establece una primera versión identificable.
6. No realices cambios destructivos sin autorización.

Si el repositorio todavía no existe, prepara los archivos iniciales y explícame cómo crear el repositorio gratuito en GitHub.

---

3. VISIÓN DEL VIDEOJUEGO

Reinos Tycoon será un juego de estrategia, construcción, economía, gestión territorial y progreso Idle ambientado aproximadamente alrededor del año 1000 d. C.

El jugador comenzará controlando un territorio pequeño y deberá transformarlo progresivamente en una potencia regional, un reino extenso o una federación de territorios.

La experiencia debe combinar:

- Gestión económica.
- Construcción y mejora de asentamientos.
- Agricultura y producción industrial.
- Población y necesidades.
- Gestión de trabajadores.
- Almacenamiento y distribución de recursos.
- Comercio regional e internacional.
- Rutas terrestres, fluviales y marítimas.
- Desarrollo tecnológico.
- Administración provincial.
- Diplomacia.
- Ejércitos y guerra.
- Conquista e integración territorial.
- Automatización.
- Progreso durante la ausencia del jugador.
- Objetivos a largo plazo.
- Eventos históricos y emergentes.
- Desarrollo de dinastías como sistema avanzado.

No debe ser un simple clicker basado en pulsar botones para conseguir monedas.

El jugador debe tomar decisiones económicas y estratégicas que tengan consecuencias comprensibles.

Bucle principal

El bucle de juego será:

Producción → recursos → población → necesidades → excedentes → comercio → ingresos → infraestructura → tecnología → capacidad militar y administrativa → expansión → integración → automatización → nuevas oportunidades.

La expansión debe crear nuevos problemas que obliguen al jugador a mejorar su economía, sus rutas, sus reservas y su administración.

Conquistar un territorio no debe equivaler a obtener inmediatamente todos sus beneficios.

Experiencia objetivo

El juego debe ofrecer:

- Progreso perceptible en los primeros minutos.
- Decisiones interesantes durante las primeras horas.
- Automatización progresiva.
- Desarrollo territorial a medio plazo.
- Objetivos que puedan prolongarse durante meses de juego.
- Sistemas combinables que permitan partidas diferentes.
- Capacidad de jugar de manera activa o regresar tras varias horas.
- Ausencias sin castigos desproporcionados.

No impongas una duración artificial. El objetivo es que el mundo y la economía sigan teniendo interés a largo plazo.

---

4. PRINCIPIOS DE DISEÑO

4.1 Profundidad con reglas comprensibles

Cada sistema debe poder explicarse al jugador mediante información visible.

Si una fábrica no produce, el juego debe indicar por qué.

Si una ciudad pasa hambre, debe mostrar qué recurso falta.

Si una ruta comercial deja de ser rentable, debe explicar el coste, los precios y las pérdidas.

Si un ejército pierde, debe ofrecer un resumen de los factores relevantes.

4.2 Especialización territorial

Las provincias deben diferenciarse por su geografía, recursos, población, infraestructura y situación política.

No deben existir provincias idénticas que solo cambien de nombre.

4.3 Consecuencias reales

Los sistemas deben estar conectados.

Ejemplos:

- Reclutar trabajadores puede reducir la producción agrícola.
- Una mala cosecha puede reducir las reservas y aumentar los precios.
- Una guerra puede interrumpir el comercio.
- Un puente puede reducir el coste de una ruta.
- Una mina necesita mano de obra, combustible y transporte.
- Un puerto puede facilitar el comercio y el abastecimiento.
- Una conquista puede aumentar los ingresos y, al mismo tiempo, los costes administrativos.
- Una provincia insegura puede perder población y comercio.

4.4 Automatización progresiva

El jugador debe poder automatizar tareas repetitivas, pero no debe disponer de control automático perfecto desde el principio.

La automatización será una recompensa de desarrollo.

4.5 Evitar la complejidad inútil

No simules individuos, objetos físicos o movimientos de mercancías unidad por unidad cuando un modelo agregado produzca resultados suficientes.

Prioriza modelos económicos coherentes y eficientes.

---

5. AMBIENTACIÓN HISTÓRICA Y CRONOLOGÍA

La fecha de referencia será aproximadamente el año 1000 d. C.

La primera versión histórica debe utilizar una fecha de referencia explícita, por ejemplo el año 1000, y no mezclar automáticamente entidades de siglos distintos.

La cronología será ampliable, pero no se implementará una simulación completa de todos los siglos desde el principio.

Reglas históricas

Distingue siempre:

- Hechos documentados.
- Reconstrucciones históricas.
- Inferencias geográficas.
- Simplificaciones jugables.
- Decisiones de diseño.

No inventes fuentes, fronteras, asentamientos ni recursos históricos.

Las fronteras del periodo medieval pueden ser inciertas o disputadas. Representa esa incertidumbre mediante control directo, vasallaje, influencia y fronteras no consolidadas.

No proyectes las fronteras de los estados actuales sobre el mapa medieval.

Poderes políticos que investigar

Investiga las entidades que correspondan cronológicamente a la fecha seleccionada, incluyendo cuando proceda:

- Inglaterra, Escocia, Gales e Irlanda.
- Califato de Córdoba y poderes cristianos ibéricos.
- Reino de Francia y Sacro Imperio.
- Italia y poderes regionales.
- Imperio bizantino y Bulgaria.
- Rus de Kiev.
- Polonia y Hungría.
- Poderes del norte de África.
- Califato abasí y dinastías regionales de Oriente Próximo.
- Poderes iranios.
- Samaníes, Karajánidas, Gaznávidas y otros poderes de Asia Central según sus fechas de existencia.
- Dinastía Song del Norte y Liao.
- Goryeo.
- Japón del periodo Heian.
- Reinos y dinastías regionales de India.

Esta lista es un plan de investigación, no una lista definitiva de entidades simultáneas.

Antes de incorporar una entidad al mapa, verifica su existencia y situación política en la fecha de referencia.

---

6. GEOGRAFÍA Y MAPA DEL MUNDO

Objetivo final

El mundo debe extenderse progresivamente desde Europa occidental hasta Asia oriental, incluyendo las regiones relevantes para el comercio, la guerra y el desarrollo histórico del periodo.

Debe contemplar:

- Islas británicas.
- Península ibérica.
- Europa occidental y central.
- Escandinavia.
- Europa oriental.
- Balcanes.
- Mediterráneo.
- Norte de África.
- Anatolia.
- Cáucaso.
- Mesopotamia.
- Persia.
- Arabia.
- Asia Central.
- Norte y sur del subcontinente indio.
- Norte de China.
- Sur de China.
- Corea.
- Japón.
- Regiones de estepa y corredores comerciales intermedios.

Geografía física

El mapa debe representar:

- Montañas.
- Llanuras.
- Bosques.
- Estepas.
- Desiertos.
- Ríos.
- Lagos.
- Costas.
- Islas.
- Pasos montañosos.
- Oasis.
- Tierras agrícolas.
- Puertos naturales.
- Regiones mineras.

Los principales sistemas geográficos deben afectar a la economía y la logística.

Las montañas pueden dificultar el transporte; los ríos pueden facilitarlo; los desiertos pueden exigir abastecimiento; las costas pueden permitir rutas marítimas.

No todos los terrenos deben ser atravesables por todas las unidades.

Escala

El objetivo final es disponer de cientos de provincias si el rendimiento y la calidad del contenido lo permiten.

No fijes un número definitivo antes de probar el motor.

El MVP comenzará con 10–20 provincias. La estructura debe permitir ampliar el mapa mediante datos sin reescribir la lógica.

Capas de información

El mapa tendrá, progresivamente:

1. Capa política.
2. Capa geográfica.
3. Capa de recursos.
4. Capa de producción.
5. Capa comercial.
6. Capa de rutas y abastecimiento.
7. Capa militar.
8. Capa de seguridad y lealtad.
9. Capa de población.
10. Capa de infraestructura.

Cada capa debe poder activarse y desactivarse.

---

7. IDENTIDAD VISUAL

El estilo deseado es un atlas medieval de alta calidad.

Debe transmitir:

- Pergamino envejecido.
- Tinta y líneas dibujadas.
- Relieve geográfico.
- Montañas y bosques ilustrados.
- Ríos reconocibles.
- Fronteras pintadas.
- Símbolos de ciudades y fortalezas.
- Emblemas originales de los poderes políticos.
- Rutas terrestres y marítimas.
- Etiquetas geográficas legibles.

Paleta

Prioriza:

- Sepias.
- Ocres.
- Marrones.
- Verdes apagados.
- Azules grisáceos.
- Colores diferenciados para los poderes políticos.
- Tonos más intensos para alertas críticas.

Evitar

- Aspecto infantil.
- Estética futurista.
- Interfaz excesivamente recargada.
- Exceso de efectos.
- Grandes animaciones que perjudiquen el rendimiento.
- Mapas donde las fronteras y los nombres sean ilegibles.

Niveles de zoom

Continental: reinos, regiones, grandes ciudades y rutas principales.

Provincial: límites provinciales, recursos, asentamientos, carreteras, puentes y fortalezas.

Local: edificios, campos, talleres y elementos de producción cuando el nivel de detalle lo permita.

No es obligatorio crear una vista local tridimensional. La prioridad es una representación eficiente, coherente y atractiva.

---

8. PROVINCIAS Y TERRITORIOS

Cada provincia tendrá un identificador estable.

Su ficha debe poder incluir:

- Nombre.
- Variantes históricas del nombre.
- Región.
- Terreno.
- Clima.
- Superficie útil.
- Fertilidad.
- Disponibilidad de agua.
- Bosques.
- Recursos potenciales.
- Recursos explotados.
- Población.
- Vivienda.
- Mano de obra.
- Seguridad.
- Lealtad.
- Infraestructura.
- Edificios.
- Almacenes.
- Producción.
- Consumo.
- Importaciones.
- Exportaciones.
- Rutas.
- Gobernador.
- Guarnición.
- Control político.
- Impuestos.
- Costes administrativos.
- Fuentes históricas.
- Nivel de confianza de los datos.

Especialización

Ejemplos de provincias especializadas:

- Granero regional.
- Centro ganadero.
- Zona forestal.
- Distrito minero.
- Ciudad artesanal.
- Puerto comercial.
- Paso militar.
- Oasis.
- Centro religioso.
- Capital administrativa.

Una provincia puede combinar varias funciones.

La especialización debe surgir de la geografía, la infraestructura y las decisiones del jugador.

---

9. SISTEMA DE RECURSOS

Diseña un catálogo ampliable de mercancías.

9.1 Alimentos

- Trigo.
- Cebada.
- Centeno.
- Avena.
- Arroz donde corresponda.
- Legumbres.
- Verduras.
- Frutas.
- Pescado.
- Carne.
- Huevos.
- Leche.
- Queso.
- Miel.

9.2 Agua

- Agua de pozo.
- Agua de río aprovechable.
- Cisternas.
- Canales.
- Infraestructura hidráulica.

El agua puede modelarse como capacidad y disponibilidad local, no necesariamente como mercancía transportable en todos los casos.

9.3 Recursos forestales

- Troncos.
- Madera.
- Leña.
- Carbón vegetal.

9.4 Minerales

- Hierro.
- Cobre.
- Estaño.
- Plomo.
- Plata.
- Oro.

Los depósitos deben depender de la geología y de la evidencia disponible. No coloques todos los minerales en todas las regiones.

9.5 Construcción

- Piedra.
- Arcilla.
- Ladrillos.
- Cal.
- Tejas.

9.6 Textiles

- Lana.
- Lino.
- Algodón.
- Seda.
- Tintes.
- Tejidos.

Su distribución debe corresponder a las regiones y tecnologías apropiadas.

9.7 Ganadería

- Caballos.
- Bueyes.
- Ovejas.
- Cabras.
- Cerdos.
- Camellos donde sean apropiados.

Los animales pueden representar ganado productivo, capacidad de transporte o recursos militares.

9.8 Manufacturas

- Harina.
- Pan.
- Herramientas.
- Cuero.
- Cerámica.
- Vidrio.
- Papel cuando corresponda.

9.9 Comercio especializado

- Especias.
- Incienso.
- Perfumes.
- Pieles.
- Productos de lujo documentados.

9.10 Recursos institucionales

- Moneda.
- Conocimiento.
- Legitimidad.
- Influencia diplomática.

No trates todos estos recursos como mercancías físicas.

Reglas

Cada recurso tendrá:

- ID.
- Nombre traducible.
- Categoría.
- Unidad abstracta.
- Posibles fuentes de producción.
- Usos.
- Requisitos de almacenamiento.
- Durabilidad, si corresponde.
- Distribución regional.
- Valor de referencia.
- Fuente histórica cuando sea necesaria.
- Nivel de confianza.

El catálogo final puede contener decenas de recursos. El MVP debe comenzar con 8–12 mercancías esenciales.

---

10. ECONOMÍA Y CADENAS DE PRODUCCIÓN

La economía debe respetar la conservación de recursos.

Ningún edificio puede producir mercancías sin disponer de sus requisitos.

La fórmula conceptual de balance provincial será:

Existencias finales = existencias iniciales + producción + importaciones − consumo − exportaciones − pérdidas.

Las transferencias internas deben registrarse correctamente para evitar duplicar recursos.

Cadena agrícola

Cultivo → cosecha → granero → molino → harina → panadería → consumo o mercado.

Cadena forestal

Bosque → tala → troncos → aserrado o transformación → madera o leña → construcción y consumo.

Cadena metalúrgica

Mineral → combustible → fundición → metal trabajado → herrería → herramientas y armas.

Cadena textil

Ganadería o cultivo apropiado → materia prima → transformación → tejido → mercado o consumo.

Edificios productivos

Cada edificio debe definir:

- Coste inicial.
- Requisitos de construcción.
- Mano de obra.
- Insumos.
- Producción base.
- Intervalo de producción.
- Coste de mantenimiento.
- Almacenamiento.
- Mejoras.
- Efectos sobre otros sistemas.
- Condiciones de parada.

Estacionalidad

La agricultura debe tener temporadas y cosechas.

El calendario y la intensidad estacional deben ser simplificaciones jugables, salvo que exista información histórica suficiente para un modelo más preciso.

Agotamiento y regeneración

- Las minas pueden agotarse.
- Los bosques pueden regenerarse.
- Los pastos tienen capacidad.
- Los animales requieren agua y alimento.
- Los productos perecederos pueden deteriorarse.
- Las manufacturas necesitan insumos y transporte.

---

11. POBLACIÓN Y TRABAJO

La población será agregada por provincia y por categorías.

Categorías iniciales:

- Campesinos.
- Artesanos.
- Comerciantes y transportistas.
- Funcionarios.
- Nobles.
- Clero y comunidades religiosas según corresponda.
- Soldados.

No es necesario representar individualmente a cada persona.

Necesidades

- Alimentación.
- Agua.
- Combustible.
- Vivienda.
- Seguridad.
- Vestimenta.
- Empleo.
- Estabilidad.

Variables

- Población total.
- Trabajadores disponibles.
- Trabajadores asignados.
- Capacidad residencial.
- Bienestar.
- Seguridad.
- Descontento.
- Crecimiento.
- Migración.
- Mortalidad abstracta cuando sea necesaria para el modelo.

Prioridades laborales

El sistema debe priorizar de forma configurable:

1. Necesidades esenciales.
2. Producción alimentaria.
3. Agua y mantenimiento.
4. Edificios e industria.
5. Comercio y transporte.
6. Administración.
7. Ejército.

La prioridad exacta debe ser configurable y visible.

Reclutar demasiado debe reducir la disponibilidad de trabajadores civiles.

Crisis

La escasez debe tener consecuencias graduales.

El hambre no debe producir automáticamente la desaparición de una provincia por un único intervalo de cálculo.

Debe haber avisos, reservas, oportunidades de importar y decisiones para recuperarse.

---

12. ASENTAMIENTOS Y CONSTRUCCIÓN

Tipos de asentamiento:

- Aldea.
- Pueblo.
- Ciudad.
- Capital regional.
- Puerto.
- Castillo.
- Fortaleza.
- Puesto comercial.
- Puesto caravanero.

No todas las provincias necesitan una gran ciudad.

Familias de edificios

Residenciales

Viviendas y ampliaciones de capacidad.

Agrícolas

Granjas, campos y explotaciones ganaderas.

Almacenamiento

Graneros, depósitos y almacenes especializados.

Agua

Pozos, cisternas, canales y sistemas de abastecimiento.

Forestales

Leñadores y aserraderos cuando corresponda.

Mineros

Minas y dependencias de transformación.

Industriales

Molinos, herrerías, talleres y manufacturas.

Comerciales

Mercados, almacenes comerciales, puertos y puestos de intercambio.

Administrativos

Edificios de gestión y recaudación.

Culturales y religiosos

Edificios adecuados a la región y a la cronología.

Militares

Cuarteles, fortificaciones, arsenales y estructuras de apoyo.

Infraestructura

Carreteras, puentes, puertos y mejoras logísticas.

Reglas de construcción

Cada construcción debe mostrar:

- Precio.
- Recursos necesarios.
- Tiempo restante.
- Efecto esperado.
- Requisitos.
- Mano de obra.
- Costes de mantenimiento.

No permitas iniciar construcciones imposibles.

Las mejoras deben tener rendimientos comprensibles y no generar inflación descontrolada.

---

13. ALMACENAMIENTO Y DISTRIBUCIÓN

Cada provincia y edificio debe respetar sus capacidades.

Si un almacén está lleno, la producción debe detenerse, reducirse o dirigirse a otro destino permitido.

No permitas que los recursos se dupliquen al transferirlos entre almacenes.

Debe existir una vista que muestre:

- Exist