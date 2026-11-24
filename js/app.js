(function () {
  "use strict";

  // Configuración: se completará cuando haya titularidad y correos reales.
  var CONFIG = {
    orderEmail: "pedidos@example.com",
    sellerEmail: "vendedores@example.com"
  };

  var UTM = "?utm_source=intimae&utm_medium=referral";
  var TYPE_LABEL = { braga: "Braga", tanga: "Tanga", sujetador: "Sujetador", camison: "Camisón", conjunto: "Lote" };
  var money = TAX.money;

  var $ = function (s, r) { return (r || document).querySelector(s); };
  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function icon(id) {
    var s = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    s.setAttribute("class", "icon");
    s.setAttribute("aria-hidden", "true");
    var u = document.createElementNS("http://www.w3.org/2000/svg", "use");
    u.setAttribute("href", "#" + id);
    s.appendChild(u);
    return s;
  }
  function photo(p, w, h) {
    return p.img + "?ixlib=rb-4.1.0&auto=format&fit=crop&crop=entropy&w=" + w + "&h=" + h + "&q=75";
  }
  function byId(id) { return window.PRODUCTS.filter(function (p) { return p.id === id; })[0]; }
  function countryName(code) { var c = TAX.get(code); return c ? c.name : code; }

  /* ---------- Confirmación de edad ---------- */
  var gate = $("#agegate");
  if (store.get("intimae_age_ok") !== "1") {
    gate.showModal();
    gate.addEventListener("cancel", function (e) { e.preventDefault(); });
  }
  $("#ag-yes").addEventListener("click", function () {
    store.set("intimae_age_ok", "1");
    gate.close();
  });

  /* ---------- Países ---------- */
  var destSel = $("#dest");
  function fillCountries(sel, withGroups) {
    var eu = TAX.countries.filter(function (c) { return c.eu; });
    var non = TAX.countries.filter(function (c) { return !c.eu; });
    function opt(c) { var o = el("option", null, c.name + (c.open ? "" : " (próximamente)")); o.value = c.code; return o; }
    if (withGroups) {
      var g1 = document.createElement("optgroup"); g1.label = "Unión Europea";
      eu.forEach(function (c) { g1.appendChild(opt(c)); });
      var g2 = document.createElement("optgroup"); g2.label = "Fuera de la UE";
      non.forEach(function (c) { g2.appendChild(opt(c)); });
      sel.appendChild(g1); sel.appendChild(g2);
    } else {
      TAX.countries.forEach(function (c) { sel.appendChild(opt(c)); });
    }
  }
  fillCountries(destSel, true);
  fillCountries($("#s-country"), true);

  var dest = store.get("intimae_dest");
  if (!TAX.get(dest)) {
    var lang = (navigator.language || "es-ES").split("-")[1];
    dest = lang && TAX.get(lang.toUpperCase()) ? lang.toUpperCase() : "ES";
  }
  destSel.value = dest;
  $("#s-country").value = dest;
  destSel.addEventListener("change", function () {
    dest = destSel.value;
    store.set("intimae_dest", dest);
    renderGrid(); renderCart();
    if (pdp.open && pdpCurrent) fillPdp(pdpCurrent);
  });

  /* ---------- Catálogo ---------- */
  var grid = $("#grid"), empty = $("#empty"), countEl = $("#count");
  var f = { type: $("#f-type"), size: $("#f-size"), days: $("#f-days"), sort: $("#f-sort") };

  function card(p) {
    var s = SELLERS[p.seller];
    var sh = TAX.shippable(p, s, dest);
    var a = sh.ok ? TAX.assess(p, s, dest) : null;

    var c = el("article", "pcard" + (sh.ok ? "" : " is-off"));
    var media = el("div", "pcard__media");
    var img = new Image();
    img.src = photo(p, 640, 800); img.width = 640; img.height = 800;
    img.alt = p.title; img.loading = "lazy"; img.decoding = "async";
    media.appendChild(img);
    media.appendChild(el("span", "tag num", p.days + (p.days === 1 ? " día" : " días") + " de uso"));
    var cr = el("a", "credit", "Foto: " + p.by);
    cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM;
    cr.target = "_blank"; cr.rel = "noopener noreferrer";
    media.appendChild(cr);
    if (!sh.ok) media.appendChild(el("span", "off-label", "No disponible para " + countryName(dest)));
    media.addEventListener("click", function (e) { if (e.target.closest("a")) return; openPdp(p); });

    var body = el("div", "pcard__body");
    var top = el("div", "pcard__top");
    top.appendChild(el("span", "num", "N.º " + p.ref));
    top.appendChild(el("span", null, s.country));
    body.appendChild(top);
    var h = el("h3", "pcard__title");
    var hb = el("button", null, p.title); hb.type = "button";
    hb.addEventListener("click", function () { openPdp(p); });
    h.appendChild(hb);
    body.appendChild(h);
    body.appendChild(el("p", "pcard__meta", TYPE_LABEL[p.type] + " · Talla " + p.size + " · " + s.alias + " · " + (s.type === "particular" ? "Particular" : "Profesional")));

    var pr = el("div", "pcard__price");
    pr.appendChild(el("span", "price num", money(a ? a.unit : p.price)));
    pr.appendChild(el("span", "taxnote", a ? a.title : "Solo envía en " + countryName(s.country)));
    body.appendChild(pr);

    var act = el("div", "pcard__actions");
    var add = el("button", "btn btn--sm", "Añadir"); add.type = "button";
    add.disabled = !sh.ok;
    add.addEventListener("click", function () { addToCart(p.id, true); });
    var more = el("button", "link", "Ver ficha"); more.type = "button";
    more.addEventListener("click", function () { openPdp(p); });
    act.appendChild(add); act.appendChild(more);
    body.appendChild(act);

    c.appendChild(media); c.appendChild(body);
    return c;
  }

  function renderGrid() {
    var minDays = +f.days.value;
    var list = window.PRODUCTS.filter(function (p) {
      return (!f.type.value || p.type === f.type.value) && (!f.size.value || p.size === f.size.value) && p.days >= minDays;
    });
    var s = f.sort.value;
    list.sort(function (a, b) {
      if (s === "asc") return a.price - b.price;
      if (s === "desc") return b.price - a.price;
      if (s === "days") return b.days - a.days;
      return a.date < b.date ? 1 : -1;
    });
    grid.textContent = "";
    list.forEach(function (p) { grid.appendChild(card(p)); });
    empty.hidden = list.length > 0;
    countEl.textContent = list.length + (list.length === 1 ? " pieza" : " piezas");
  }
  Object.keys(f).forEach(function (k) { f[k].addEventListener("change", renderGrid); });

  /* ---------- Ficha de producto ---------- */
  var pdp = $("#pdp"), pdpCurrent = null;
  function fillPdp(p) {
    var s = SELLERS[p.seller];
    var sh = TAX.shippable(p, s, dest);
    var a = sh.ok ? TAX.assess(p, s, dest) : null;

    var img = $("#pdp-img");
    img.src = photo(p, 900, 1125); img.alt = p.title;
    var cr = $("#pdp-credit");
    cr.textContent = "Foto: " + p.by;
    cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM;

    $("#pdp-ref").textContent = TYPE_LABEL[p.type] + " · N.º " + p.ref;
    $("#pdp-title").textContent = p.title;

    var line = $("#pdp-seller"); line.textContent = "";
    var v = el("span", "badge badge--ok"); v.appendChild(icon("i-check")); v.lastChild.style.cssText = "width:12px;height:12px"; v.appendChild(document.createTextNode("Verificado"));
    line.appendChild(v);
    line.appendChild(el("span", null, s.alias + " · " + countryName(s.country)));
    line.appendChild(el("span", "badge", s.type === "particular" ? "Particular" : "Profesional"));

    $("#pdp-price").textContent = money(a ? a.unit : p.price);

    var box = $("#pdp-tax"); box.textContent = "";
    if (a) {
      box.appendChild(el("strong", null, a.title));
      box.appendChild(el("p", null, a.note));
      if (a.extra) box.appendChild(el("p", "warn", a.extra));
      var shipLine = el("p", null, "Envío estimado a " + countryName(dest) + ": " + money(TAX.shippingFor(a.zone)) + " (tarifa de demostración).");
      box.appendChild(shipLine);
    } else {
      box.appendChild(el("strong", null, "No disponible para " + countryName(dest)));
      box.appendChild(el("p", "warn", sh.reason));
    }

    var sp = $("#pdp-specs"); sp.textContent = "";
    [["Talla", p.size], ["Uso", p.days + (p.days === 1 ? " día" : " días")], ["Estado", "Usada, sin lavar"],
     ["Material", p.material], ["Color", p.colour], ["Envía desde", countryName(s.country)], ["Vendedor desde", String(s.since)]
    ].forEach(function (r) { sp.appendChild(el("dt", null, r[0])); sp.appendChild(el("dd", null, r[1])); });

    $("#pdp-add").disabled = !sh.ok;
    $("#pdp-report").href = "mailto:" + CONFIG.orderEmail + "?subject=" + encodeURIComponent("Denuncia del anuncio N.º " + p.ref) +
      "&body=" + encodeURIComponent("Anuncio: " + p.title + " (N.º " + p.ref + ")\nMotivo:\nExplicación:\nMi nombre y correo:\nDeclaro que esta denuncia se hace de buena fe y que es exacta y completa.");
  }
  function openPdp(p) { pdpCurrent = p; fillPdp(p); pdp.showModal(); }
  $("#pdp-add").addEventListener("click", function () { if (pdpCurrent) { addToCart(pdpCurrent.id, true); } });

  /* ---------- Cerrar diálogos ---------- */
  document.querySelectorAll("dialog").forEach(function (d) {
    d.addEventListener("click", function (e) { if (e.target === d && d.id !== "agegate") d.close(); });
    d.querySelectorAll("[data-close]").forEach(function (b) { b.addEventListener("click", function () { d.close(); }); });
  });

  /* ---------- Pedido ---------- */
  var cart = [];
  try {
    cart = JSON.parse(store.get("intimae_cart") || "[]").filter(function (id) { return !!byId(id); });
  } catch (e) { cart = []; }
  var cartDlg = $("#cart");
  $("#open-cart").addEventListener("click", function () { renderCart(); cartDlg.showModal(); });

  function addToCart(id, open) {
    if (cart.indexOf(id) === -1) cart.push(id);
    saveCart();
    if (pdp.open) pdp.close();
    if (open) { renderCart(); cartDlg.showModal(); }
  }
  function saveCart() { store.set("intimae_cart", JSON.stringify(cart)); renderCart(); }

  function calc() {
    var r = { lines: [], sub: 0, vat: 0, ship: 0, off: 0, exportZone: false, sellers: 0 };
    var zones = {};
    cart.forEach(function (id) {
      var p = byId(id), s = SELLERS[p.seller], sh = TAX.shippable(p, s, dest);
      if (!sh.ok) { r.off++; r.lines.push({ p: p, s: s, ok: false, reason: sh.reason }); return; }
      var a = TAX.assess(p, s, dest);
      r.sub += a.unit; r.vat += a.vatIncluded;
      if (a.zone === "export") r.exportZone = true;
      zones[p.seller] = a.zone;
      r.lines.push({ p: p, s: s, ok: true, a: a });
    });
    Object.keys(zones).forEach(function (k) { r.ship += TAX.shippingFor(zones[k]); r.sellers++; });
    return r;
  }

  function renderCart() {
    var r = calc();
    $("#cart-count").textContent = cart.length;
    var box = $("#lines"); box.textContent = "";
    $("#o-country").value = countryName(dest);

    if (!cart.length) {
      box.appendChild(el("p", "cart__empty", "Tu pedido está vacío."));
      $("#cart-foot").hidden = true;
      return;
    }
    $("#cart-foot").hidden = false;

    r.lines.forEach(function (l) {
      var row = el("div", "line");
      var im = new Image(); im.src = photo(l.p, 160, 200); im.alt = ""; im.width = 72; im.height = 90;
      row.appendChild(im);
      var info = el("div");
      info.appendChild(el("h3", null, l.p.title));
      info.appendChild(el("small", null, l.s.alias + " · " + countryName(l.s.country)));
      if (!l.ok) { var w = el("small", null, "No disponible para " + countryName(dest) + "."); w.style.color = "var(--danger)"; info.appendChild(w); }
      var rm = el("button", "rm", "Quitar"); rm.type = "button";
      rm.addEventListener("click", function () { cart = cart.filter(function (x) { return x !== l.p.id; }); saveCart(); });
      info.appendChild(rm);
      row.appendChild(info);
      row.appendChild(el("span", "price num", l.ok ? money(l.a.unit) : "—"));
      box.appendChild(row);
    });

    var sum = $("#sum"); sum.textContent = "";
    function row(a, b, cls) { var d = el("div", cls || null); d.appendChild(el("span", null, a)); d.appendChild(el("span", "num", b)); sum.appendChild(d); }
    row("Subtotal", money(r.sub));
    row("Envío estimado" + (r.sellers > 1 ? " (" + r.sellers + " vendedores)" : ""), money(r.ship));
    if (r.vat > 0) row("IVA incluido en el subtotal", money(r.vat), "muted");
    row("Total", money(r.sub + r.ship), "tot");

    var note = $("#cart-note"), msgs = [];
    msgs.push("Las tarifas de envío son de demostración.");
    if (!TAX.get(dest).open) msgs.push("Los envíos a " + countryName(dest) + " estarán disponibles próximamente: el mercado debe cobrar el IVA local en el pago y aún no estamos registrados para ello.");
    if (r.off) msgs.push("Quita los artículos no disponibles para continuar.");
    note.textContent = msgs.join(" ");
    note.hidden = false;
  }

  var orderMsg = $("#order-msg");
  function setMsg(node, text, err) { node.textContent = text; node.className = "msg" + (err ? " err" : ""); }
  function mailto(to, subject, body) {
    window.location.href = "mailto:" + to + "?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body);
  }

  $("#order-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, r = calc();
    if (!cart.length) return setMsg(orderMsg, "Añade al menos una prenda.", true);
    if (!TAX.get(dest).open) return setMsg(orderMsg, "Los envíos a " + countryName(dest) + " estarán disponibles próximamente. Elige un país de la UE.", true);
    if (r.off) return setMsg(orderMsg, "Quita los artículos no disponibles para tu destino.", true);
    if (!form.checkValidity()) return setMsg(orderMsg, "Completa los campos obligatorios y acepta las dos confirmaciones.", true);
    var d = new FormData(form);
    var lines = r.lines.map(function (l) {
      return "- N.º " + l.p.ref + " " + l.p.title + " · " + l.s.alias + " (" + l.s.country + ", " + l.s.type + ") · " + money(l.a.unit);
    });
    var body = "Pedido\n\n" + lines.join("\n") +
      "\n\nSubtotal: " + money(r.sub) + "\nEnvío estimado: " + money(r.ship) + "\nTotal: " + money(r.sub + r.ship) +
      "\n\nNombre: " + d.get("name") + "\nCorreo: " + d.get("email") + "\nEntrega: " + d.get("addr") + "\nPaís: " + countryName(dest) +
      "\nPago: " + d.get("pay") + "\nPetición: " + (d.get("note") || "-") +
      "\n\nMayor de 18 años y condiciones aceptadas: sí\nConsentimiento expreso (art. 9.2.a RGPD): sí";
    mailto(CONFIG.orderEmail, "Nuevo pedido Intimae", body);
    setMsg(orderMsg, "Se abrirá tu correo con el pedido. Te responderemos con las instrucciones de pago.");
  });

  /* ---------- Solicitud de vendedor ---------- */
  var kindHint = $("#kind-hint"), proFields = $("#pro-fields");
  var HINTS = {
    particular: "Vendes artículos propios de forma ocasional. No cobras IVA y no se aplican las normas de consumo.",
    profesional: "Vendes de forma habitual o con ánimo de lucro. Cobras IVA según tu régimen y sí se aplican las normas de consumo."
  };
  document.querySelectorAll("input[name=kind]").forEach(function (r) {
    r.addEventListener("change", function () {
      kindHint.textContent = HINTS[r.value];
      proFields.hidden = r.value !== "profesional";
    });
  });

  $("#seller-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, m = $("#seller-msg"), d = new FormData(form);
    if (+d.get("age") < 18) return setMsg(m, "Debes ser mayor de 18 años para vender.", true);
    if (!form.checkValidity()) return setMsg(m, "Completa los campos obligatorios y acepta las condiciones.", true);
    var pro = d.get("kind") === "profesional";
    var vat = String(d.get("vatid") || "").replace(/\s+/g, "").toUpperCase();
    if (pro && vat && !/^[A-Z]{2}[0-9A-Z]{8,12}$/.test(vat)) return setMsg(m, "El número de IVA debe empezar por el código de país, por ejemplo ESB12345678.", true);
    var c = TAX.get(d.get("country"));
    var outside = c && !c.eu;
    var body = "Alias: " + d.get("alias") + "\nCorreo: " + d.get("email") + "\nPaís: " + (c ? c.name : "") + "\nEdad: " + d.get("age") +
      "\nVende como: " + d.get("kind") + (pro ? "\nNúmero de IVA: " + (vat || "-") + "\nRégimen: " + (d.get("regime") || "sin indicar") : "") +
      "\n\n" + (d.get("about") || "");
    mailto(CONFIG.sellerEmail, "Solicitud de vendedor: " + d.get("alias"), body);
    setMsg(m, outside
      ? "Se abrirá tu correo. Al estar fuera de la UE, de momento solo podrás vender dentro de " + c.name + "."
      : "Se abrirá tu correo con la solicitud. Te pediremos la verificación de identidad en el siguiente paso.");
  });

  /* ---------- Menú móvil y aparición suave ---------- */
  var burger = $("#burger"), menu = $("#menu");
  burger.addEventListener("click", function () {
    var open = menu.classList.toggle("open");
    burger.setAttribute("aria-expanded", String(open));
  });
  menu.addEventListener("click", function (e) { if (e.target.tagName === "A") { menu.classList.remove("open"); burger.setAttribute("aria-expanded", "false"); } });

  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    revealEls.forEach(function (n) { io.observe(n); });
  } else {
    revealEls.forEach(function (n) { n.classList.add("in"); });
  }

  renderGrid();
  renderCart();
})();
