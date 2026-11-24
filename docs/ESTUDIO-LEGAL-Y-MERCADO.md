# Intimae: estudio legal, de mercado y hoja de ruta

Fecha: 24 de noviembre de 2026. **No es asesoría legal.** Es una investigación con fuentes públicas para que llegues a un abogado con las preguntas correctas.

Cada afirmación lleva una etiqueta de confianza:
- **[Certeza]**: respaldada por una fuente que he leído en esta investigación.
- **[Probable]**: inferencia fuerte o conocimiento general, sin fuente verificada ahora.
- **[Suposición]**: relleno de huecos. Hay que comprobarlo.

---

## 0. Lo incómodo primero

1. **La puerta de edad actual no vale como verificación real.** Es un botón de "soy mayor de edad". [Certeza] La Comisión Europea publicó el 29 de abril de 2026 la Recomendación (UE) 2026/1035 con un marco común de verificación de edad y pide a los Estados que ofrezcan un sistema fiable antes del 31 de diciembre de 2026. [Probable] Un simple clic es autodeclaración y no te protegerá si un regulador considera tu sitio "contenido adulto".
2. **Cobrar con tarjeta va a ser lo más difícil.** [Certeza] Stripe no admite contenido ni servicios para adultos como regla general, aunque sean legales donde operas. [Suposición] Lo mismo pasa con PayPal y la mayoría de pasarelas de uso general; no lo he verificado. Por eso el pago hoy es manual.
3. **Los datos de tus compradores pueden ser "vida sexual" (art. 9 RGPD).** [Certeza] Un tribunal administrativo de Wiesbaden (noviembre de 2025) consideró que comprar en un sex shop puede revelar datos sobre vida sexual. Es una sentencia de primera instancia, no vinculante en toda la UE. [Probable] Un pedido de lencería usada "con carácter erótico" cae en la misma zona. Exige consentimiento explícito, separado y no premarcado.
4. **Dejas de ser "una tienda" y pasas a ser un marketplace.** [Certeza] Eso activa obligaciones propias: el DSA (identificar y verificar a vendedores profesionales, sistema de denuncias), la directiva Omnibus (indicar si el vendedor es profesional o particular) y la DAC7 (comunicar a Hacienda a los vendedores que superen umbrales).
5. **El mayor riesgo real no es el papel, es la seguridad de las personas.** [Probable] Vendedores doxeados, acoso, documentos de identidad filtrados, menores que se cuelan y contenido ilegal. Una brecha con DNIs de vendedoras de este tipo de web sería un desastre reputacional y una sanción RGPD.
6. **Tu hosting también puede cerrarte.** [Suposición] No he comprobado la política de uso de Vercel sobre contenido adulto. Antes de invertir en tráfico, léela o migra a un proveedor europeo cuyas condiciones lo admitan.

---

## 1. Lo que tienes hoy

| Elemento | Estado | Nota |
|---|---|---|
| Web estática en Vercel (`intimae.vercel.app`) | Hecho | `noindex`, demo |
| Puerta de edad 18+ | Parcial | Autodeclaración. Ver punto 1 de arriba |
| Catálogo con 9 productos | Demo | Vendedores ficticios; fotos de Unsplash con crédito |
| Filtros por prenda, talla y uso; orden | Hecho | |
| Carrito (en el navegador) | Hecho | |
| Pedido | Parcial | Abre un email a `pedidos@example.com`. Sin backend |
| Alta de vendedor | Parcial | Abre un email. No verifica nada |
| Páginas legales (compradores: 7 + índice; vendedores: 2) | Borrador | Falta la titularidad. Revisión legal pendiente. Solo en español |
| 7 idiomas con detección por navegador y por país | Hecho | Sin revisión de nativos |
| Zona de vendedores separada (`/vendedores/`) con calculadora de comisión | Hecho | Comisión del 20 % como propuesta |
| Motor de IVA por vendedor y destino (`js/tax.js`) | Hecho (orientativo) | Particular, bienes usados, régimen general, exportación. Tipos de los 27 países |
| Destino de envío con selector y bloqueo de vendedores no UE | Hecho | Reino Unido, Suiza y Noruega: visibles, pedido bloqueado («próximamente») |
| Alta de vendedor con país, particular/profesional, número de IVA y régimen | Hecho | Solo valida formato; falta consulta VIES |
| Consentimiento explícito art. 9 RGPD en el pedido | Hecho | Casilla aparte, no premarcada |
| Pagos | No | Manual por email |
| Cuentas de usuario | No | |
| Verificación de edad real / identidad de vendedores | No | |
| Envíos reales y etiquetas | No | Solo hay texto informativo |
| Panel de administración y moderación | No | |
| Mensajería, reseñas, disputas | No | |
| Idiomas distintos del español | No | |
| Comunicación fiscal (DAC7) | No | |
| Emails reales | **Pendiente a petición tuya** | |

