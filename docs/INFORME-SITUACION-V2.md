# Intimae · Informe de situación y propuesta de cambios (respuesta al Documento Maestro v2)

Fecha: 25-11-2026. Alcance: repositorio `ElProyecto91/reinos-tycoon` (rama `ccr-8e0f77d7-wzjkok`, commit `5e1e1d2`), proyecto Vercel `intimae` y web pública. **No se ha implementado nada nuevo**: solo auditoría y propuesta, como pide el apartado 26 del documento.

Etiquetas: **[Certeza]** comprobado en el código, en el sitio o con prueba; **[Probable]** inferencia fuerte; **[Suposición]** estimación mía; **[No verificado]** no he podido comprobarlo. Esto no es asesoramiento legal ni fiscal.

---

## 0. Primero lo incómodo: contradicciones que hay que resolver antes de seguir

1. **El Documento v2 contradice la instrucción anterior sobre reclamaciones.** Hace unos días me pediste que Intimae no gestionara devoluciones ni reclamaciones, y lo implementé (código y textos legales). El v2 (apartados 2.7, 15 y 17) pide un procedimiento de incidencias y prohíbe cláusulas del tipo «Intimae no se hace responsable de nada». Ya te advertí de ese riesgo. **Mi recomendación: el v2 manda.** Hay que revertir la política en el código y en las páginas legales; el sistema de incidencias del apartado 15 se diseña con alcance limitado a lo que Intimae puede cumplir. **[Certeza]** Hoy la web y el contrato describen lo contrario de lo que pide el v2.
2. **Lo que construí como «pago retenido hasta la entrega» choca con tus principios.** El v2 prohíbe custodiar dinero de terceros, una cartera propia y la palabra «escrow» si el proveedor no lo ofrece (apartados 2.8 y 8). Mi capa de demostración simula retención y liquidación diferida: sirve como maqueta, pero **el diseño real debe dejar la retención y el reparto al proveedor de pagos**, con sus reglas, y el texto no puede hablar de custodia. **[Certeza]** La UI actual habla de «pago retenido».
3. **La capa de demostración incumple varios criterios del v2 si se publica como está:** muestra 9 productos ficticios como si estuvieran a la venta (4.2), cambia estados de pedido y de pago desde el navegador (23: «nunca desde el navegador») y no tiene autorización en servidor. **[Certeza]** Es una maqueta de interfaz, no una base reutilizable tal cual.
4. **El «stack de referencia» del v2 (Next.js 14, TypeScript, Supabase) no existe en este repositorio.** Es HTML, CSS y JavaScript estáticos, sin build. El v2 dice «no migrar sin razón demostrable». La razón existe, pero es más estrecha de lo que parece: hace falta **servidor** (pagos, webhooks, autorización), no necesariamente Next.js. Ver sección 14.
5. **Comisión 8–10 %.** Con costes de procesamiento de alto riesgo, el punto de equilibrio que calculé (≈11,8 %) está por encima. Con un proveedor europeo «estándar» sería más bajo (ver sección 13), pero hoy no hay ninguno confirmado. Sin confirmación, el 8–10 % es una hipótesis sin respaldo.
6. **Posible acceso restringido a la web.** El proyecto Vercel tiene `ssoProtection` activado (`all_except_custom_domains`). **[Probable]** Quien abra `intimae.vercel.app` sin sesión de Vercel puede encontrar una pantalla de acceso en lugar de la tienda. **[No verificado]** (no puedo abrirla como visitante anónimo desde aquí). Compruébalo tú desde una ventana privada del móvil. Si es así, ninguna IA ni persona ajena a tu cuenta puede auditar la web pública.

---

## 1. Qué comprobé y qué no

- **Comprobado:** código del repositorio; 35 comprobaciones de navegador automatizadas sobre flujos completos (compra, vendedor, moderación, DAC7, Canarias, idiomas, móvil); configuración del proyecto Vercel (sin variables de entorno, sin dominio propio, sin `vercel.json`); disponibilidad pública de archivos.
- **No comprobable:** Supabase (existe un host `…supabase.co` que responde 401 sin clave, pero no hay credenciales ni vínculo con este repositorio); webhooks, funciones, Edge Functions y políticas RLS reales (no existen en el repositorio); accesibilidad con herramienta formal; rendimiento medido en dispositivos reales; acceso anónimo a la web.

---

