#!/usr/bin/env python3
"""Genera las páginas legales de Intimae. Los {{CAMPOS}} son datos pendientes de titularidad."""
import re, pathlib

OUT = pathlib.Path(__file__).resolve().parents[2]

NAV = [
    ("aviso-legal.html", "Aviso legal"),
    ("privacidad.html", "Privacidad"),
    ("cookies.html", "Cookies"),
    ("condiciones-compra.html", "Condiciones de compra"),
    ("envios.html", "Envíos y entrega"),
    ("iva.html", "IVA e impuestos"),
    ("incidencias.html", "Incidencias y reclamaciones"),
    ("normas.html", "Normas y denuncias"),
]
SHARED = ["aviso-legal", "privacidad", "cookies", "normas", "envios", "condiciones-compra", "incidencias"]

BANNER = ('<div class="draft"><strong>Borrador.</strong> Texto redactado sin asesoría legal y pendiente de revisión por un '
          'abogado. Los campos <mark class="todo">resaltados</mark> están pendientes de la titularidad del negocio. '
          'Última actualización: {{FECHA}}.</div>')


def fill(s):
    return re.sub(r"\{\{(.+?)\}\}", r'<mark class="todo">[\1]</mark>', s)


def page(fname, title, body, zone="buyer"):
    seller = zone == "seller"
    pfx = "../" if seller else ""
    if seller:
        # En el área de vendedores, los documentos compartidos viven en la raíz y la guía de IVA es la de vendedores
        for n in SHARED:
            body = body.replace(f'href="{n}.html"', f'href="../{n}.html"')
        body = body.replace('href="iva.html"', 'href="impuestos.html"').replace('href="privacidad.html"', 'href="../privacidad.html"')
        links = '<a href="./">Área de vendedores</a><a href="condiciones.html">Condiciones para vendedores</a><a href="impuestos.html">Impuestos para vendedores</a><a href="../normas.html">Normas y denuncias</a><a href="../privacidad.html">Privacidad</a>'
        header = f'''<header class="sv-header"><div class="wrap sv-header__in">
  <div class="sv-brand"><a class="wordmark" href="./" aria-label="Intimae, área de vendedores">Intimae</a><span class="sv-tag" data-i18n="sv.hdr.label">Vendedores</span></div>
  <div class="sv-tools"><select class="lang" id="lang" data-i18n-attr="aria-label:aria.lang" aria-label="Idioma"></select><a class="sv-shop" href="../" data-i18n="sv.hdr.shop">Ir a la tienda →</a></div>
</div></header>'''
        footer = '<footer class="footer"><div class="wrap footer__legal"><span>© 2026 Intimae · Área de vendedores. Sitio para mayores de 18 años.</span><a href="./">Volver al área de vendedores</a></div></footer>'
        extra_css = f'<link rel="stylesheet" href="{pfx}css/seller.css">'
        body_class = ' class="seller"'
    else:
        links = "".join(f'<a href="{h}">{t}</a>' for h, t in NAV)
        header = '''<header class="site-header"><div class="wrap site-header__in">
  <nav class="menu" aria-label="Legal"><a href="legal.html" data-i18n="legal.hdr">Información legal</a></nav>
  <a class="wordmark" href="index.html" aria-label="Intimae, inicio">Intimae</a>
  <div class="tools"><select class="lang" id="lang" data-i18n-attr="aria-label:aria.lang" aria-label="Idioma"></select><a class="link" href="index.html" data-i18n="legal.back">← Volver a la tienda</a></div>
</div></header>'''
        footer = '<footer class="footer"><div class="wrap footer__legal"><span>© 2026 Intimae. Sitio para mayores de 18 años.</span><a href="index.html">Volver a la tienda</a></div></footer>'
        extra_css = ""
        body_class = ""
    html = f"""<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} · Intimae</title>
  <meta name="robots" content="noindex, nofollow">
  <meta name="theme-color" content="#171213">
  <link rel="icon" href="{pfx}favicon.svg" type="image/svg+xml">
  <link rel="preload" href="{pfx}fonts/inter-latin-400-normal.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="{pfx}css/fonts.css">
  <link rel="stylesheet" href="{pfx}css/styles.css">
  <link rel="stylesheet" href="{pfx}css/legal.css">
  {extra_css}
  <script>(function(){{var d=document.documentElement;d.classList.add("js");try{{var l=localStorage.getItem("intimae_lang_manual")==="1"?localStorage.getItem("intimae_lang"):(navigator.language||"es").slice(0,2);if(l&&l!=="es")d.classList.add("i18n-pending")}}catch(e){{}}setTimeout(function(){{d.classList.remove("i18n-pending")}},1800)}})()</script>
</head>
<body{body_class}>
<a class="skip" href="#main">Saltar al contenido</a>
{header}
<main id="main" class="legal">
  <div class="notice" id="es-only" hidden></div>
  {BANNER}
  <h1>{title}</h1>
{body}
  <nav class="legal__nav" aria-label="Otros documentos legales"><a href="{'./' if seller else 'legal.html'}">Índice</a>{links}</nav>
</main>
{footer}
<script src="{pfx}js/i18n.js"></script>
<script src="{pfx}i18n/es.js"></script>
<script>(function(){{var b=document.getElementById("es-only");I18N.mountSelect(document.getElementById("lang"));I18N.onChange(function(l){{b.hidden=(l==="es");b.textContent=I18N.t("legal.es_only")}});I18N.start()}})()</script>
</body>
</html>
"""
    out = OUT / fname
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(fill(html), encoding="utf-8")


