# Auditoría de Intimae (apartado 14 del documento maestro)

Fecha: 24-11-2026. Alcance: el repositorio `ElProyecto91/reinos-tycoon`, rama `ccr-8e0f77d7-wzjkok`, y el sitio publicado en https://intimae.vercel.app.
Este documento **no desarrolla nada nuevo**: solo audita y propone. No es asesoramiento legal ni fiscal.

Etiquetas usadas: **[Verificado]** comprobado en el código o en el sitio; **[Fuente]** dato de una fuente citada, no contrastado por mí con la autoridad oficial; **[Hipótesis]** inferencia razonable; **[No verificado]** no he podido comprobarlo.

---

## 0. Corrección previa: el estado real no es el que dice el documento maestro

| El documento maestro dice | Realidad en el repositorio |
|---|---|
| Next.js 14 + Supabase + Vercel + GitHub | **[Verificado]** Web estática: HTML, CSS y JavaScript sin build ni dependencias. No hay Next.js, ni Supabase, ni base de datos, ni servidor propio. |
| Marketplace con pagos integrados (Modelo B) | **[Verificado]** No hay pagos, ni cuentas de usuario, ni panel de vendedor, ni mensajería, ni reseñas, ni disputas. El "pedido" abre un `mailto:` en el correo del comprador. |
| Mercados ES/FR/DE/IT | **[Verificado]** Catálogo con 9 productos **de demostración** y 9 vendedores **ficticios**. Fotos de muestra de Unsplash. El motor de IVA cubre 27 países UE; interfaz en 7 idiomas. |

Consecuencia práctica: si pegas el documento maestro en otra IA sin esta corrección, esa IA creerá que existe un backend que no existe. Pega primero el apartado 0 de este documento.

---

## 1. Auditoría funcional

### 1.1 Lo que funciona de verdad [Verificado, probado con navegador automatizado]
- Puerta de edad con selector de idioma en la primera pantalla.
- Detección de idioma (elección manual > navegador > país > inglés) y selector en todas las páginas; 7 idiomas (es, en, fr, de, it, pt, nl), 321 claves por idioma, validadas por script.
- Catálogo con filtros y ordenación, ficha de producto, carrito, cálculo de envío por vendedor (tarifas de demostración 4,90 / 7,90 / 14,90 €).
- Motor fiscal orientativo (`js/tax.js`): regímenes particular / bienes usados (margen) / general; zonas nacional / UE / exportación / bloqueada; vendedores no UE solo envían dentro de su país; destinos UK, NO y CH marcados "próximamente" y con pedido bloqueado.
- Separación comprador (`/`) y vendedor (`/vendedores/`): la tienda solo enlaza al área de vendedores desde el pie.
- Formulario de solicitud de vendedor con validación de NIF-IVA (formato).
- Casilla de consentimiento explícito (art. 9 RGPD) y de mayoría de edad en el pedido.
- Tipografías alojadas en el propio sitio (sin Google Fonts); sin cookies de terceros.

### 1.2 Lo que parece funcionar pero es solo visual o demostración
- **"Pedido"**: genera un correo en español dirigido a `pedidos@example.com` (marcador). No hay pedido registrado, ni pago, ni confirmación. [Verificado]
- **"Solicitud de vendedor"**: igual, un `mailto:` a `vendedores@example.com`. No se almacena nada. [Verificado]
- **Puerta de edad**: es una declaración con un clic. No verifica nada y no es un sistema de verificación de edad. [Verificado]
- **Productos, vendedores, valoraciones, fotos**: ficticios. [Verificado]
- **Textos de las páginas legales**: describen cosas que aún no existen (verificación de identidad, cifrado, cuentas, retención de pagos). Eso es un riesgo si se publicara tal cual. [Verificado]
- **Calculadora de comisión** del área de vendedores: usa 20 % (`COMMISSION_PCT` en `js/seller.js`); es una propuesta mía, no una decisión tuya. [Verificado]

> **Actualización (25-11-2026):** buena parte de esta lista ya existe **en modo demostración** (sin servidor): ver la sección 12. Lo que sigue describe el estado previo.

### 1.3 Lo que falta por completo [Verificado]
Cuentas y autenticación; base de datos; alta/edición de anuncios por el vendedor; subida de fotos; pagos y reparto a vendedores; custodia/liberación de fondos; seguimiento de envíos; mensajería; reseñas; disputas y devoluciones; panel de moderación y cola de denuncias; verificación de edad e identidad; registro de datos DAC7; facturación/justificantes; correo transaccional; copias de seguridad; registro de auditoría; recuperación de cuenta; panel de administración.