## 2. Inventario de funciones, clasificado

Categorías: **F** funcional · **P** parcial · **S** solo visual o simulada · **N** no implementada · **I** insegura · **J** necesita revisión jurídica · **?** no se puede comprobar. En esta tabla, «funcional» significa que cumple su papel en producción; lo que solo funciona en la capa de demostración local cuenta como **S**.

| Área | Estado | Comentario |
|---|---|---|
| Estructura y rutas (tienda, cuenta, vendedores, panel, admin, legales) | F | 15 páginas; estáticas; sin framework |
| Framework y versiones | N | No hay Next.js ni build. El ajuste de Node 26.x de Vercel no se usa |
| Componentes reutilizables | P | Ayudas en JS plano (`ui.js`); no hay sistema de componentes |
| Registro e inicio de sesión | S, I | `core.js` en el navegador; hash SHA-256 con sal corta, sin derivación de claves |
| Confirmación de correo, recuperación de contraseña, MFA | N | |
| Perfiles | P, S | Comprador y vendedor básicos; no hay tienda pública del vendedor |
| Roles y permisos | S, I | El rol de administración es una marca en `localStorage` |
| Productos y publicaciones | S | Crear, editar, pausar, eliminar; faltan duplicar, borrador, stock, historial |
| Catálogo público | S, J | 9 productos ficticios mostrados como reales; fotos de Unsplash con marcas visibles en dos |
| Pedidos | S | 5 estados (el v2 pide 11); registro de cambios sí |
| Pagos | S | Proveedor simulado; sin webhooks, idempotencia ni conciliación |
| Reembolsos, contracargos, disputas | N | Solo cancelación antes del envío |
| Comisiones | S | Fija en ajustes; sin facturación de la comisión |
| Panel de administración | S, I | Sin autenticación real; contraseña de demostración en el código |
| Panel de vendedor | P, S | Faltan estadísticas, tienda, verificación real, incidencias, ayuda |
| Formularios | P | Validación solo en el cliente |
| Mensajería | P, S | Hilos, no leídos, bloqueo de contactos por patrón; faltan bloquear usuario, denunciar mensaje, límites por cuenta nueva, avisos por correo |
| Notificaciones | N | Solo contadores en pestañas |
| Búsqueda y filtros | P | Texto, prenda, talla, uso y orden. Faltan precio, color, estado, país, valoración, vendedor verificado, autocompletado |
| Favoritos | S | Funciona en local |
| Valoraciones | P, S | Una por pedido entregado; faltan criterios (5), respuesta del vendedor, moderación e historial |
| Trust Score | N | |
| Denuncias de contenido | P, S | Con número y exposición de motivos; faltan denunciar vendedor/comprador, apelación, reincidencias |
| Imágenes y almacenamiento | S, I | Fotos en `localStorage`; reducidas a 900 px y sin EXIF (ventaja); sin almacenamiento privado ni URLs firmadas |
| Verificación de edad | S | Declaración y verificación simulada; no guarda la fecha de nacimiento |
| Verificación de identidad | N | Solo datos fiscales declarados |
| Datos fiscales y DAC7 | P, J | Recogida y CSV; sin validación contra registros ni envío a la administración |
| Motor fiscal (IVA, margen, IGIC) | P, J | Orientativo; 27 países de la UE; Canarias solo envíos internos |
| Multidioma | P | Tienda y alta de vendedores en 7 idiomas (validados); cuenta, panel y admin solo en español |
| Supabase, PostgreSQL, RLS, funciones SQL, Edge Functions, API, webhooks | N / ? | `db/schema.sql` es un borrador **sin ejecutar** |
| Vercel | P | Despliegue manual; sin variables de entorno; sin cabeceras de seguridad propias |
| SEO | N | Las 15 páginas llevan `noindex`; no hay sitemap, robots, canonical, Open Graph ni datos estructurados (correcto mientras no se lance) |
| Diseño responsive | F | Sin desbordamiento horizontal a 390 px en tienda, cuenta, panel y admin |
| Accesibilidad | P | Etiquetas y foco cuidados; **[No verificado]** sin auditoría formal |
| Rendimiento | P | JS sin minificar (≈120 kB), fuentes propias (≈330 kB); fotos remotas |
| Errores de consola | F | Ninguno en las pruebas |
| Documentación legal | J | Borrador con datos de titularidad pendientes; **contradice el v2** (punto 0.1) |
| Pruebas | P | Las hice con un navegador automatizado, pero **no están en el repositorio** |