# ---------------------------------------------------------------- AVISO LEGAL
page("aviso-legal.html", "Aviso legal", """
  <h2>1. Datos identificativos del titular</h2>
  <p>En cumplimiento del artículo 10 de la Ley 34/2002, de servicios de la sociedad de la información y de comercio electrónico (LSSI-CE):</p>
  <table>
    <tr><th>Titular</th><td>{{TITULAR: nombre y apellidos o denominación social}}</td></tr>
    <tr><th>NIF / CIF</th><td>{{NIF/CIF}}</td></tr>
    <tr><th>Domicilio</th><td>{{DOMICILIO COMPLETO}}</td></tr>
    <tr><th>Correo electrónico</th><td>{{EMAIL DE CONTACTO}}</td></tr>
    <tr><th>Teléfono</th><td>{{TELÉFONO}}</td></tr>
    <tr><th>Datos registrales</th><td>{{REGISTRO MERCANTIL: tomo, folio, hoja (solo si es sociedad)}}</td></tr>
    <tr><th>Nombre de dominio</th><td>{{DOMINIO}}</td></tr>
  </table>

  <h2>2. Objeto del sitio y papel del titular</h2>
  <p>Este sitio es una plataforma en línea que permite a personas mayores de edad ofrecer y comprar prendas íntimas de segunda mano. Cada anuncio indica quién es el vendedor y si actúa como <strong>profesional</strong> o como <strong>particular</strong>. Salvo que se indique lo contrario, el contrato de compraventa se celebra entre comprador y vendedor; el titular actúa como intermediario y no es parte de ese contrato. El reparto de obligaciones se detalla en las <a href="condiciones-compra.html">condiciones de compra</a>.</p>
  <p>El titular no es parte del contrato de compraventa, pero ofrece a compradores y vendedores un <a href="incidencias.html">procedimiento de incidencias</a> y atiende las denuncias de contenido ilegal (ver <a href="normas.html">normas y denuncias</a>).</p>

  <h2>3. Acceso y uso: solo mayores de edad</h2>
  <p>El sitio contiene material de carácter erótico y está dirigido exclusivamente a personas mayores de 18 años. Al acceder declaras ser mayor de edad. El titular puede exigir mecanismos adicionales de verificación de edad. Está prohibido el uso del sitio por menores.</p>

  <h2>4. Propiedad intelectual</h2>
  <p>El diseño, el código, los textos y la marca del sitio pertenecen al titular o se usan con licencia. Las fotografías de muestra proceden de <a href="https://unsplash.com/?utm_source=intimae&amp;utm_medium=referral" target="_blank" rel="noopener noreferrer">Unsplash</a>, con crédito a sus autores en cada anuncio, y se usan conforme a su licencia. Las imágenes y textos de los anuncios de vendedores son responsabilidad de estos, que declaran ser titulares de los derechos o contar con autorización.</p>

  <h2>5. Responsabilidad</h2>
  <p>El titular no responde del contenido publicado por vendedores, pero actuará con diligencia para retirar contenido ilegal de acuerdo con el Reglamento (UE) 2022/2065 (Ley de Servicios Digitales) y con las <a href="normas.html">normas de la plataforma</a>. El titular no garantiza la disponibilidad ininterrumpida del sitio. La conformidad, la entrega y la calidad de las prendas corresponden al vendedor, sin perjuicio de las obligaciones que la ley imponga al titular como prestador de servicios intermediarios y del procedimiento de incidencias descrito en <a href="incidencias.html">incidencias y reclamaciones</a>.</p>

  <h2>6. Punto de contacto (Ley de Servicios Digitales)</h2>
  <p>Autoridades de los Estados miembros, la Comisión Europea y la Junta Europea de Servicios Digitales pueden comunicarse con el titular por correo electrónico en {{EMAIL DE CONTACTO PARA AUTORIDADES}}, en español o en inglés. Los usuarios pueden contactar en {{EMAIL DE CONTACTO}}. El procedimiento de denuncias se explica en <a href="normas.html">normas y denuncias</a>.</p>

  <h2>7. Enlaces</h2>
  <p>Los enlaces a sitios de terceros se ofrecen por comodidad. El titular no responde del contenido ni de las políticas de esos sitios.</p>

  <h2>8. Legislación aplicable y jurisdicción</h2>
  <p>Este aviso se rige por la ley española. Para los consumidores, serán competentes los juzgados y tribunales de su domicilio, sin perjuicio de las normas imperativas de protección de consumidores de su país de residencia habitual. En el resto de casos, los juzgados de {{CIUDAD DE JURISDICCIÓN}}.</p>
""")

# ---------------------------------------------------------------- PRIVACIDAD
page("privacidad.html", "Política de privacidad", """
  <div class="box"><p><strong>Estado actual: demostración.</strong> En la versión de demostración, las cuentas, los pedidos, los mensajes, los favoritos y los datos fiscales se guardan únicamente en el almacenamiento local de tu navegador. No se envían a ningún servidor ni a terceros, la verificación de edad es simulada y no se procesan pagos reales. Lo que sigue describe el tratamiento previsto cuando el servicio funcione con servidores reales.</p></div>

  <h2>1. Responsable del tratamiento</h2>
  <p>{{TITULAR}}, con NIF {{NIF/CIF}} y domicilio en {{DOMICILIO COMPLETO}}. Contacto: {{EMAIL DE CONTACTO}}. Delegado de protección de datos (si procede): {{DPD o "no designado"}}.</p>

  <h2>2. Qué datos tratamos</h2>
  <ul>
    <li><strong>Compradores:</strong> nombre o alias, correo, dirección de entrega, teléfono (si lo facilitas), contenido del pedido, estado del pedido, comunicaciones con el vendedor y con nosotros, y mensajes y pruebas de las incidencias que abras.</li>
    <li><strong>Vendedores:</strong> lo anterior más datos de identidad y edad (documento oficial), dirección, teléfono, NIF o identificador fiscal, país de residencia fiscal, fecha de nacimiento, cuenta bancaria o medio de cobro, y datos de actividad (número e importe de ventas).</li>
    <li><strong>Técnicos:</strong> dirección IP, tipo de navegador y registros de seguridad.</li>
  </ul>

  <h2>3. Categorías especiales: vida sexual</h2>
  <p>Comprar o vender artículos de carácter erótico puede revelar información sobre tu vida sexual, que el artículo 9 del RGPD considera categoría especial de datos. <strong>Tratamos esos datos solo con tu consentimiento explícito</strong>, que te pediremos de forma separada y no premarcada en el momento del pedido o del alta como vendedor. Puedes retirarlo en cualquier momento; si lo haces no podremos tramitar nuevos pedidos. No cedemos el contenido de pedidos o carritos a herramientas de analítica ni de publicidad.</p>

  <h2>4. Para qué los usamos y en qué base legal</h2>
  <table>
    <tr><th>Finalidad</th><th>Base legal</th></tr>
    <tr><td>Tramitar pedidos y entregas</td><td>Ejecución del contrato (art. 6.1.b RGPD) y consentimiento explícito (art. 9.2.a)</td></tr>
    <tr><td>Verificar edad e identidad de vendedores y evitar menores</td><td>Obligación legal e interés legítimo en proteger a menores (art. 6.1.c y 6.1.f)</td></tr>
    <tr><td>Identificar a vendedores profesionales (trazabilidad) y comunicar datos a la Administración tributaria (DAC7)</td><td>Obligación legal (art. 6.1.c)</td></tr>
    <tr><td>Prevenir fraude, abusos y contenido ilegal; atender denuncias</td><td>Interés legítimo y obligación legal</td></tr>
    <tr><td>Comunicaciones comerciales</td><td>Consentimiento (art. 6.1.a), opcional</td></tr>
  </table>

  <h2>5. Destinatarios</h2>
  <p>Vendedor correspondiente (solo los datos necesarios para el envío), transportistas, proveedor de pagos {{PROVEEDOR DE PAGOS}}, proveedor de verificación de identidad y edad {{PROVEEDOR DE VERIFICACIÓN}}, proveedor de alojamiento {{HOSTING}}, asesores, y autoridades cuando la ley lo exija (por ejemplo, la Agencia Tributaria). No vendemos tus datos.</p>

  <h2>6. Transferencias internacionales</h2>
  <p>Si algún proveedor trata datos fuera del Espacio Económico Europeo, lo haremos con garantías adecuadas (decisión de adecuación o cláusulas contractuales tipo). Detalle: {{LISTA DE PROVEEDORES Y PAÍSES}}.</p>

  <h2>7. Cuánto tiempo conservamos los datos</h2>
  <p>Mientras dure la relación y, después, bloqueados durante los plazos legales de prescripción fiscales, mercantiles y de consumo. Los documentos de identidad se conservan solo el tiempo necesario para completar la verificación y cumplir las obligaciones legales: {{PLAZO DE CONSERVACIÓN}}. Los datos de contacto para marketing, hasta que retires el consentimiento.</p>

  <h2>8. Tus derechos</h2>
  <p>Puedes ejercer los derechos de acceso, rectificación, supresión, oposición, limitación y portabilidad escribiendo a {{EMAIL DE CONTACTO}}, y retirar tu consentimiento cuando quieras. Si consideras que no tratamos tus datos correctamente, puedes reclamar ante la Agencia Española de Protección de Datos (<a href="https://www.aepd.es" target="_blank" rel="noopener noreferrer">aepd.es</a>) o ante la autoridad de tu país.</p>

  <h2>9. Seguridad y menores</h2>
  <p>Aplicamos medidas técnicas y organizativas proporcionales al riesgo, con acceso restringido a la documentación de identidad. El servicio está prohibido a menores de 18 años; si detectamos una cuenta de un menor, la bloquearemos y borraremos sus datos.</p>
""")