---

## 2. Competencia: lo que existe

La búsqueda dio poca información fiable sobre funciones concretas. Lo siguiente viene de las propias webs o de prensa; **no he podido verificar sus condiciones ni cumplimiento legal.**

| Sitio | Qué dice de sí mismo / qué consta | Fuente |
|---|---|---|
| Snifffr | "Marketplace de confianza para comprar y vender braguitas y ropa interior usada de forma anónima" | [Tumblr de Snifffr](https://www.tumblr.com/snifffr) |
| Worn Fantasy | Braguitas usadas de "modelos", transacciones "rápidas, seguras y anónimas", envío discreto y "un día de uso gratis" | [Tumblr de Worn Fantasy](https://www.tumblr.com/wornfantasycom/following) |
| PantyTrust | Activo desde principios de los 2000; las oleadas de vendedores suelen seguir a noticias que prometen ganancias | [Vice](https://www.vice.com/en/article/its-surprisingly-difficult-to-sell-your-panties-online) |
| ManyVids | Plataforma de contenido adulto donde algunas vendedoras montan tienda | [MEL Magazine](https://melmagazine.com/en-us/story/guys-sell-used-underwear-reddit-malepantyselling) |
| Sububis | Tienda creada en octubre de 2021 que vendía lencería usada; ~120 $ por prenda según una noticia | [Yahoo News](https://au.news.yahoo.com/online-shop-selling-used-tampons-to-strangers-lucrative-business-064613569.html) |

Lo que se ve en el sector:
- **[Certeza]** El modelo dominante es anonimato, envío discreto y ventas ligadas a actrices porno y fans.
- **[Certeza]** Vice titula que es "sorprendentemente difícil" vender braguitas en línea: las plataformas generalistas no suelen aceptarlo. [Suposición] eBay y similares lo prohíben; no lo he comprobado en sus normas actuales.
- **[Suposición]** Ninguno parece destacar el cumplimiento europeo (DSA, DAC7, verificación de edad y de vendedores). Si es así, ahí hay hueco: "el marketplace europeo, legal y seguro". Hay que verificarlo mirando sus webs directamente; no lo he hecho.

---

## 3. Todo lo que se podría integrar

Prioridad: **P0** imprescindible antes de operar con público, **P1** necesario al crecer, **P2** mejora.

### A. Cumplimiento legal en la UE

| Norma | Qué exige | Estado | Prio |
|---|---|---|---|
| **LSSI-CE art. 10** (España) | Datos del titular visibles: nombre, NIF, domicilio, email, datos registrales | Borrador hecho, falta titularidad | P0 |
| **RGPD** | Información al usuario, base legal por finalidad, registro de tratamientos, evaluación de impacto (probable por datos de vida sexual y DNIs), gestión de brechas, contratos con proveedores. Valorar delegado de protección de datos | Política redactada | P0 |
| **RGPD art. 9** | Consentimiento explícito, separado y no premarcado para datos de vida sexual. [Certeza] No sirve un "aceptar todo" ni la navegación como consentimiento | Redactado en política; falta implementarlo en el pedido | P0 |
| **Cookies (art. 22.2 LSSI)** | Hoy no usas cookies no técnicas. Si añades analítica, aviso con aceptar y rechazar al mismo nivel | Política hecha | P0 |
| **Consumidores: directiva 2011/83 y texto refundido español** | Información precontractual, 14 días de desistimiento, garantía | Redactado | P0 |
| **Excepción de higiene** | [Certeza] El art. 16(e) excluye bienes precintados no aptos para devolverse por higiene si se desprecintan tras la entrega. [Certeza] El Tribunal de Justicia (caso del colchón) la interpreta de forma restrictiva. [Suposición] No sé si le vale a la ropa interior usada | **Pregunta para el abogado** | P0 |
| **Garantía de bienes de segunda mano (España)** | [Certeza] Por defecto 3 años; se puede pactar menos pero nunca por debajo de 1 año. Solo vendedores profesionales; entre particulares rige el Código Civil | Redactado | P0 |
| **Directiva Omnibus** | [Certeza] El marketplace debe indicar si el vendedor es profesional o no, según su declaración, y avisar de que no se aplican las normas de consumo si no lo es. Explicar el reparto de obligaciones | Redactado; falta el campo en el alta y la etiqueta en cada anuncio | P0 |
| **DSA: obligaciones básicas** | Punto de contacto, condiciones claras, sistema de denuncias, motivación de decisiones, reclamaciones internas | Redactado en "Normas"; falta implementarlo | P0 |
| **DSA art. 30-32 (marketplaces)** | [Certeza] Recoger, verificar y conservar datos de los vendedores profesionales (nombre, dirección, teléfono, email) antes de que operen; diseñar la interfaz para que cumplan sus obligaciones | Redactado; falta implementarlo | P0 |
| **DSA: exención para micro y pequeñas empresas** | [Probable] Las micro y pequeñas empresas están exentas de parte de las obligaciones de plataformas y marketplaces (no de las básicas). Verificar con tu abogado si te alcanza | Pregunta para el abogado | P0 |
| **DAC7 (fiscal)** | [Certeza] Debes recoger datos fiscales de vendedores y comunicar a Hacienda a quienes superen 30 operaciones o 2.000 € al año (la fuente es contradictoria sobre si basta una u otra condición). Conviene usar la lectura estricta | Falta implementar | P1 |
| **IVA: ventanilla única (OSS)** | [Certeza] Umbral único de 10.000 € para ventas a distancia B2C en la UE; por encima, IVA del país del comprador, declarable por OSS. [Certeza] La plataforma se considera proveedor en importaciones de hasta 150 € o si el vendedor no es de la UE. [Probable] Los profesionales de bienes usados tienen un régimen especial de margen | Consultar asesor fiscal | P1 |
| **Reglamento P2B (2019/1150)** | [Probable] Si tienes vendedores profesionales: condiciones claras, preaviso de cambios, transparencia en cómo ordenas | Parcial | P1 |
| **Accesibilidad (EAA, desde 28/06/2025)** | [Certeza] Aplica a comercio electrónico. [Certeza] Hay exención para microempresas de servicios (menos de 10 empleados y hasta 2 M€). [Probable] El estándar práctico es WCAG 2.2 AA | Hacer aunque estés exento | P1 |
| **Verificación de edad** | [Certeza] Recomendación UE 2026/1035; en España, la AEPD tiene un sistema de verificación en el dispositivo (Ley 13/2022); en Francia, Arcom exige doble anonimato en webs porno. [Suposición] No sé si un marketplace de lencería usada cuenta como "pornográfico" en cada país | Falta. Sustituir el clic por verificación real | P0 |
| **Plataforma de resolución de litigios (ODR)** | [Certeza] Cerró el 20 de julio de 2025; ya no hay que enlazarla | Aplicado en las condiciones | — |
| **Protección de menores y contenido ilegal** | Tolerancia cero con abuso sexual infantil, retirada inmediata, aviso a autoridades | Redactado; falta el procedimiento operativo | P0 |
| **Dinero de vendedores (PSD2)** | [Probable] Si retienes fondos de compradores para pagar luego a vendedores (escrow) puedes necesitar licencia de entidad de pago, o usar un socio licenciado. [Suposición] Pocos socios admiten contenido adulto | Decidir modelo | P1 |

### B. Avisos y obligaciones específicas para vendedores

Ya redactado en `condiciones-vendedores.html`. Pendiente de implementar:
- Declaración obligatoria **profesional o particular** en el alta.
- **Verificación de identidad y edad** (documento oficial) antes de publicar.
- Recogida de **datos fiscales** (DAC7) y **datos de trazabilidad** (DSA).
- **Consentimiento escrito** de cualquier persona que aparezca en fotos y confirmación de que es mayor de edad.
- Guía de **seguridad personal**: alias, sin datos personales en paquetes ni mensajes, qué hacer ante acoso, eliminación de metadatos de fotos.
- Guía **fiscal** por país (qué declarar y cuándo se pasa a profesional).
- Política de **retención de pagos y disputas**, **comisión** y **preaviso** de cambios en condiciones.
- Canal de **apelación** si se suspende una cuenta, con motivación de la decisión.
- **Aviso de higiene** y obligación de sellar la prenda.
- [Probable] Acuerdo entre responsables del tratamiento sobre los datos de entrega del comprador que recibe el vendedor.

### C. Envíos a toda Europa

- **Zonas.** [Probable] Dentro de la UE, sin aduanas. Reino Unido, Suiza y Noruega requieren declaración de aduanas y pueden generar aranceles e IVA local.
- **Transportistas.** [Suposición] Correos, SEUR, GLS, DHL, UPS. No he verificado tarifas ni que acepten este tipo de envío.
- **Agregadores con API.** [Certeza] Sendcloud ofrece una API que cubre tarifas, creación de envíos, descarga de etiquetas, webhooks y recogidas, más de 170 transportistas y documentos de aduanas para envíos fuera de la UE. Su página muestra el plan Pro en 639-799 €/mes más 0,07 € por etiqueta, según el snippet y la región. Packlink PRO no apareció en la búsqueda; hay que consultarlo aparte.
- **Privacidad.** Embalaje neutro, remitente neutro (nunca la dirección personal del vendedor), puntos de recogida o taquillas, concepto neutro en el extracto bancario.
- **Etiquetas generadas por la plataforma**, seguimiento, seguro opcional y gestión de incidencias y devoluciones.
- **Reenvío vía hub** (el vendedor envía a un punto de la plataforma y esta reenvía) para proteger la dirección del vendedor. [Suposición] Aumenta coste y responsabilidad.

### D. Pagos y dinero

- **Hoy:** transferencia, Bizum, cripto, manual por email.
- **Siguiente:** una pasarela que admita contenido adulto. [Suposición] Existen procesadores especializados en "alto riesgo", pero no he verificado ninguno ni sus condiciones. Habrá que pedir cotización y leer sus listas de bienes prohibidos antes de comprometerse.
- Pago a vendedores por SEPA, **retención hasta confirmar entrega**, contracargos y antifraude, **moneda** (EUR, y GBP, CHF, SEK, DKK, PLN según países), **facturación** y recibos.

### E. Confianza y seguridad (lo que diferenciaría la web)

- **Verificación de vendedores** con un proveedor especializado, y distintivo visible.
- **Verificación real de edad para compradores** (app europea, proveedor, o credencial reutilizable), no un clic.
- **Moderación de imágenes:** detección automática de desnudos explícitos y comparación con listas de material de abuso infantil, más revisión humana.
- **Mensajería interna** con filtro de datos personales y de contacto externo.
- **Reputación y reseñas** verificadas (solo de compradores reales), sistema de **disputas** con mediación.
- **Seguridad técnica:** 2FA, cifrado de documentos de identidad con acceso mínimo y registro de accesos, borrado automático, copias de seguridad, pruebas de intrusión.
- **Protocolo de denuncia a autoridades** y respuesta a requerimientos.

### F. Funciones de marketplace

- Cuentas y perfiles de vendedor con alias, subida y gestión de anuncios, favoritos, búsqueda.
- **Peticiones personalizadas** (hoy solo hay un campo de texto), cupones, tarjetas regalo.
- Panel de administración: moderación, pedidos, disputas, vendedores, informes fiscales.
- Notificaciones por correo, **multiidioma** (español, inglés, alemán, francés, italiano, portugués, neerlandés) y multimoneda.
- Blog y guías (SEO limitado), programa de afiliados.
- [Suposición] La publicidad en Google y Meta para este contenido probablemente esté restringida; el crecimiento será orgánico, por correo y comunidades.

### G. Técnica recomendada para pasar de demo a producto

- Aplicación con base de datos en la **UE**, autenticación, almacenamiento **privado** para documentos y fotos, y **políticas de acceso por fila** para que cada usuario solo vea lo suyo.
- Tareas en segundo plano para verificación, notificaciones y generación de informes DAC7.
- **Hosting europeo** cuyas condiciones admitan contenido adulto.
- Analítica **sin enviar contenido de carritos** a terceros, política de seguridad de contenido (CSP), límites de peticiones, monitorización de errores sin datos personales.
- **Evaluación de impacto RGPD** antes de lanzar.

---

### H. IVA y vendedores de otros países

**Lo que he integrado:** cada vendedor tiene país, condición (particular o profesional) y régimen (ninguno, bienes usados o general). El comprador elige su país de destino y la ficha muestra el tratamiento. Los vendedores de fuera de la UE solo venden dentro de su país. Reino Unido, Suiza y Noruega se pueden consultar pero no pedir.

| Caso | Qué hace la web | Confianza |
|---|---|---|
| Vendedor particular | Sin IVA; precio final; no aplican normas de consumo | **[Certeza]** La directiva Omnibus exige indicar si el vendedor es profesional y avisar de que, si no lo es, no aplica el derecho de consumo ([Iubenda](https://www.iubenda.com/en/blog/implementing-the-omnibus-directive-for-online-marketplaces/)) |
| Dónde está la frontera particular/profesional | La decide el vendedor al registrarse | **[Certeza]** No hay un umbral único en la UE: pesa la regularidad de las ventas y cada país fija el suyo ([Catawiki](https://www.catawiki.com/en/help/seller-success-fee-vat/eu-vat-regulations-for-selling-on-catawiki)) |
| Profesional, régimen de bienes usados | «IVA incluido», sin desglosar | **[Probable]** Se confirma que las normas de ventas a distancia no aplican a bienes en margen y tributa el país de salida ([Catawiki](https://www.catawiki.com/en/help/seller-success-fee-vat/eu-vat-regulations-for-selling-on-catawiki)); no encontré el artículo de la directiva |
| Profesional, régimen general | IVA del país del vendedor, desglosado | **[Certeza]** Umbral único de 10.000 € para ventas a distancia B2C en la UE ([Portal OSS](https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en)) |
| Profesional por encima de 10.000 € | Documentado, **no implementado**: el precio debería cambiar según el país de destino | Pendiente (fase 2) |
| Márgenes y plataforma como «proveedor presunto» | El régimen de margen no se aplica si la plataforma actúa como proveedor | **[Certeza]** [Revenue (Irlanda)](https://www.revenue.ie/en/tax-professionals/tdm/value-added-tax/part10-special-schemes/vat-ecommerce-rules/deemed-supplier.pdf) |

**Vendedores de fuera de la UE: por qué se bloquean**
- **[Certeza]** Si el mercado facilita la venta de bienes importados de hasta 150 €, se le trata como proveedor a efectos de IVA; en ventas de vendedores no UE con bienes ya en la UE, a cualquier importe ([Avalara](https://www.avalara.com/us/en/learn/whitepapers/2021-eu-vat-ecommerce-reforms-guide-usversion.html)). Y puede responder solidariamente si sabía o debía saber que el vendedor incumplía ([Vertex](https://www.vertexinc.com/sites/default/files/2024-05/Practical-Implications-EU-eCommerce-VAT-Rules-eGuide-4.12.pdf)).
- **[Certeza]** Desde el 1 de julio de 2026 y hasta el 1 de julio de 2028 hay un derecho fijo de 3 € por artículo en envíos de hasta 150 €, también con IOSS ([Comisión Europea](https://trade.ec.europa.eu/access-to-markets/en/news/eu-applies-eu3-customs-duty-item-low-value-e-commerce-consignments)). Puede haber tasas de gestión adicionales aún provisionales.
- **[Probable]** El IOSS puede exigir un intermediario establecido en la UE según el país del vendedor ([Stripe](https://stripe.com/resources/more/ioss-and-eu-vat)); no he verificado qué países están exentos.
- **Decisión de producto:** hasta que haya registro IOSS, los vendedores no UE solo venden en su país. Es lo más barato y lo más seguro.

**Reino Unido, Noruega y Suiza: por qué «próximamente»**
- **[Certeza] Reino Unido:** para envíos de hasta 135 £, el mercado debe cobrar el IVA en el momento de la venta ([GOV.UK](https://www.gov.uk/guidance/vat-and-overseas-goods-sold-to-customers-in-the-uk-using-online-marketplaces)). Un documento oficial de 28 de octubre de 2026 propone ampliar esa responsabilidad a bienes ya en el Reino Unido; no he comprobado si está aprobado.
- **[Certeza] Noruega:** umbral de bajo valor de 3.000 NOK por artículo; los mercados pueden ser responsables; sin número VOEC, el envío se retiene en la frontera ([Aduana de Noruega](https://www.toll.no/en/corporate/import/the-voec-scheme)).
- **Suiza:** **[Suposición]** no encontré fuentes. Pendiente de investigar.
- **Consecuencia:** servir esos tres países implica registrarse como operador en cada uno. Es fase 3, con asesor.

**Tipos de IVA:** los 27 tipos generales están en `js/tax.js`. **[Certeza]** Confirmados con fuente: Hungría 27 %, Finlandia 25,5 %, Luxemburgo 17 %, Rumanía 21 % desde el 1 de agosto de 2025 ([PwC](https://taxsummaries.pwc.com/romania/corporate)), Estonia 24 % desde el 1 de julio de 2025 ([KPMG](https://kpmg.com/us/en/taxnewsflash/news/2025/07/tnf-estonia-increase-in-standard-vat-rate-effective-july-1-2025.html)), Eslovaquia 23 % y Bulgaria 20 % ([Tax Foundation](https://taxfoundation.org/data/all/global/value-added-tax-vat-rates-europe/)). **[Probable]** El resto por conocimiento general: contrastar con la base de datos de la Comisión antes de operar.

**Preguntas para el asesor fiscal**
1. ¿Cómo se trata la **comisión** de la plataforma (IVA y lugar de prestación) cuando el vendedor es particular, profesional de la UE o de fuera?
2. ¿Cuándo se me considera **proveedor presunto** si el vendedor de la UE envía dentro de la UE? ¿Solo con vendedores no UE?
3. Régimen de bienes usados en ventas a distancia intracomunitarias: ¿país de origen o de destino? ¿Qué artículo lo regula?
4. ¿Qué verificación del número de IVA (VIES) debo conservar para no responder solidariamente?
5. ¿Cuándo debo registrarme en el Reino Unido y en Noruega, y cuánto cuesta mantenerlo?
6. ¿Qué pasa con Suiza?

### I. Comisión de la plataforma

**Recomendación: 20 % sobre el precio de venta (sin envío) al vendedor, con mínimo de 2 € por venta y sin recargo al comprador.** Lanzamiento con 15 % durante los primeros 12 meses para los vendedores fundadores, y escalones a la baja cuando negocies mejor el procesador de pagos.

**Qué cobran otros** (todo de páginas de comparación, no de las condiciones oficiales de cada uno, salvo Vinted y Vestiaire):

| Plataforma | Comisión | Confianza |
|---|---|---|
| OnlyFans y Fansly | 20 % al creador ([Sirency](https://www.sirency.com/blog/fansly-vs-onlyfans-platform-comparison-2026)) | **[Probable]** |
| Passes / Fanvue | 10 % / 15 % el primer año y luego 20 % ([TechBullion](https://techbullion.com/onlyfans-vs-passes-vs-fansly-vs-fanvue-which-creator-platform-actually-pays-the-most-in-2026/)) | **[Probable]** |
| Poshmark | 20 % desde 15 $ ([Listperfectly](https://listperfectly.com/selling/reselling-fees-explained-2026/)) | **[Probable]** |
| Vestiaire Collective | 12 % según su ayuda; otras fuentes dan 12-25 % por tramos ([ayuda oficial](https://faq.vestiairecollective.com/hc/en-gb/articles/24659638721425-Seller-Selling-Fees)) | **[Certeza]** el 12 %, **[Suposición]** el resto |
| Vinted | 0 % al vendedor; el comprador paga una tarifa de protección, en EE. UU. «normalmente 5 % + 0,70 $» ([Vinted](https://www.vinted.com/help/342)) | **[Certeza]** |
| Mercari | 10 % ([Finder, vía Listperfectly](https://listperfectly.com/selling/reselling-fees-explained-2026/)) | **[Probable]** |

**Por qué no copiar el modelo de Vinted:** su comisión la paga el comprador. Con un ticket medio de unos 35 € y un procesador de alto riesgo, esa tarifa no cubre costes. Además, **[Probable]** mostrar al comprador un recargo que no estaba en el precio anunciado es una práctica problemática en la UE (obligación de precio total desde el principio).

**Cuentas por pedido de 35 €** (todo **[Suposición]**, para que cambies los números):

| Concepto | Hipótesis | € por pedido |
|---|---|---|
| Procesador de pagos | 6 % (las fuentes dan 4-8 %, y hasta 10 % en algunos casos: [Startups.co.uk](https://startups.co.uk/payment-processing/high-risk-merchant-accounts/)) | 2,10 |
| Fraude y contracargos | 1,5 % del volumen (umbral «excesivo» de Visa de 1,5 % según un proveedor: [Chargeflow](https://www.chargeflow.io/blog/high-risk-merchant-account-6f2cf); en el sector adulto se citan 2-5 %) | 0,53 |
| Verificación, moderación y soporte | 1,50 € por pedido (sin cotizar) | 1,50 |
| **Coste total** | | **4,13 (11,8 %)** |

| Modelo | Ingreso | Margen | % del volumen |
|---|---|---|---|
| Vendedor 20 % | 7,00 | 2,88 | 8,2 % |
| Vendedor 10 % + comprador 5 % + 0,50 € | 5,75 | 1,63 | 4,6 % |
| Estilo Vinted (comprador 5 % + 0,70 €, vendedor 0 %) | 2,45 | **−1,68** | pierde dinero |

- **Suelo:** con un procesador al 6 %, el **punto de equilibrio está en torno al 12 %** de comisión total. No bajes del 13-15 % hasta renegociar.
- **Sensibilidad:** con procesador al 10 % y 2 € de operación, el coste sube al 17 %, y un 20 % deja un 3 % de margen. Con procesador al 4 %, el coste baja al 9,8 %.
- **IVA sobre la comisión:** **[Suposición]** puede ser un servicio sujeto a IVA. Si el 20 % incluye IVA (por ejemplo 21 % en España), tu ingreso neto baja a un 16,5 % (5,79 € por pedido). Decide entre «20 % + IVA» y «20 % IVA incluido» con el asesor fiscal. La web lo muestra como «comisión orientativa, pendiente de confirmar».
- **Caja:** **[Probable]** los procesadores de alto riesgo suelen retener un 5-10 % durante 90-180 días. Es dinero que no puedes usar: calcula el capital de trabajo.
- **Por qué 20 % y no menos:** es el nivel al que ya están acostumbrados los vendedores del sector adulto (OnlyFans, Fansly) y deja margen para absorber costes que aún no sabemos. Bajar después es fácil; subir una comisión es lo que ahuyenta vendedores.
- **Riesgo:** **[Suposición]** si el vendedor es el factor escaso del mercado, un 20 % puede frenar la captación. Por eso el 15 % de lanzamiento.

### J. Idiomas y traducción

**Implementado:** 7 idiomas (español, inglés, francés, alemán, italiano, portugués, neerlandés). El idioma se elige así: **lo que la persona haya elegido a mano > idioma del navegador > país de entrega o de residencia > inglés**. El selector está en la primera pantalla (verificación de edad), en la cabecera y en el área de vendedores. Al cambiar el país de entrega (comprador) o de residencia (vendedor), la web sugiere el idioma de ese país salvo que se haya elegido uno a mano. Los precios, los países y los números salen con el formato de cada idioma.

- **Cobertura real:** **[Certeza]** estos 7 idiomas cubren los países más grandes, pero no los 24 idiomas oficiales de la UE. Los países sin traducción (por ejemplo Polonia, Suecia o Rumanía) no cambian el idioma: se mantiene el del navegador o el último elegido, y si no hay ninguno, inglés. Siguientes por tamaño de mercado: polaco, sueco, checo, rumano, griego, húngaro.
- **Cómo añadir uno:** copiar `tools/i18n/src/en.py` a `<código>.py`, traducir, añadir el código a `js/i18n.js` y ejecutar `python3 tools/i18n/build.py`. El script comprueba que no falte ni sobre ninguna clave y que se conserven los marcadores y enlaces.
- **Calidad:** **[Suposición]** las traducciones las he hecho yo, sin revisión de nativos. Antes de lanzar, que las revise una persona de cada idioma, sobre todo los textos fiscales.
- **Los documentos legales siguen solo en español.** **[Probable]** Es un riesgo real: varios países exigen que las condiciones de un contrato de consumo estén en su idioma (en Francia, la ley Toubon). Hace falta traducción jurídica profesional de, al menos, las condiciones de compra, la privacidad y el aviso legal por cada país donde vendas. Mientras tanto, la web avisa en el idioma del usuario de que el documento solo está en español.
- **Anuncios de los vendedores:** hoy los textos de las 9 piezas de demostración están traducidos a mano. Con vendedores reales, cada anuncio vendrá en el idioma del vendedor: hará falta traducción automática (por ejemplo, un servicio de traducción por API) y marcar el texto como «traducido automáticamente» con acceso al original.
- **Los correos de pedidos y de solicitudes llegan siempre en español** al equipo, con el idioma de la persona indicado.

### K. Separación entre zona de compradores y de vendedores

**Implementado:** la tienda (`/`) es solo para compradores: sin formulario de vendedor, sin sección de vendedores y sin documentos de vendedores. El área de vendedores (`/vendedores/`) tiene su propia cabecera oscura, su portada con calculadora de comisión, su solicitud, sus condiciones y su guía de impuestos. La única conexión desde la tienda es un enlace discreto en el pie. Los documentos compartidos (aviso legal, privacidad, cookies, normas) viven en la raíz.

- **Pendiente:** cuentas separadas con roles (un usuario que compra y vende), panel del vendedor, y separar también el subdominio (`vender.` en lugar de `/vendedores/`) si quieres que las zonas tengan políticas de cookies y de seguridad distintas.

## 4. Hoja de ruta propuesta

| Fase | Objetivo | Incluye | Depende de |
|---|---|---|---|
| **0 (hecha)** | Demo y textos legales | Web, catálogo demo, 7 documentos legales en borrador | |
| **1** | Operar a pequeña escala, en la UE, con pagos manuales | Titularidad, revisión legal, cuentas, alta de vendedores con verificación, anuncios, pedidos, envíos UE con etiqueta, panel básico, moderación | Abogado, proveedor de verificación |
| **2** | Cobros y cumplimiento fiscal | Procesador de pagos adulto, retención y pagos a vendedores, verificación de edad real, DAC7, IVA con cambio de precio por país de destino y consulta VIES | Decisión de modelo de dinero, asesor fiscal |
| **3** | Europa completa | Registro de IVA en Reino Unido y Noruega, estudio de Suiza, IOSS si se admiten vendedores no UE, multiidioma y multimoneda, reseñas y disputas, puntos de recogida | Fase 2 estable |

---

## 5. Datos de titularidad que faltan

Titular (persona o sociedad), NIF/CIF, domicilio, **correo(s)** (contacto, denuncias, autoridades, reclamaciones; pendiente por ahora), teléfono, datos registrales si es sociedad, nombre de dominio, ciudad de los tribunales, y los proveedores (pagos, verificación, hosting). Además: comisión, plazos de pago, tarifas y plazos de envío, plazo de garantía, hojas de reclamaciones, entidad de resolución alternativa si la hay.

---

## 6. Preguntas para el abogado

1. ¿Vale la excepción de higiene para prendas íntimas **de segunda mano** vendidas por profesionales?
2. ¿Dónde está el umbral entre "particular" y "profesional" en cada país en el que vas a vender?
3. ¿Estoy exento de las obligaciones de marketplace del DSA como micro o pequeña empresa?
4. ¿Cómo debo recoger el consentimiento explícito del artículo 9 sin romper el flujo de compra?
5. ¿Qué verificación de edad es obligatoria **hoy** en los países destino? ¿Cuenta mi sitio como "contenido pornográfico" en Francia, Alemania o Italia?
6. ¿Estoy sujeto a DAC7 y a partir de qué volumen?
7. ¿Necesito licencia de pagos si retengo fondos y los transfiero a vendedores?
8. ¿Qué tratamiento fiscal tiene mi comisión y el IVA de la intermediación?
9. ¿Cuándo tengo que nombrar un delegado de protección de datos?
10. ¿Qué responsabilidad tengo por el contenido de vendedores y cómo debo gestionar el material ilegal?

---

## 7. Fuentes

- Venta de braguitas usadas en línea: [Vice](https://www.vice.com/en/article/its-surprisingly-difficult-to-sell-your-panties-online), [Daily Beast](https://www.thedailybeast.com/the-dirty-panties-black-market-porn-stars-make-big-money-selling-their-underwear-to-superfans), [Snifffr (Tumblr)](https://www.tumblr.com/snifffr), [Worn Fantasy (Tumblr)](https://www.tumblr.com/wornfantasycom/following)
- DSA, trazabilidad de vendedores: [CCPC](https://www.ccpc.ie/enforcement-and-regulation/digital/the-digital-services-act), [Freshfields](https://technologyquotient.freshfields.com/post/102lx12/dsa-decoded-9-the-dsa-and-online-marketplaces), [Pinsent Masons: DSA y DAC7](https://www.pinsentmasons.com/out-law/analysis/kyc-the-eu-digital-services-act-adds-platforms-dac7-duties)
- DAC7: [Belastingdienst](https://www.belastingdienst.nl/wps/wcm/connect/en/business/content/information-for-platform-operators-dac7), [Vivid](https://vivid.money/en-de/blog/dac7/), [EMTA](https://www.emta.ee/en/node/382/chapter/44168/pdf)
- Desistimiento y excepción de higiene: [Directiva 2011/83, art. 16](https://www.legislation.gov.uk/eudr/2011/83/article/16), [Europe Consommateurs](https://www.europe-consommateurs.eu/en/shopping-internet/14-days-to-withdraw.html)
- Datos de vida sexual y compras: [Baker McKenzie](https://connectontech.bakermckenzie.com/sensitive-data-under-the-cjeus-spotlight-practical-implications/), [PPC Land: sentencia de Wiesbaden](https://ppc.land/german-court-finds-shopping-cart-data-may-qualify-as-sensitive-under-gdpr), [Autoridad irlandesa de protección de datos](https://dataprotection.ie/en/organisations/know-your-obligations/lawful-processing/special-category-data)
- Verificación de edad: [Better Internet for Kids](https://better-internet-for-kids.europa.eu/en/news/age-assurance-across-europe-how-countries-are-safeguarding-minors-online), [Taylor Wessing](https://www.taylorwessing.com/en/interface/2025/predictions-2026/enhancement-and-enforcement), [Arcom](https://www.arcom.fr/en/press/protection-persons-under-18-online-arcom-issues-formal-notice-five-eu-based-porn-sites)
- Aviso legal LSSI: [INCIBE](https://www.incibe.es/empresas/blog/aviso-legal-parte-importante-tu-web), [Legalitas](https://www.legalitas.com/actualidad/requisitos-legales-tienda-online)
- IVA y OSS: [Portal OSS de la Comisión](https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en), [Your Europe](https://europa.eu/youreurope/business/taxation/vat/one-stop-shop/indexamp_hr.htm)
- Omnibus y marketplaces: [Iubenda](https://www.iubenda.com/en/blog/implementing-the-omnibus-directive-for-online-marketplaces/)
- Accesibilidad: [CCPC](https://www.ccpc.ie/business/enforcement/accessibility/european-accessibility-act-guidelines-for-microenterprises/), [Taylor Wessing](https://www.taylorwessing.com/de/interface/2025/accessibility/key-eu-accessibility-act-exemptions-and-the-challenges-they-pose)
- Cierre de la plataforma ODR: [Reglamento (UE) 2024/3228](https://eur-lex.europa.eu/eli/reg/2024/3228/oj/eng), [Taylor Wessing](https://www.taylorwessing.com/en/insights-and-events/insights/2025/01/abolition-of-the-odr-platform)
- Pagos: [Stripe, negocios prohibidos y restringidos](https://support.stripe.com/questions/restricted-business-list-faqs), [404 Media](https://www.404media.co/stripe-cuts-off-platform-used-by-dominatrixes-wishtender/)
- Garantía de bienes de segunda mano (España): [Comunidad de Madrid](https://www.comunidad.madrid/node/118809), [Dirección General de Consumo](https://www.dsca.gob.es/es/consumo/novedades/derechos-compra-empresas-bienes-segunda-mano-reacondicionados)
- Envíos: [Sendcloud](https://www.sendcloud.com/enterprise/multi-carrier-delivery/)