---

## 3. Respuestas a los 15 puntos del primer encargo

### 3.1 Qué funciona realmente
- Diseño, tipografías propias y navegación; responsive probado.
- Motor fiscal de IVA por vendedor y destino; datos del IVA general de la UE; aviso de países no abiertos.
- Pipeline de idiomas con validación automática.
- Separación comprador / vendedor / administración en rutas distintas.
- Consentimiento explícito (art. 9 RGPD) en el pedido.
- Reducción y limpieza de fotos antes de guardarlas.

### 3.2 Qué funciona parcialmente
Búsqueda y filtros, mensajería, valoraciones, denuncias, datos fiscales y DAC7, idiomas, panel de vendedor.

### 3.3 Qué es solo simulación
Cuentas y sesiones, pagos, retención y liquidación, verificación de edad, administración, favoritos, pedidos y todo lo que depende de `core.js`. Funciona en el navegador de cada persona y **no se comparte con nadie más**.

### 3.4 Qué falta
Servidor y base de datos reales; autenticación con correo, recuperación y MFA; pagos reales con webhooks; verificación de identidad; tienda pública del vendedor; seguimiento de envíos; notificaciones por correo; incidencias y disputas; Trust Score; estadísticas; SEO; panel de administración protegido; copias de seguridad; pruebas en repositorio.

### 3.5 Qué está mal diseñado
- Estados de pago y de pedido modificables desde el cliente.
- Texto de «pago retenido» que sugiere custodia.
- Catálogo con datos ficticios en la portada.
- La política «no gestionamos reclamaciones» (según el v2).
- Fotos de Unsplash con marcas visibles (una caja rosa de lencería de marca y un pintalabios con nombre) en dos productos de ejemplo.
- Una única clave de almacenamiento para datos de comprador, vendedor y administración.

### 3.6 Riesgos legales y fiscales
- **Procesadores de pago** (Stripe y otros restringen contenido adulto): sin confirmación escrita, el modelo B no es viable. Borrador de consulta en `docs/CONSULTA-PROCESADORES.md`.
- **Responsabilidad personal** del administrador de la SL: una SL no la elimina del todo. **[Probable]**
- **Canarias.** Está fuera del territorio de IVA y forma parte del territorio aduanero de la UE; el IGIC y los trámites de despacho (DUA) hay que validarlos con un asesor canario. Mi texto habla de «trámites aduaneros y fiscales»: debe afinarse con el asesor.
- **Servicio a consumidores desde Canarias:** posible alta en un régimen OSS para no establecidos en la UE. **[No verificado]**
- **DAC7:** no se asume que Intimae quede exenta por ser intermediaria; hay que revisar las exclusiones y sus requisitos con el asesor.
- **DSA:** puntos de contacto, notificación y acción, trazabilidad de comerciantes, motivos de las decisiones. Hay una parte hecha en la maqueta; falta el marco real y su revisión.
- **RGPD:** datos que pueden revelar vida sexual; evaluación de impacto probable; encargados de tratamiento; retención.
- **Consumo:** desistimiento con la excepción de higiene (art. 16.e de la Directiva 2011/83/UE, de lectura restrictiva); garantía; reclamaciones.
- **Verificación de edad:** la recomendación de 2026 de la Comisión apunta a verificación efectiva, no a una casilla.

### 3.7 Problemas de seguridad
1. **[Certeza]** Toda la autenticación y autorización está en el navegador: cualquier persona puede editar `localStorage`, hacerse administradora, cambiar estados de pago o de pedido y leer datos de la demostración.
2. **[Certeza]** Contraseña de administración en el código y en el README.
3. **[Certeza]** Hash SHA-256 con sal corta, sin función de derivación de claves; sin verificación de correo, recuperación, MFA, límites de intentos ni CAPTCHA.
4. **[Certeza]** Datos personales (nombre, dirección, correo) y fotos sin cifrar en `localStorage`.
5. **[Certeza]** Sin cabeceras de seguridad (CSP, anti-framing, política de referencias) porque no hay `vercel.json`. HSTS sí lo aplica Vercel.
6. **[Certeza]** Las fotos de ejemplo se cargan desde Unsplash: el navegador del visitante envía su IP a un tercero. Desaparece con fotos propias.
7. **[Certeza]** El bloqueo de correos y teléfonos en mensajes es solo un filtro de patrones: sirve como freno, no como control.
8. **[Probable]** Riesgo de XSS bajo hoy (el contenido de usuario se inserta como texto), pero el sistema de idiomas usa HTML de los diccionarios; si se importan traducciones automáticas hay que sanearlas.