# ---------------------------------------------------------------- COOKIES
page("cookies.html", "Política de cookies y almacenamiento local", """
  <h2>1. Qué usamos hoy</h2>
  <p>Este sitio no usa cookies de analítica, publicidad ni seguimiento. Solo guarda en tu navegador, mediante almacenamiento local, los datos imprescindibles para que funcione lo que has pedido:</p>
  <table>
    <tr><th>Nombre</th><th>Finalidad</th><th>Tipo</th><th>Duración</th></tr>
    <tr><td><code>intimae_age_ok</code></td><td>Recordar que has confirmado ser mayor de edad</td><td>Técnico, necesario</td><td>Hasta que borres los datos del navegador</td></tr>
    <tr><td><code>intimae_cart</code></td><td>Mantener el contenido de tu carrito</td><td>Técnico, necesario</td><td>Hasta que borres los datos del navegador</td></tr>
    <tr><td><code>intimae_lang</code>, <code>intimae_lang_manual</code></td><td>Recordar tu idioma y si lo has elegido tú</td><td>Preferencia, necesaria</td><td>Hasta que borres los datos del navegador</td></tr>
    <tr><td><code>intimae_dest</code></td><td>Recordar tu país de envío</td><td>Preferencia, necesaria</td><td>Hasta que borres los datos del navegador</td></tr>
    <tr><td><code>intimae_sess_v1</code></td><td>Mantener tu sesión iniciada (comprador, vendedor o administración)</td><td>Técnico, necesario</td><td>Hasta que cierres la sesión o borres los datos</td></tr>
    <tr><td><code>intimae_db_v1</code></td><td>Versión de demostración: cuentas, anuncios, pedidos y mensajes guardados en tu navegador</td><td>Técnico, necesario</td><td>Hasta que borres los datos del navegador</td></tr>
  </table>
  <p>Al ser estrictamente necesarios para prestar el servicio que solicitas, no requieren consentimiento (art. 22.2 LSSI-CE).</p>

  <h2>2. Si añadimos otras herramientas</h2>
  <p>Cualquier cookie o tecnología no necesaria (analítica, publicidad, redes sociales) solo se activará después de que la aceptes mediante un aviso con botones de aceptar y rechazar del mismo nivel. Por la naturaleza del sitio, no se instalarán herramientas que reciban el contenido de carritos o pedidos.</p>

  <h2>3. Cómo eliminarlas</h2>
  <p>Puedes borrar el almacenamiento local desde los ajustes de tu navegador. Si lo haces, se te pedirá de nuevo confirmar tu edad y se vaciará el carrito.</p>
""")