### 1.4 Otros hallazgos técnicos [Verificado]
- **Todo lo del repositorio se sirve públicamente** (también `docs/`, `tools/`, `screenshots/`). Mi estudio legal y esta auditoría serían accesibles por URL. Se corrige con `.vercelignore` (incluido en este cambio).
- El proyecto de Vercel no está enlazado a Git: cada cambio requiere un despliegue manual.
- **Vercel Hobby es solo para uso personal/no comercial** [Fuente: condiciones de Vercel]. Una tienda comercial necesita plan Pro. No encontré política específica de Vercel sobre contenido adulto [No verificado]: hay que preguntar por escrito.
- Accesibilidad: hay etiquetas ARIA, foco inicial y contraste cuidado, pero no he pasado una auditoría formal (WCAG) [No verificado].

---

## 2. Auditoría legal y fiscal de las páginas existentes

Páginas: aviso legal, privacidad, cookies, condiciones de compra, envíos y devoluciones, IVA e impuestos, normas y denuncias; para vendedores: condiciones e impuestos. Generadas por `tools/legal/generate.py`.

**Estado general [Verificado]:** borrador con aviso visible "pendiente de revisión por un abogado"; datos del titular como marcadores resaltados; solo en español (el resto de idiomas muestra un aviso de que la versión legal vinculante es la española).

**Lagunas importantes**
1. **Canarias ausente [Verificado].** El motor fiscal trata España como un único territorio de IVA. Canarias está fuera del territorio IVA de la UE y tiene IGIC, DUA/aduana y régimen propio de bienes usados. Ni `tax.js` ni las páginas lo recogen. Hasta resolverlo, "España" no es un destino ni un origen fiable para vendedores canarios.
2. **Afirmaciones sin respaldo técnico [Verificado].** Los textos hablan de verificación, cifrado o retención que no existen. Hay que retirarlos o implementarlos antes de publicar.
3. **Consentimiento art. 9 RGPD.** La compra de artículos eróticos puede revelar datos de vida sexual; se pide consentimiento explícito [Probable: criterio de autoridades y sentencias recientes]. Falta evaluación de impacto (EIPD), registro de actividades y contrato con encargados [Hipótesis: probablemente exigibles].
4. **DSA.** Falta designar punto de contacto, mecanismo de notificación y acción, y trazabilidad de comerciantes (art. 30). La exención para micro/pequeña empresa es probable pero depende de tu estructura [Probable; abogado].
5. **DAC7.** No hay recogida de datos (NIF, fecha de nacimiento, dirección, nº de operaciones e importes). Obligación probable para el operador de plataforma; en España, modelo 238 cada enero [Fuente: Ley 13/2023, RD 117/2024].
6. **Desistimiento y garantía.** Plazo de 14 días y excepción por higiene (art. 16.e CRD, interpretación restrictiva del TJUE); garantía distinta según el vendedor sea profesional o particular. Los textos lo reflejan de forma genérica; hay que fijar política real [Probable].
7. **Verificación de edad real.** La Recomendación (UE) 2026/1035 de 29-4-2026 y los sistemas de la AEPD/Arcom apuntan a verificación efectiva, no a una casilla [Fuente]. El plan debe prever un proveedor de verificación (sin guardar el DNI salvo justificación).
8. **Idiomas.** Los textos vinculantes solo están en español; para vender a FR/DE/IT lo habitual es ofrecer las condiciones en el idioma del consumidor [Hipótesis; abogado].

**Lo que está razonablemente resuelto como borrador:** estructura de los documentos, separación comprador/vendedor, distinción particular/profesional (Omnibus), información de IVA por régimen, aviso de borrador.

---

## 3. Competidores (revisión directa, 24-11-2026)

Método: abrí las portadas y páginas públicas de preguntas frecuentes y condiciones con peticiones HTTP normales. **No accedí a zonas con registro, no eludí protecciones y no valoré el contenido explícito**, solo el modelo de negocio. Lo que cada web dice de sí misma es **afirmación comercial**, no hecho comprobado (p. ej. cifras de miembros).