### 3.8 Qué hacen mejor los competidores
Solo he leído páginas públicas de cuatro de seis, sin registrarme. Los datos de cada web son afirmaciones suyas.
- **Snifffr:** proveedor externo de verificación de edad; verificación manual con foto y nota; mensajería como motor de conversión; exige a los vendedores conservar documentos y consentimientos de quien aparezca; prohíbe imágenes generadas por IA.
- **PantyDeal:** tienda propia por vendedor, ranking y reseñas; modelo de suscripción en lugar de comisión.
- **The Panty Bank:** curación de vendedoras, vídeo de verificación por pedido, embalaje con remitente genérico, textos de política de seguridad y retirada de contenido.
- **Sofia Gray y All Things Worn:** protegidas por un desafío de Cloudflare. No las he analizado.
- **Underprivé:** solo vi metadatos.

### 3.9 Mejoras con mayor ventaja competitiva (verificable con lo que hay)
1. **Transparencia fiscal europea** por vendedor y destino (los tres competidores leídos no la muestran).
2. **Verificación y confianza explicadas** (distintivos separados: edad, identidad, tienda activa, experiencia, valoraciones verificadas).
3. **Tienda pública por vendedor** (donde PantyDeal y Sofia Gray compiten).
4. **Móvil primero** con navegación inferior.
5. **Privacidad logística**: remitente genérico, mínimo de datos, borrado programado (sin prometer anonimato absoluto).
6. **Idiomas** con traducciones revisadas.

### 3.10 Qué conservar
El diseño y las tipografías; el pipeline de idiomas con validación; el motor fiscal como base (con revisión); la separación de zonas; el consentimiento del art. 9; el flujo de moderación con motivos; el esquema SQL como punto de partida; la capa de demostración **como prototipo de interfaz y banco de pruebas de flujos**, no como backend.

### 3.11 Qué modificar
Catálogo (estado vacío atractivo, sin productos ficticios, o marcados como demostración); redacción de pagos (sin custodia ni «escrow»); política de reclamaciones e incidencias según el apartado 15; estados de pedido (ampliar a los de 9); búsqueda y filtros (apartado 5); portada y navegación (4.2 y 4.3); textos que prometen verificación; fotos de ejemplo con marcas.

### 3.12 Qué eliminar
`core.js` como «backend» (queda como prototipo hasta que exista el servidor); la contraseña de administración y su mención en el README; los datos y fotos de ejemplo cuando haya oferta real; cualquier texto legal que contradiga el funcionamiento.

---

## 4. Costes aproximados de servicios externos

Fuentes: búsquedas en páginas públicas del 25-11-2026. Cualquier cifra debe confirmarse en la página oficial o por escrito con el proveedor.

| Servicio | Coste | Fiabilidad |
|---|---|---|
| Vercel Pro | 20 $/mes por miembro, con 20 $ de uso incluido; el plan Hobby es solo para uso no comercial | [Fuente: web de Vercel] |
| Supabase Pro | 25 $/mes base: 8 GB de base de datos, 100.000 usuarios activos al mes, 100 GB de almacenamiento, 250 GB de salida de datos incluidos | [Fuente: documentación de Supabase] |
| Supabase Free | 500 MB de base de datos; pausa por inactividad | [Probable] |
| Stripe Connect | Con la plataforma fijando precios: 2 $ por cuenta activa al mes + 0,25 % + 0,25 por pago a vendedor (tarifas de EE. UU.; la de cada país puede variar) más el procesamiento; sector restringido | [Fuente: web de Stripe] |
| Mangopay | Sin tarifas públicas; terceros citan desde unos 249 €/mes de plataforma, ≈1,8 % + fijo por pago con tarjeta y desde 1 € por verificación | [Poco fiable: terceros] |
| Lemonway | Tarjeta 1,10 % + 0,25 € según su propia web, a verificar | [Fuente: web de Lemonway vía buscador] |
| Procesamiento de «alto riesgo» | 4–8 %, más reservas del 5–10 % | [Fuente: proveedores y blogs comerciales] |
| Verificación de edad e identidad | 0,5–2 € por verificación | [Suposición] |
| Correo transaccional | 0–20 €/mes | [Suposición] |
| Dominio | 10–15 €/año | [Suposición] |
| Seguro de responsabilidad civil y ciberseguridad | ≈ 40 €/mes | [Suposición] |
| Revisión legal y fiscal inicial | ≈ 4.800 € (SL, abogado, asesor, protección de datos, marca) | [Suposición] |