# ---------------------------------------------------------------- CONDICIONES COMPRA
page("condiciones-compra.html", "Condiciones de compra", """
  <h2>1. Quién vende</h2>
  <p>Cada anuncio muestra el alias del vendedor y si es <strong>profesional</strong> o <strong>particular</strong>, según su propia declaración al registrarse. <strong>Si el vendedor es un particular, no se aplican las normas de protección de consumidores de la Unión Europea ni la legislación de consumidores española</strong> (derecho de desistimiento y garantía legal de consumo); se aplica el Código Civil o el derecho del país correspondiente. Si es profesional, sí se aplican. <strong>Intimae actúa como intermediario:</strong> facilita el contacto, el pago y el seguimiento del pedido y ofrece un <a href="incidencias.html">procedimiento de incidencias</a>, pero no es el vendedor ni parte del contrato de compraventa, y no almacena, envía ni inspecciona las prendas.</p>

  <h2>2. Edad y capacidad</h2>
  <p>Debes ser mayor de 18 años. El titular puede pedir verificación de edad antes de tramitar un pedido y rechazar los pedidos de quien no la supere.</p>

  <h2>3. Precio e impuestos</h2>
  <p>Los precios se muestran en euros y, cuando proceda, incluyen el IVA. Los gastos de envío se indican antes de confirmar el pedido: ver <a href="envios.html">envíos y entrega</a>. El tratamiento del IVA depende de si el vendedor es particular o profesional y de dónde se envía. Se explica en <a href="iva.html">IVA e impuestos</a> y se muestra en cada ficha antes de pedir.</p>

  <h2>4. Pedido y pago</h2>
  <p>El pago lo procesa el proveedor de pagos {{PROVEEDOR DE PAGOS}} ({{MEDIOS DE PAGO ADMITIDOS}}). La liquidación al vendedor se realiza después de la entrega, según el contrato con el proveedor y sus reglas ({{PLAZO DE LIQUIDACIÓN}}). Cada prenda es única: si ya no está disponible, o si el vendedor cancela antes de enviarla, se te reembolsa el importe íntegro. También puedes cancelar tú el pedido mientras no se haya enviado, con reembolso íntegro.</p>
  <p>Si abres un contracargo ante tu banco, lo gestiona el proveedor de pagos según sus procedimientos. Conviene abrir antes una incidencia: es más rápido y no excluye tus derechos.</p>

  <h2>5. Entrega</h2>
  <p>Plazos, zonas y embalaje neutro se detallan en <a href="envios.html">envíos y entrega</a>.</p>

  <h2>6. Desistimiento y devoluciones (compras a vendedores profesionales)</h2>
  <p>Cuando compras a un vendedor profesional, la ley puede darte un derecho de desistimiento de 14 días naturales desde la recepción. <strong>Ese derecho se ejerce frente al vendedor</strong>; comunícaselo de forma inequívoca por el sistema de mensajes. Si no se resuelve, puedes abrir una <a href="incidencias.html">incidencia</a> y Intimae intervendrá dentro de sus facultades. Los vendedores particulares no están sujetos al desistimiento de consumo.</p>
  <p><strong>Higiene:</strong> la ley prevé una excepción para bienes precintados que no sean aptos para devolverse por razones de higiene y se hayan desprecintado tras la entrega (art. 103.e del texto refundido de la Ley General para la Defensa de los Consumidores y Usuarios). <strong>Esa excepción no se aplica de forma automática por el hecho de que se trate de prendas íntimas</strong>: depende de las circunstancias concretas de cada caso y de la interpretación que haga un tribunal. {{CRITERIO LEGAL PENDIENTE DE REVISIÓN POR UN ABOGADO}}</p>
  <div class="box">
    <p><strong>Modelo de formulario de desistimiento</strong> (rellénalo y envíalo solo si quieres desistir)</p>
    <p>A la atención del vendedor (alias: ______ ):<br>
    Por la presente le comunico que desisto de mi contrato de compra del siguiente bien: ______ . Pedido el ______ , recibido el ______ . Nombre del consumidor: ______ . Domicilio del consumidor: ______ . Fecha: ______ .</p>
  </div>

  <h2>7. Conformidad y garantía (compras a profesionales)</h2>
  <p>Los bienes deben ser conformes con lo descrito en el anuncio. La responsabilidad por falta de conformidad corresponde al vendedor; si no se resuelve con él, puedes abrir una <a href="incidencias.html">incidencia</a>. Si el vendedor es profesional, se aplica la garantía legal del texto refundido de la Ley General para la Defensa de los Consumidores y Usuarios. En bienes de segunda mano, el plazo puede reducirse por acuerdo hasta un mínimo de un año desde la entrega; el plazo concreto se indicará en cada anuncio: {{PLAZO DE GARANTÍA}}.</p>

  <h2>8. Reclamaciones</h2>
  <p>Ante cualquier problema con un pedido (retraso, pérdida, prenda distinta de la anunciada, daños) puedes abrir una <a href="incidencias.html">incidencia</a> desde tu cuenta. Intimae la tramita dentro de sus facultades y de las reglas del proveedor de pagos. Esto no limita tus derechos legales ni tu posibilidad de acudir a la vía de reclamación que te corresponda en tu país.</p>
  <p>Las denuncias de contenido ilegal se tramitan según <a href="normas.html">normas y denuncias</a>. {{HOJAS DE RECLAMACIONES: indicar si procede en tu comunidad autónoma}}. Entidad de resolución alternativa de litigios adherida, si la hay: {{ENTIDAD ADR o "ninguna"}}. La plataforma europea de resolución de litigios en línea dejó de funcionar el 20 de julio de 2025.</p>

  <h2>9. Conductas prohibidas</h2>
  <p>Está prohibido pedir o ofrecer cualquier cosa que implique a menores, coacción, acoso o suplantación; solicitar datos personales del vendedor; o intentar contactar o acordar encuentros fuera de la plataforma.</p>

  <h2>10. Ley aplicable</h2>
  <p>Ley española, sin perjuicio de las normas imperativas de protección de consumidores del país de residencia habitual del comprador.</p>
""")

# ---------------------------------------------------------------- ENVIOS
page("envios.html", "Envíos y entrega", """
  <h2>1. Dónde enviamos</h2>
  <table>
    <tr><th>Zona</th><th>Aduanas</th><th>Notas</th></tr>
    <tr><td>Unión Europea (27 países)</td><td>No</td><td>Sin trámites aduaneros. El IVA depende del vendedor: ver <a href="iva.html">IVA e impuestos</a>. Plazo estimado {{PLAZO UE}}.</td></tr>
    <tr><td>Canarias</td><td>Sí (DUA)</td><td>Por ahora solo hay envíos <strong>dentro de Canarias</strong>. Entre Canarias y el resto de la UE no se envía hasta que la plataforma gestione los trámites aduaneros y fiscales.</td></tr>
    <tr><td>Reino Unido, Suiza, Noruega</td><td>Sí</td><td><strong>Próximamente.</strong> Reino Unido y Noruega exigen que el mercado cobre el IVA local en el pago de los envíos de bajo valor; activaremos estos destinos cuando estemos registrados. Plazo estimado {{PLAZO NO UE}}.</td></tr>
    <tr><td>Resto del mundo</td><td>—</td><td>No enviamos por ahora.</td></tr>
  </table>
  <p>El comprador es responsable de comprobar que recibir estos artículos es legal en su país.</p>

  <h2>2. Tarifas y plazos</h2>
  <p>Las tarifas dependen del país y del peso y se muestran antes de confirmar. Tarifas: {{TARIFAS}}. El vendedor prepara el envío en un máximo de {{DÍAS DE PREPARACIÓN}} días hábiles tras confirmarse el pago.</p>

  <h2>3. Embalaje discreto</h2>
  <ul>
    <li>La prenda va en bolsa hermética sellada, dentro de una caja o sobre neutro sin logos ni mención al sitio.</li>
    <li>Los transportistas exigen un remitente identificable. Se usa {{NOMBRE DE REMITENTE NEUTRO}} o un punto de recogida, nunca la dirección personal del vendedor.</li>
    <li>El extracto del cargo, si lo hay, no incluirá referencias al contenido del pedido: {{NOMBRE QUE APARECE EN EL EXTRACTO}}.</li>
  </ul>

  <h2>4. Punto de recogida y seguimiento</h2>
  <p>Puedes elegir entrega a domicilio o, donde esté disponible, en un punto de recogida o taquilla automática para mayor privacidad. Recibirás un número de seguimiento por correo.</p>

  <h2>5. Retrasos, pérdida y daños</h2>
  <p>El envío lo prepara y contrata el vendedor; Intimae no es el transportista. Si el pedido no llega en {{PLAZO MÁXIMO}} días, escribe primero al vendedor por mensajes y, si no se resuelve, abre una <a href="incidencias.html">incidencia</a> desde tu cuenta.</p>

  <h2>6. Devoluciones y reclamaciones</h2>
  <p>Si procede una devolución (por ejemplo, el desistimiento en compras a vendedores profesionales: ver <a href="condiciones-compra.html">condiciones de compra</a>), se acuerda con el vendedor, incluidos los gastos y el reembolso, y puedes abrir una <a href="incidencias.html">incidencia</a> si no hay acuerdo. La prenda debe devolverse en su bolsa original, sin otro uso. Que una prenda íntima esté desprecintada no excluye por sí solo tus derechos: ver la nota sobre higiene en las condiciones de compra. Mientras el pedido no se haya enviado puedes cancelarlo y recuperar el importe íntegro.</p>
""")