| Competidor | Acceso | Modelo (lo que dice la propia web) | Dinero | Verificación | Protección al comprador |
|---|---|---|---|---|---|
| **Snifffr** | OK | Mercado global; "2M+ miembros", "desde 2018"; registro gratis sin DNI; mensajería solo con cuenta Premium | Moneda interna (tokens, no reembolsables ni canjeables por el comprador). Cobro del vendedor vía Wise, con mínimo de 10 tokens y exigiendo Premium + verificación. Cobros hechos por empresas del grupo como comerciante de registro (EE. UU./Reino Unido). Permite también pagar directamente con el vendedor | Edad por proveedor externo de verificación de edad; "verificado" = foto con nota manuscrita; el vendedor debe conservar documentos de identidad y consentimiento de las personas que aparezcan; prohíbe imágenes generadas por IA | Dice que hay protección tipo "escrow" con tokens; reseñas y denuncias; recomienda envío con seguimiento |
| **PantyDeal** | OK | Anuncios + tienda propia + chat; "más de 2.000.000 miembros", "sin comisión" | Suscripciones. **Pagos entre comprador y vendedor fuera de la plataforma** (PayPal, tarjetas regalo, Cash App, Venmo) | Insignias por teléfono, foto y vídeo | Ninguna garantía propia: "no participamos en las transacciones" |
| **The Panty Bank** | OK | Tienda curada: sin registro abierto, las modelos las aprueba el equipo; cada pedido incluye vídeo de verificación y carta | Cobro con Authorize.net; **sin devoluciones ni reembolsos** de prendas usadas | Equipo aprueba a cada modelo; páginas de política contra trata, retirada de contenido y 18 U.S.C. 2257 | Vídeo de verificación por pedido; embalaje discreto |
| **underprivé** | OK, pero la web carga con JavaScript y solo vi metadatos | Se presenta como "marketplace líder en España", "vendedoras verificadas, pagos seguros y envío discreto" | No pude ver comisiones ni condiciones | No visible | No visible |
| **Sofia Gray** | **Bloqueado** (desafío de Cloudflare) | No analizada | - | - | - |
| **All Things Worn** | **Bloqueado** (desafío de Cloudflare) | No analizada | - | - | - |

Para Sofia Gray y All Things Worn no intenté saltar la protección. Sigo sin datos propios de ellas; solo valen las cifras de terceros de la primera pasada (retirada mínima de 50 $ para Sofia Gray, según un tercero).

Referencias de comisión de otros mercados [Fuente, mixta]: OnlyFans/Fansly 20 %, Passes 10 %, Fanvue 15–20 %, Poshmark 20 %, Vestiaire Collective 12 % (oficial), Mercari 10 %, Vinted 0 % al vendedor con tarifa al comprador.

---

## 4. Comparativa con Intimae

**Lo que descubren los competidores [Verificado en sus webs]**
1. **Ninguno de los tres publica un porcentaje de comisión**: PantyDeal dice expresamente que no cobra comisión (suscripciones); Snifffr gana con membresía Premium y con la venta de tokens, y se reserva cambiar "la cantidad pagadera al vendedor en el cash-out" (es decir, puede haber un margen implícito no publicado); The Panty Bank es una tienda curada, no un mercado abierto. Esto contradice la hipótesis del documento maestro (comisión del 8-12 %) como práctica del sector, y da una alternativa: ingresos por suscripción o por tarifa de anuncio en lugar de comisión.
2. **Dos de los tres evitan ser parte del pago** (PantyDeal deja pagar fuera; Snifffr usa tokens con comerciante de registro propio en EE. UU./Reino Unido). Eso apunta a que reparto de fondos a terceros con procesador convencional es justo lo difícil, y que operan en jurisdicciones distintas a la UE. [Probable]
3. **Verificación**: lo habitual es edad por proveedor externo + verificación manual con foto/nota. Ninguno pide DNI en el registro.
4. **El estándar del sector incluye** chat, reseñas, denuncias, envío discreto, perfiles/tienda del vendedor y pagos dentro o fuera de la plataforma.
5. **Los tres son anglófonos y con perspectiva EE. UU.**: ninguno muestra tratamiento de IVA por país ni DAC7. Esa es la única ventaja diferencial real y verificable de Intimae (ya implementada en el motor fiscal).

**Intimae frente a ellos**
- Ventaja: fiscalidad europea por vendedor y destino, multilingüe, zonas separadas, consentimiento explícito de datos sensibles.
- Déficit: todo lo del apartado 1.3 (cuentas, mensajería, reseñas, verificación, pagos...). Hoy no hay ni un solo usuario real.
- Dato que no tengo: su tráfico real, sus ingresos y sus tasas de fraude. Las cifras de miembros son declaraciones propias.