**Coste fijo mínimo orientativo** antes de pagos y marketing: unos **150–250 €/mes**, más pagos únicos. Ya está en `docs/AUDITORIA-INTIMAE.md` (sección 11) con el modelo de rentabilidad: **a 8–10 % de comisión solo es viable con un procesador de coste bajo, que hoy no existe confirmado.**

---

## 5. Arquitectura que recomiendo

**Mantener** el front estático actual, el sistema de idiomas y el diseño. **Añadir** lo mínimo que exige el servidor:
- **Supabase** (región UE): autenticación con correo verificado, base de datos con RLS, almacenamiento privado con URLs firmadas, funciones SQL.
- **Funciones serverless de Vercel (o Edge Functions de Supabase)** para lo que necesita secretos: pagos, webhooks firmados con idempotencia, verificación de edad y correo.
- **Next.js: no todavía.** La razón técnica real es el SEO de tiendas y categorías públicas, que se resuelve con páginas pre-generadas o renderizado en servidor. Recomiendo decidirlo al llegar a la fase 5, no ahora, porque migrar antes de tener pagos y usuarios añade coste sin reducir riesgo. **[Suposición de diseño]** Si prefieres Next.js desde el principio por ser el estándar que conoce Claude Code, es defendible; el riesgo es reescribir todo el front antes de saber si habrá pagos.
- **Pagos: no se diseña hasta tener la respuesta escrita** del procesador (apartado 8 del v2). La retención y el reparto los hace el proveedor.
- **Pruebas** dentro del repositorio (permisos, webhooks duplicados, pagos fallidos, reembolsos), como pide el apartado 25.

---

## 6. Plan de desarrollo ordenado

| Fase | Contenido | Condición de salida |
|---|---|---|
| **0. Decisiones (sin código)** | Resolver los puntos 0.1 a 0.6; elegir política de incidencias; consulta a procesadores; asesor fiscal canario; abogado; plan Vercel Pro | Respuestas escritas del procesador y del asesor |
| **1. Base legal y operativa** | Contratos, política de incidencias, países habilitados, proveedor de verificación | Revisión de abogado y asesor aprobada |
| **2. Backend mínimo** | Supabase con RLS, autenticación real, almacenamiento privado, migración de la interfaz a la API, tienda pública del vendedor, filtros ampliados, retirada de datos de ejemplo | Pruebas de permisos en verde; sin datos en `localStorage` |
| **3. Operaciones** | Pagos reales con webhooks, comisiones, pedidos, seguimiento, incidencias, correo transaccional | Pruebas de pago, reembolso y disputa; un solo país |
| **4. Confianza** | Valoraciones verificadas, Trust Score, bloqueos, apelaciones, administración con MFA y auditoría | Revisión de seguridad |
| **5. Crecimiento** | SEO, vendedores fundadores, destacados, estadísticas, Next.js si procede | Oferta real publicada |
| **6. Internacionalización** | Países uno a uno, monedas, fiscalidad avanzada | Cada país revisado en pagos, fiscalidad, aduanas, consumo y privacidad |

---

## 7. Decisiones que necesito de ti

1. **Incidencias:** ¿el v2 sustituye a tu instrucción anterior? (mi recomendación: sí, y reviertes «no gestionamos reclamaciones»).
2. **Catálogo:** ¿retiro los productos ficticios de la portada y muestro el estado vacío del apartado 4.2, dejando los datos de ejemplo solo en modo demostración?
3. **Stack:** ¿mantenemos estático + Supabase + funciones, o prefieres Next.js desde ahora?
4. **Web pública:** ¿puedes abrir `intimae.vercel.app` en una ventana privada y decirme si ves la tienda o una pantalla de acceso de Vercel?
5. **Primer gasto:** ¿empezamos por la fase 0 (consulta a procesadores y asesor canario) antes de tocar código?