# ---------------------------------------------------------------- INCIDENCIAS
page("incidencias.html", "Incidencias y reclamaciones", """
  <p class="lead">Qué puedes hacer si hay un problema con un pedido, en qué plazos y qué puede y qué no puede hacer Intimae.</p>

  <h2>1. Papel de Intimae</h2>
  <p>La compraventa se celebra entre comprador y vendedor. Intimae es intermediario: facilita el contacto, el pago y el seguimiento, y ofrece este procedimiento. <strong>Intimae no puede garantizar reembolsos fuera de este procedimiento ni de las reglas del proveedor de pagos</strong> ({{PROVEEDOR DE PAGOS}}), y no limita tus derechos legales como consumidor ni tu posibilidad de acudir a un banco, a un organismo de consumo o a los tribunales.</p>

  <h2>2. Antes del envío</h2>
  <p>Puedes cancelar un pedido que aún no se ha enviado y recuperar el importe íntegro. El vendedor también puede cancelarlo; en ese caso se te devuelve todo.</p>

  <h2>3. Cuándo abrir una incidencia</h2>
  <p>Desde la ficha del pedido en tu cuenta, mientras el pago no se haya liquidado al vendedor. Motivos admitidos: pedido no enviado (pasado el plazo de preparación de {{PLAZO DE PREPARACIÓN}} días), pedido no recibido, producto distinto del anunciado, producto dañado, descripción engañosa, posible fraude, problema con el pago y problema de privacidad.</p>

  <h2>4. Cómo funciona</h2>
  <ol>
    <li>Abres la incidencia: indicas el motivo, describes lo ocurrido y, si quieres, adjuntas hasta dos fotos. El pedido pasa a «Incidencia» y la liquidación al vendedor queda en pausa.</li>
    <li>Avisamos al vendedor, que tiene {{PLAZO DE RESPUESTA DEL VENDEDOR}} días para responder. Si no responde, la incidencia pasa a revisión de Intimae sin su versión.</li>
    <li>Intimae revisa la información de las dos partes y decide dentro de sus facultades: reembolso total, reembolso parcial o rechazo de la incidencia. La decisión se motiva y se comunica a ambas partes.</li>
    <li>Si se acuerda un reembolso, se tramita por el proveedor de pagos conforme a sus reglas; si ya se había liquidado, puede descontarse de las siguientes liquidaciones del vendedor.</li>
    <li>El resultado queda registrado en el pedido.</li>
  </ol>

  <h2>5. Plazos</h2>
  <p>Plazo para abrir una incidencia: hasta la liquidación al vendedor ({{PLAZO DE LIQUIDACIÓN}} días tras la entrega). Plazo de respuesta del vendedor: {{PLAZO DE RESPUESTA DEL VENDEDOR}} días. Plazo de resolución por Intimae: {{PLAZO DE RESOLUCIÓN}} días desde que dispone de la información. Son plazos operativos, no sustituyen los legales.</p>

  <h2>6. Contracargos y disputas bancarias</h2>
  <p>Si abres una disputa con tu banco o con el emisor de tu tarjeta, el proveedor de pagos la gestionará según sus procedimientos y sus resultados pueden ser distintos de los de esta incidencia. Te recomendamos abrir primero la incidencia.</p>

  <h2>7. Desistimiento y garantía legal</h2>
  <p>Si compras a un vendedor profesional, puedes tener derecho de desistimiento y garantía legal, que se ejercen frente al vendedor (ver <a href="condiciones-compra.html">condiciones de compra</a>). Una incidencia no sustituye esos derechos.</p>

  <h2>8. Qué no cubre este procedimiento</h2>
  <ul>
    <li>Denuncias de contenido ilegal: ver <a href="normas.html">normas y denuncias</a>.</li>
    <li>Reclamaciones por daños personales, delitos o situaciones que exijan intervención de las autoridades.</li>
    <li>Pedidos ya liquidados fuera de plazo: puedes acudir al banco, a la vía de consumo o a los tribunales.</li>
  </ul>

  <h2>9. Contacto</h2>
  <p>Reclamaciones y atención al cliente: {{EMAIL DE RECLAMACIONES}}. Hojas de reclamaciones y entidad de resolución alternativa: {{HOJAS DE RECLAMACIONES Y ENTIDAD ADR}}.</p>
""")