**Consecuencia para la decisión de comisión**: el 8-12 % del documento maestro no está respaldado por lo que hacen estos competidores; la alternativa a evaluar es **tarifa fija por anuncio o suscripción** (más fácil de cobrar y de justificar fiscalmente), con comisión opcional si hay pago integrado. Decisión pendiente tuya.

---

## 5. Mejoras priorizadas

Orden pensado para tu prioridad declarada: viable legalmente, correcto fiscalmente, seguro técnicamente y que limite tu responsabilidad personal.

**P0 – Bloqueantes (antes de escribir backend)**
1. Confirmación **por escrito** de un procesador de pagos que acepte este modelo (marketplace + artículos de carácter erótico + reparto a terceros). Sin ella, el Modelo B no existe.
2. Constituir/definir el titular (SL) y recibir asesoramiento mercantil/fiscal canario sobre IGIC/IVA, OSS no-Unión, DAC7 y responsabilidad del administrador.
3. Decidir si el Modelo B es viable o si se parte de un Modelo A reducido (ver 6).
4. Ocultar al público `docs/`, `tools/`, `screenshots/` (`.vercelignore`, hecho) y pasar a un plan de Vercel que permita uso comercial antes de operar.

**P1 – Imprescindibles para un lanzamiento mínimo**
5. Cuentas + base de datos + almacenamiento de imágenes (Supabase es candidato razonable; ver 6).
6. Alta de anuncios por el vendedor con revisión previa (moderación).
7. Verificación de edad real (proveedor externo, sin guardar documentos propios).
8. Recogida de datos DAC7 en el alta del vendedor.
9. Motor fiscal con Canarias (IGIC, DUA, origen/destino) validado por asesor.
10. Flujo de denuncias y avisos DSA con registro.
11. Correo transaccional, copias de seguridad, registro de auditoría.

**P2 – Para operar con confianza**
12. Pagos con custodia y liberación tras entrega; disputas; reembolsos.
13. Seguimiento de envíos (integración con transportistas).
14. Mensajería moderada; reseñas.
15. Traducción jurídica profesional de los documentos vinculantes.

**P3 – Crecimiento**
16. Más países (activar uno a uno cuando su fiscalidad esté resuelta), SEO, programa de fidelización, etc.

---

## 6. Arquitectura propuesta (sin cambiar lo que funciona)

[Hipótesis de diseño; verificar con proveedores antes de comprometerse]
- **Se mantiene** el front estático actual y el sistema de idiomas; no hay razón fuerte para reescribir en Next.js ahora. Se puede añadir backend ligero sin cambiar de framework.
- **Backend:** Supabase (Postgres con reglas de acceso por fila, autenticación, almacenamiento) + funciones serverless de Vercel para lo que requiera secretos (pagos, verificación de edad, correo). Región UE.
- **Datos personales sensibles:** mínimos, separados, con acceso restringido y borrado programado; el comprador no se vincula a sus compras en vistas públicas.
- **Pagos:** no se diseña hasta tener el apartado 5.P0.1. Si el procesador exige que el vendedor tenga su propia cuenta conectada, el flujo cambia por completo. **No** usar cuentas bancarias personales ni cartera propia de saldo.
- **Modelo A reducido (alternativa si B no es viable):** la plataforma anuncia y modera; la compraventa se cierra entre las partes con medios de pago ajenos y la plataforma cobra una tarifa fija por anuncio/suscripción. Menos riesgo regulatorio de pagos, peor experiencia y peor protección al comprador. [Hipótesis; hay que contrastarla con un abogado: no está claro que ese modelo evite las obligaciones de plataforma]
- **Comisión:** el documento propone 8–12 %. Con costes de pago de alto riesgo (4–8 %, hasta ~10 % [Fuente: proveedores y blogs comerciales]), reservas y contracargos, mi modelo de ejemplo (ticket 35 €, 6 % procesador, 1,5 % fraude, 1,50 € operativos) da un punto de equilibrio de ≈11,8 %. Con 10 % se pierde dinero por pedido; con 20 % el margen es ≈2,88 €. Esto es un **ejemplo con supuestos propios**, no un dato de mercado.

---

## 7. Riesgos que requieren profesional

1. **Medios de pago:** políticas de Stripe (contenido adulto y artículos de orientación sexual con aprobación previa y supervisión de cuentas conectadas), Adyen, PayPal y exigencias de Mastercard (verificación de edad/identidad de personas mostradas y de quienes suben contenido) [Fuente: textos públicos; no verificado con cada proveedor].
2. **Responsabilidad personal de la SL:** una SL no elimina toda responsabilidad (deberes del administrador, avales, responsabilidad tributaria derivada) [Probable; abogado mercantil].
3. **Canarias:** IGIC, régimen de bienes usados del IGIC (Ley 20/1991, arts. 52–53 según mi lectura), no aplicación del REBU en Canarias, DUA en envíos con la Península y la UE, y posible alta en OSS no-Unión como prestador de servicios electrónicos [No verificado; asesor fiscal canario].
4. **REBU/bienes usados:** no todo producto usado entra automáticamente; depende del vendedor y de cómo adquirió el bien.
5. **DAC7 y retenciones/IRPF de vendedores particulares.**
6. **Protección de datos:** categorías especiales, EIPD, transferencias internacionales, DPO si procede.
7. **DSA:** categoría de la plataforma, contacto con autoridades, transparencia.
8. **Higiene y productos usados:** exclusión del desistimiento y obligaciones de información.
9. **Contenido y personas:** prohibición de fotos con rostro o menores, política de consentimiento, protección frente a imágenes íntimas no consentidas.
10. **Envíos fuera de la UE** (UK, NO, CH): IVA/aduanas con reglas propias; hoy bloqueados a propósito.

---

## 8. Plan por fases

| Fase | Objetivo | Hito de salida |
|---|---|---|
| 0. Decisiones (sin código) | Titular, asesores, proveedor de pagos con respuesta escrita, plan de Vercel/hosting, comisión | Documento firmado con respuestas de pagos y asesor fiscal |
| 1. Base técnica | Cuentas, BD, anuncios, imágenes, moderación, correo, copias | Vendedores de prueba publicando en entorno privado |
| 2. Cumplimiento | Verificación de edad, DAC7, DSA, motor fiscal con Canarias, textos legales revisados | Revisión de abogado y asesor fiscal aprobada |
| 3. Pagos y logística | Cobro con custodia, reparto, reembolsos, seguimiento | Transacciones reales de bajo importe con un solo país (ES península) |
| 4. Expansión | FR, DE, IT uno a uno; traducciones jurídicas; marketing | Cada país solo se activa tras resolver su fiscalidad |

No se avanza de fase sin cerrar la salida de la anterior.

---

## 9. Qué haría yo ahora (opinión)

La verdad incómoda: el cuello de botella no es el código, es **conseguir cobrar legalmente** por este tipo de producto con reparto a terceros. Hasta que un proveedor te lo confirme por escrito, construir cuentas, panel y base de datos es gastar tiempo en algo que puede no poder lanzarse. El primer gasto útil es una consulta con un asesor fiscal canario y una pregunta formal a 2–3 proveedores de pago.

## 10. Límites de esta auditoría
- No he accedido a cuentas de Vercel, Supabase ni Stripe del usuario más allá de desplegar; no existe un proyecto Supabase vinculado a este repositorio que yo haya podido inspeccionar.
- Competidores: leí cuatro de seis (Snifffr, PantyDeal, The Panty Bank, y solo metadatos de underprivé). Sofia Gray y All Things Worn estaban tras un desafío de Cloudflare y no los analicé. Solo páginas públicas, sin registro.
- No he consultado BOE, AEAT, ATC ni la Comisión Europea directamente en esta pasada; las cifras fiscales y regulatorias son de fuentes secundarias o de mi conocimiento y deben contrastarse con fuente oficial antes de actuar.
- Las tarifas de envío, comisión e impuestos del sitio son de demostración.

---

## 11. Costes y beneficios estimados (modelo de ejemplo, 25-11-2026)

**Todo son supuestos míos, no datos de mercado.** Sirven para ver órdenes de magnitud, no para pedir un préstamo. Excluyen tu tiempo, el desarrollo (lo haces tú) y el impuesto de sociedades (15 % los dos primeros años con beneficio es lo habitual en España; ZEC/Canarias sin confirmar).