# ---------------------------------------------------------------- CONDICIONES VENDEDORES
page("vendedores/condiciones.html", "Condiciones para vendedores", """
  <h2>1. Requisitos para vender</h2>
  <ul>
    <li>Ser mayor de 18 años. Para publicar, debes facilitar tus datos fiscales y superar la verificación de tu cuenta (edad e identidad) que realice el titular o su proveedor.</li>
    <li>Declarar si actúas como <strong>profesional</strong> (actividad habitual con ánimo de lucro) o <strong>particular</strong>. Es tu responsabilidad declararlo correctamente; el titular lo muestra a los compradores.</li>
    <li>Facilitar tus datos de contacto verdaderos: nombre, dirección, teléfono, correo, NIF o identificador fiscal y, si eres profesional, datos de registro. La plataforma los verifica y los conserva (art. 30 del Reglamento (UE) 2022/2065).</li>
  </ul>

  <h2>2. Qué puedes vender</h2>
  <ul>
    <li>Prendas íntimas que son tuyas y que has usado tú.</li>
    <li>Prohibido: prendas de terceros sin su consentimiento, artículos que impliquen a menores, falsificaciones, o cualquier descripción engañosa.</li>
    <li>Describe con honestidad los días de uso y el estado.</li>
  </ul>

  <h2>3. Contenido de tus anuncios</h2>
  <ul>
    <li>Las fotos del catálogo público no pueden mostrar desnudos ni imágenes sexualmente explícitas.</li>
    <li>Recomendamos no mostrar tu rostro ni elementos identificativos. Elimina los metadatos de las fotos.</li>
    <li>Solo subes imágenes de tu propiedad. Quien aparezca en ellas debe ser mayor de edad y haber consentido por escrito la publicación.</li>
  </ul>

  <h2>4. Precios, comisión y cobros</h2>
  <p>Fijas el precio. La plataforma cobra una comisión del {{COMISIÓN}} % sobre el precio de los artículos (no sobre el envío). El pago lo procesa el proveedor de pagos {{PROVEEDOR DE PAGOS}}; la liquidación se hace después de la entrega, {{PLAZO DE PAGO}} días después de que el comprador confirme la recepción o de que se dé por entregado ({{PLAZO DE ENTREGA AUTOMÁTICA}} días desde el envío), según el contrato con el proveedor y sus reglas. <strong>Si el comprador abre una incidencia, la liquidación de ese pedido queda en pausa hasta que se resuelva.</strong> Los reembolsos y contracargos que imponga el proveedor de pagos se descontarán de tus liquidaciones. Mientras no hayas enviado el pedido, tú o el comprador podéis cancelarlo y el importe se devuelve íntegro.</p>

  <h2>5. Impuestos y obligaciones fiscales</h2>
  <ul>
    <li>Eres responsable de declarar y pagar los impuestos que correspondan a tus ingresos (IRPF y, si eres profesional, IVA y alta de actividad).</li>
    <li>La normativa europea (Directiva DAC7) obliga a la plataforma a comunicar a la Administración tributaria los datos de los vendedores que superan ciertos umbrales de actividad. Aceptas que se comuniquen tus datos fiscales y el importe de tus ventas.</li>
    <li>Si vendes como profesional a consumidores de varios países de la UE, puedes tener obligaciones de IVA en cada país (ventanilla única, OSS). Consulta la <a href="iva.html">guía de IVA e impuestos</a>.</li>
    <li>Como profesional debes indicar tu número de IVA y tu régimen (general o de bienes usados). Comprobaremos el número en el sistema europeo de validación (VIES). Los vendedores particulares no cobran IVA.</li>
    <li>No existe un umbral único en la UE para pasar de particular a profesional: depende de la regularidad y el ánimo de lucro y de cada país. Si dudas, consulta a tu administración tributaria. Declarar mal tu condición es tu responsabilidad.</li>
    <li><strong>Vendedores de Canarias:</strong> Canarias está fuera del territorio de IVA de la UE y se aplica el IGIC. Por ahora solo se admiten envíos dentro de Canarias. El tipo y el régimen aplicados son una estimación pendiente de validar por un asesor fiscal.</li>
    <li><strong>Vendedores de fuera de la UE:</strong> por ahora solo puedes vender dentro de tu propio país. Enviar a la UE desde fuera exige registros de IVA y derechos de aduana que la plataforma aún no gestiona.</li>
  </ul>

  <h2>6. Envíos, devoluciones y reclamaciones</h2>
  <p>Debes enviar en el plazo indicado en <a href="envios.html">envíos y entrega</a>, con bolsa sellada, embalaje neutro y sin incluir tus datos personales, e indicar el transportista y el seguimiento en tu panel.</p>
  <p>Eres el responsable frente al comprador de la conformidad de la prenda, la entrega y, si vendes como profesional, del desistimiento y la garantía legal que la ley le reconozca. Si un comprador abre una <a href="incidencias.html">incidencia</a>, debes responder en el plazo indicado en la política de incidencias; si no respondes, la incidencia pasa a revisión de Intimae sin tu versión.</p>

  <h2>7. Tu seguridad</h2>
  <ul>
    <li>Usa solo el sistema de mensajes de la plataforma. No compartas tu dirección, teléfono ni redes sociales.</li>
    <li>No aceptes pedidos que te incomoden. Puedes rechazar cualquier petición sin dar explicaciones.</li>
    <li>Informa de cualquier acoso o presión a {{EMAIL DE CONTACTO}}. Tomaremos medidas contra el comprador.</li>
  </ul>

  <h2>8. Salud e higiene</h2>
  <p>Las prendas usadas pueden transmitir infecciones. Declaras que la información que das sobre su uso es veraz y que envías la prenda en bolsa hermética. Informa al comprador de cualquier circunstancia relevante.</p>

  <h2>9. Moderación, sanciones y reclamaciones</h2>
  <p>Podemos retirar anuncios, suspender o cancelar cuentas que incumplan estas condiciones o la ley. Te informaremos de la decisión y de sus motivos, y podrás reclamar a través del sistema interno descrito en <a href="normas.html">normas y denuncias</a>.</p>

  <h2>10. Terminación y datos</h2>
  <p>Puedes cerrar tu cuenta cuando quieras tras completar los pedidos en curso. Tus datos se tratan según la <a href="privacidad.html">política de privacidad</a>.</p>
""", zone="seller")

# ---------------------------------------------------------------- NORMAS / DSA
page("normas.html", "Normas de la plataforma y denuncias", """
  <h2>1. Qué no se permite</h2>
  <ul>
    <li>Cualquier contenido que implique a menores de edad. <strong>Tolerancia cero.</strong></li>
    <li>Contenido sin consentimiento de las personas que aparecen o de su titular.</li>
    <li>Coacción, acoso, amenazas, explotación o trata de personas.</li>
    <li>Suplantación, fraude, falsificaciones y datos personales de terceros.</li>
    <li>Cualquier otro contenido ilegal según la ley aplicable.</li>
  </ul>

  <h2>2. Cómo denunciar contenido ilegal</h2>
  <p>Cualquier persona, tenga o no cuenta, puede notificar un contenido que considere ilegal con el botón «Denunciar este anuncio» de cada ficha o escribiendo a {{EMAIL DE DENUNCIAS}}. Cada denuncia recibe un número de seguimiento. Debe incluir:</p>
  <ol>
    <li>Una explicación de por qué considera ilegal el contenido.</li>
    <li>La dirección exacta (URL) del contenido.</li>
    <li>Su nombre y correo, salvo en denuncias de abuso sexual infantil, donde no es necesario.</li>
    <li>Una declaración de que la denuncia se hace de buena fe y es exacta y completa.</li>
  </ol>
  <p>Acusaremos recibo, evaluaremos con diligencia y te comunicaremos la decisión y las vías de recurso.</p>

  <h2>3. Abuso sexual infantil</h2>
  <p>Retiramos de inmediato el contenido, conservamos las pruebas que exija la ley y lo comunicamos a las autoridades competentes ({{AUTORIDAD O LÍNEA DE DENUNCIA}}). Si ves este tipo de contenido, no lo descargues ni compartas: denúncialo a las autoridades de tu país.</p>

  <h2>4. Medidas</h2>
  <p>Según la gravedad y la reiteración podemos: retirar el contenido, restringir funciones, suspender o cancelar la cuenta y, en su caso, informar a las autoridades. Siempre comunicamos al afectado la decisión y sus motivos, salvo que la ley lo impida.</p>

  <h2>5. Reclamar una decisión de moderación</h2>
  <p>Esto se refiere a nuestras decisiones de moderación sobre anuncios y cuentas; las incidencias sobre pedidos siguen el <a href="incidencias.html">procedimiento de incidencias</a>. Puedes impugnar nuestra decisión durante 6 meses desde que la recibes, escribiendo a {{EMAIL DE RECLAMACIONES}}. La revisará una persona distinta de quien la tomó. También puedes acudir a un organismo de resolución extrajudicial certificado: {{ORGANISMO CERTIFICADO}}.</p>

  <h2>6. Cómo se ordenan los anuncios</h2>
  <p>El orden del catálogo depende de lo que elijas (novedad, precio, días de uso). No hacemos perfiles tuyos para recomendar anuncios y no mostramos publicidad.</p>

  <h2>7. Punto de contacto</h2>
  <p>{{EMAIL DE CONTACTO}}. Consulta el <a href="aviso-legal.html">aviso legal</a> para los datos completos del titular.</p>
""")

# ---------------------------------------------------------------- IVA
tax_js = (OUT / "js" / "tax.js").read_text(encoding="utf-8")
rates = re.findall(r'\["([A-Z]{2})", "([^"]+)", ([0-9.]+)\]', tax_js)
def fmt(r): return r.replace(".", ",")
rate_items = "".join(f'<li><span>{n}</span><span class="num">{fmt(r)} %</span></li>' for c, n, r in rates)
page("vendedores/impuestos.html", "Impuestos para vendedores", f"""
  <p class="lead">Qué cobras y qué declaras según vendas como particular o como profesional, y qué reglas aplican si vives fuera de la UE. Es información general; no sustituye a un asesor fiscal.</p>

  <h2>1. Resumen</h2>
  <table>
    <tr><th>Quién vende</th><th>Qué ves</th><th>IVA</th><th>Normas de consumo</th></tr>
    <tr><td>Particular (UE)</td><td>Precio final</td><td>No se cobra</td><td>No se aplican</td></tr>
    <tr><td>Profesional, bienes usados (UE)</td><td>IVA incluido, sin desglosar</td><td>Régimen especial: IVA solo sobre el margen</td><td>Se aplican</td></tr>
    <tr><td>Profesional, régimen general (UE)</td><td>IVA desglosado</td><td>Del país del vendedor; tras 10.000 € de ventas a otros países de la UE, del país de destino</td><td>Se aplican</td></tr>
    <tr><td>Fuera de la UE</td><td>Solo vende en su país</td><td>El de su país</td><td>Según su país</td></tr>
  </table>

  <h2>2. Particular o profesional</h2>
  <p>La directiva Omnibus obliga a los mercados a indicar si el vendedor es profesional, según su propia declaración. Las normas de consumo de la UE (desistimiento y garantía legal) solo protegen frente a profesionales.</p>
  <p>No hay un umbral único en la UE para pasar de particular a profesional. La regularidad de las ventas a lo largo del tiempo suele indicar actividad económica, y cada país fija sus propios criterios. Si vendes de forma habitual o con ánimo de lucro, probablemente seas profesional a efectos de IVA.</p>

  <h2>3. Régimen especial de bienes usados</h2>
  <p>Un revendedor profesional que compra bienes usados a particulares puede acogerse a un régimen en el que el IVA solo grava su margen. En ese caso la factura no desglosa el IVA, por eso verás "IVA incluido" sin importe. Según las fuentes consultadas, las ventas a distancia de bienes en este régimen tributan en el país de salida y no en el de destino, y el régimen no se aplica cuando es la plataforma quien actúa como proveedor a efectos de IVA. Un asesor debe confirmarlo para cada caso.</p>

  <h2>4. Ventas a distancia dentro de la UE y ventanilla única</h2>
  <p>Hay un umbral único de 10.000 € al año para las ventas a distancia a consumidores de otros países de la UE. Por debajo, el vendedor aplica el IVA de su país. Por encima, debe aplicar el IVA del país del comprador y puede declararlo todo en un solo lugar con la ventanilla única (OSS). Cuando se supera el umbral, el precio que ves en la ficha cambiará según tu país de destino.</p>

  <h2>5. Vendedores de fuera de la UE</h2>
  <p>Por ahora solo pueden vender dentro de su propio país. Las razones:</p>
  <ul>
    <li>Cuando un mercado facilita la venta de bienes importados de hasta 150 €, se le considera proveedor a efectos de IVA, y puede ser responsable solidario si el vendedor incumple.</li>
    <li>Desde el 1 de julio de 2026 y hasta el 1 de julio de 2028, la UE aplica un derecho de aduana fijo de 3 € por artículo en los envíos de hasta 150 €, incluso con la ventanilla de importación (IOSS). Puede haber tasas de gestión adicionales que aún se están definiendo.</li>
    <li>Para el IOSS, un vendedor de fuera puede necesitar un intermediario establecido en la UE.</li>
  </ul>

  <h2>6. Reino Unido, Noruega y Suiza</h2>
  <p>Son destinos <strong>próximos</strong>, no activos:</p>
  <ul>
    <li><strong>Reino Unido:</strong> para envíos de hasta 135 £, el mercado debe cobrar el IVA en el momento de la venta. Para envíos mayores se aplican las reglas normales de importación.</li>
    <li><strong>Noruega:</strong> el umbral de bajo valor es de 3.000 NOK por artículo y los mercados pueden ser responsables del IVA. Sin número de registro VOEC, los envíos de bajo valor se retienen en la frontera.</li>
    <li><strong>Suiza:</strong> pendiente de analizar.</li>
  </ul>
  <p>Activaremos estos destinos cuando el mercado esté registrado en cada país.</p>

  <h2>7. Canarias</h2>
  <p>Canarias queda fuera del territorio de IVA de la UE: allí se aplica el IGIC (tipo general del 7 %, estimación pendiente de validar) y no el IVA. Los vendedores profesionales de Canarias muestran el IGIC en la ficha, o el régimen especial de bienes usados del IGIC si se acogen a él. Los envíos entre Canarias y el resto de la UE requieren trámites aduaneros y fiscales (DUA) que la plataforma aún no gestiona, por lo que por ahora solo se admiten envíos <strong>dentro de Canarias</strong>. {{CRITERIO DEL ASESOR FISCAL CANARIO: tipo, régimen, alta en registros y obligaciones de la comisión}}</p>

  <h2>8. Tipos generales de IVA</h2>
  <p>Tipos generales vigentes en el momento de redactar este documento. Verifícalos en la base de datos de tipos de IVA de la Comisión Europea antes de operar.</p>
  <ul class="rates">{rate_items}</ul>

  <h2>9. Qué hace Intimae con los datos fiscales de los vendedores</h2>
  <p>Recogemos y verificamos tus datos de identificación y el número de IVA, y comunicamos a la Administración tributaria la actividad de los vendedores que superen los umbrales de la directiva DAC7. Más detalle en la <a href="privacidad.html">política de privacidad</a> y en las <a href="condiciones.html">condiciones para vendedores</a>.</p>

  <h2>10. Fuentes</h2>
  <ul class="sources">
    <li><a href="https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en" target="_blank" rel="noopener noreferrer">Comisión Europea: ventanilla única (OSS)</a></li>
    <li><a href="https://trade.ec.europa.eu/access-to-markets/en/news/eu-applies-eu3-customs-duty-item-low-value-e-commerce-consignments" target="_blank" rel="noopener noreferrer">Comisión Europea: derecho de 3 € por artículo</a></li>
    <li><a href="https://www.gov.uk/guidance/vat-and-overseas-goods-sold-to-customers-in-the-uk-using-online-marketplaces" target="_blank" rel="noopener noreferrer">GOV.UK: mercados en línea y envíos al Reino Unido</a></li>
    <li><a href="https://www.toll.no/en/corporate/import/the-voec-scheme" target="_blank" rel="noopener noreferrer">Aduana de Noruega: esquema VOEC</a></li>
    <li><a href="https://revenue.ie/en/tax-professionals/tdm/value-added-tax/part10-special-schemes/vat-ecommerce-rules/deemed-supplier.pdf" target="_blank" rel="noopener noreferrer">Revenue (Irlanda): proveedor presunto</a></li>
    <li><a href="https://www.europa.eu/youreurope/business/taxation/vat/vat-rules-rates" target="_blank" rel="noopener noreferrer">Your Europe: normas y tipos de IVA</a></li>
  </ul>
""", zone="seller")