**Supuestos:** ticket medio 35 €; coste variable por pedido = 7,5 % (6 % procesador de alto riesgo + 1,5 % fraude/contracargos) + 1,50 € (soporte, verificación de edad, correo) = **4,125 €**. Pagos únicos 4.800 € (SL 600, abogado 2.500, asesor fiscal 600, RGPD 800, marca/fotos 300). Fijos 372 €/mes el año 1 (hosting Vercel Pro + Supabase 45, correo 20, dominio 2, gestoría 100, seguro 40, herramientas 50, cumplimiento/DAC7 25, cuota de autónomo societario 90) y 582 €/mes el año 2 (cuota sin tarifa plana 300). Marketing 500 €/mes el año 1 y 700 € el año 2. Pedidos/mes: pesimista 20 → 60 (meses 12 → 24), base 120 → 350, optimista 500 → 1.500.

| Modelo de ingreso | Ingreso bruto/pedido | Contribución/pedido | Equilibrio (fijos + marketing, año 1) |
|---|---|---|---|
| A. Comisión 20 % al vendedor | 7,00 € | 2,88 € (1,66 € si la comisión lleva 21 % de IVA) | 303 pedidos/mes (525 con IVA) |
| B. Comisión 10 % al vendedor | 3,50 € | −0,62 € | imposible |
| C. 10 % vendedor + 5 % + 0,50 € comprador | 5,75 € | 1,62 € (0,63 € con IVA) | 537 pedidos/mes (1.391 con IVA) |
| D. Suscripción 9,99 €/mes, pago fuera de plataforma | 9,99 €/vendedor | ≈ 7,3 € por vendedor de pago | 120 vendedores de pago (≈ 800 activos si paga el 15 %) |

**Resultado acumulado a 24 meses (modelo A, 20 %):**

| Escenario | Sin IVA sobre la comisión | Con 21 % de IVA |
|---|---|---|
| Pesimista | −28.800 € | −29.600 € |
| Base | −20.000 € | −24.500 € |
| Optimista | +14.600 € (caja mínima −7.600 €) | −4.500 € (caja mínima −10.400 €) |

Capital inmovilizado por reservas del procesador (10 % del volumen durante 6 meses): ≈ 2.500 € en el escenario base y ≈ 10.500 € en el optimista, aparte de las pérdidas.

**Lectura:** con pago integrado y costes de alto riesgo, solo el escenario optimista (500 pedidos/mes a los 12 meses, sin audiencia previa) llega a beneficio, y solo si el IVA sobre la comisión no se come el margen. Necesidad de liquidez realista para sostener 24 meses: 20.000–30.000 €. Esto es [Suposición] salvo los puntos de equilibrio, que son aritmética sobre esos supuestos.


---

## 12. Estado tras la integración en modo demostración (25-11-2026)

**Qué hay ahora [Verificado con pruebas de navegador automatizadas]:** cuentas de comprador y de vendedor (contraseña con hash SHA-256 con sal, solo demostración); verificación de edad simulada que no guarda la fecha de nacimiento; anuncios con fotos reducidas a 900 px y sin metadatos; moderación previa; pedidos por vendedor con pago simulado retenido, envío con seguimiento, confirmación de recepción, liquidación automática o manual y cancelación solo antes del envío; mensajes entre comprador y vendedor con bloqueo de correos, teléfonos y enlaces; valoraciones; favoritos; denuncias con número y resolución con exposición de motivos; datos fiscales (DAC7) con exportación CSV y umbrales; ajustes (comisión y plazos); registro de auditoría; Canarias (IGIC, solo envíos internos); esquema de base de datos con RLS (sin ejecutar).

**Qué sigue sin existir y por qué importa [Verificado]:** servidor y base de datos reales (hoy los datos viven en cada navegador y no se comparten); pagos reales y proveedor de pagos; verificación real de edad e identidad; correo transaccional; seguimiento de transportistas; traducción de cuenta, panel y administración (solo español); datos legales de la titularidad; revisión de abogado y asesor fiscal; confirmación escrita de los procesadores.

**Política decidida:** Intimae no gestiona devoluciones, reclamaciones ni disputas. Efectos: sin estados de disputa en el código; pago que no se congela por reclamaciones; contracargos imputados al vendedor en las condiciones. **Riesgos [Probable]:** los procesadores y las tarjetas esperan un procedimiento de reclamaciones y los consumidores UE conservan derechos frente a vendedores profesionales que unas condiciones no pueden eliminar; sin protección al comprador es previsible más contracargos, que son justo lo que pone en riesgo la cuenta de pagos. Hay que validarlo con el abogado y con el procesador.

**Qué no hay que dar por hecho:** el modo demostración **no** es una versión operable. Cuentas, contraseñas y administración no tienen seguridad real porque no hay servidor.