page("iva.html", "IVA e impuestos", f"""
  <p class="lead">Qué impuestos verás según quién vende y adónde se envía. Es información general; no sustituye a un asesor fiscal.</p>

  <h2>1. Resumen</h2>
  <table>
    <tr><th>Quién vende</th><th>Qué ves</th><th>IVA</th><th>Normas de consumo</th></tr>
    <tr><td>Particular (UE)</td><td>Precio final</td><td>No se cobra</td><td>No se aplican</td></tr>
    <tr><td>Profesional, bienes usados (UE)</td><td>IVA incluido, sin desglosar</td><td>Régimen especial: IVA solo sobre el margen</td><td>Se aplican</td></tr>
    <tr><td>Profesional, régimen general (UE)</td><td>IVA desglosado</td><td>Del país del vendedor; tras 10.000 € de ventas a otros países de la UE, del país de destino</td><td>Se aplican</td></tr>
    <tr><td>Vendedor fuera de la UE</td><td>Solo vende en su país</td><td>El de su país</td><td>Según su país</td></tr>
  </table>

  <h2>2. Particular o profesional</h2>
  <p>Cada ficha indica si el vendedor es particular o profesional, según su propia declaración. Las normas de consumo de la UE (desistimiento y garantía legal) solo te protegen frente a profesionales. Con un particular rige el derecho civil de su país.</p>

  <h2>3. Precio con IVA incluido y sin desglosar</h2>
  <p>Algunos profesionales revenden bienes usados bajo un régimen especial en el que el IVA solo grava su margen. Por ley no pueden desglosarlo: verás «IVA incluido» sin importe. Según las fuentes consultadas, estas ventas a distancia tributan en el país de salida y no en el de destino. Un asesor debe confirmarlo para cada caso.</p>

  <h2>4. Envíos fuera de la UE</h2>
  <p>Reino Unido, Noruega y Suiza son destinos <strong>próximos</strong>, no activos. Reino Unido y Noruega exigen que el mercado cobre el IVA local en el momento del pago, y todavía no estamos registrados. Los vendedores de fuera de la UE solo venden dentro de su propio país.</p>

  <h2>5. Canarias</h2>
  <p>Canarias está fuera del territorio de IVA de la UE y allí se aplica el IGIC en lugar del IVA (estimación pendiente de validar por un asesor fiscal). Por ahora solo se admiten envíos dentro de Canarias; entre Canarias y el resto de la UE hacen falta trámites aduaneros y fiscales que la plataforma aún no gestiona.</p>

  <h2>6. Tipos generales de IVA</h2>
  <p>Tipos generales vigentes en el momento de redactar este documento. Verifícalos en la base de datos de tipos de IVA de la Comisión Europea.</p>
  <ul class="rates">{rate_items}</ul>

  <h2>7. Fuentes</h2>
  <ul class="sources">
    <li><a href="https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en" target="_blank" rel="noopener noreferrer">Comisión Europea: ventanilla única (OSS)</a></li>
    <li><a href="https://www.gov.uk/guidance/vat-and-overseas-goods-sold-to-customers-in-the-uk-using-online-marketplaces" target="_blank" rel="noopener noreferrer">GOV.UK: mercados en línea y envíos al Reino Unido</a></li>
    <li><a href="https://www.toll.no/en/corporate/import/the-voec-scheme" target="_blank" rel="noopener noreferrer">Aduana de Noruega: esquema VOEC</a></li>
    <li><a href="https://www.europa.eu/youreurope/business/taxation/vat/vat-rules-rates" target="_blank" rel="noopener noreferrer">Your Europe: normas y tipos de IVA</a></li>
  </ul>
""")

# ---------------------------------------------------------------- INDICE (legal.html)
index_links = "".join(f'<li><a href="{h}">{t}</a></li>' for h, t in NAV)
pending = [
    ("Titular", "Nombre y apellidos o denominación social"),
    ("NIF / CIF", "Identificador fiscal"),
    ("Domicilio", "Dirección completa"),
    ("Correo y teléfono", "Contacto, denuncias, autoridades y reclamaciones (pendiente por ahora)"),
    ("Datos registrales", "Solo si es sociedad"),
    ("Dominio", "Nombre del sitio"),
    ("Proveedores", "Pagos, verificación de identidad y edad, alojamiento"),
    ("Plazos de incidencias", "Preparación, respuesta del vendedor, resolución y liquidación"),
    ("Condiciones comerciales", "Comisión, plazos de entrega automática y de pago, tarifas y plazos de envío, garantía"),
    ("Reclamaciones", "Hojas de reclamaciones, entidad ADR, organismo certificado DSA"),
    ("Jurisdicción", "Ciudad de los tribunales"),
]
rows = "".join(f"<tr><th>{a}</th><td>{b}</td></tr>" for a, b in pending)
page("legal.html", "Información legal", f"""
  <p>Documentos legales del sitio, redactados para una plataforma de compraventa de lencería usada entre adultos, con vendedores particulares y profesionales y envíos por Europa.</p>
  <ul class="doclist">{index_links}</ul>
  <p>Los documentos para vendedores están en el <a href="vendedores/">área de vendedores</a>.</p>

  <h2>Datos pendientes de titularidad</h2>
  <p>Estos datos aparecen resaltados en cada documento y hay que completarlos antes de operar:</p>
  <table>{rows}</table>
""")

print("páginas generadas")
