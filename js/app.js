/* Intimae · tienda (zona de compradores) */
(function () {
  "use strict";

  // Configuración: se completará cuando haya titularidad y correos reales.
  var CONFIG = { orderEmail: "pedidos@example.com" };
  var UTM = "?utm_source=intimae&utm_medium=referral";

  var t = I18N.t, money = I18N.money;
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
    s.setAttribute("class", "icon"); s.setAttribute("aria-hidden", "true");
    var u = document.createElementNS("http://www.w3.org/2000/svg", "use");
    u.setAttribute("href", "#" + id); s.appendChild(u);
    return s;
  }
  function photo(p, w, h) { return p.img + "?ixlib=rb-4.1.0&auto=format&fit=crop&crop=entropy&w=" + w + "&h=" + h + "&q=75"; }
  function byId(id) { return window.PRODUCTS.filter(function (p) { return p.id === id; })[0]; }
  function cname(code) { return I18N.country(code); }
  function plural(base, n) { return t(base + (n === 1 ? ".one" : ".other"), { n: n }); }
  // Texto del producto en el idioma actual (si no hay traducción, el original en español)
  function loc(p, field) { var k = "p." + p.id + "." + field; var v = t(k); return v === k ? p[field] : v; }
  function taxText(a, seller, dest) {
    return {
      title: t(a.titleKey, { amount: money(a.vatIncluded), rate: I18N.number(a.rate) }),
      note: t(a.noteKey, { country: cname(seller.country), price: money(a.unit) }),
      extra: a.extraKey ? t(a.extraKey, { country: cname(dest) }) : ""
    };
  }

  /* ---------- Confirmación de edad ---------- */
  var gate = $("#agegate");
  if (store.get("intimae_age_ok") !== "1") {
    gate.showModal();
    gate.addEventListener("cancel", function (e) { e.preventDefault(); });
  }
  $("#ag-yes").addEventListener("click", function () { store.set("intimae_age_ok", "1"); gate.close(); });

  /* ---------- País de entrega e idioma ---------- */
  var destSels = [$("#dest"), $("#dest-menu")];
  var dest = store.get("intimae_dest");
  if (!TAX.get(dest)) {
    var region = ((navigator.language || "es-ES").split("-")[1] || "").toUpperCase();
    dest = TAX.get(region) ? region : "ES";
  }

  function fillDest() {
    var list = TAX.countries.slice().sort(function (a, b) { return cname(a.code).localeCompare(cname(b.code), I18N.current()); });
    destSels.forEach(function (sel) {
      sel.textContent = "";
      [["dest.eu", true], ["dest.non", false]].forEach(function (g) {
        var og = document.createElement("optgroup"); og.label = t(g[0]);
        list.filter(function (c) { return c.eu === g[1]; }).forEach(function (c) {
          var o = el("option", null, cname(c.code) + (c.open ? "" : " (" + t("dest.soon") + ")"));
          o.value = c.code; og.appendChild(o);
        });
        sel.appendChild(og);
      });
      sel.value = dest;
    });
  }
  destSels.forEach(function (sel) {
    sel.addEventListener("change", function () {
      dest = sel.value;
      store.set("intimae_dest", dest);
      // El idioma sigue al país de entrega, salvo que la persona ya haya elegido uno
      I18N.suggestForCountry(dest).then(renderAll);
      renderAll();
    });
  });
  ["#lang", "#lang-gate", "#lang-menu"].forEach(function (s) { I18N.mountSelect($(s)); });

  /* ---------- Catálogo ---------- */
  var grid = $("#grid"), empty = $("#empty"), countEl = $("#count");
  var f = { type: $("#f-type"), size: $("#f-size"), days: $("#f-days"), sort: $("#f-sort") };

  function card(p) {
    var s = SELLERS[p.seller];
    var sh = TAX.shippable(s, dest);
    var a = sh.ok ? TAX.assess(p, s, dest) : null;
    var tt = a ? taxText(a, s, dest) : null;

    var c = el("article", "pcard" + (sh.ok ? "" : " is-off"));
    var media = el("div", "pcard__media");
    var img = new Image();
    img.src = photo(p, 640, 800); img.width = 640; img.height = 800;
    img.alt = loc(p, "title"); img.loading = "lazy"; img.decoding = "async";
    media.appendChild(img);
    media.appendChild(el("span", "tag num", plural("tag", p.days)));
    var cr = el("a", "credit", t("photo") + " " + p.by);
    cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM;
    cr.target = "_blank"; cr.rel = "noopener noreferrer";
    media.appendChild(cr);
    if (!sh.ok) media.appendChild(el("span", "off-label", t("card.off", { country: cname(dest) })));
    media.addEventListener("click", function (e) { if (e.target.closest("a")) return; openPdp(p); });

    var body = el("div", "pcard__body");
    var top = el("div", "pcard__top");
    top.appendChild(el("span", "num", t("ref.no", { ref: p.ref })));
    top.appendChild(el("span", null, s.country));
    body.appendChild(top);
    var h = el("h3", "pcard__title");
    var hb = el("button", null, loc(p, "title")); hb.type = "button";
    hb.addEventListener("click", function () { openPdp(p); });
    h.appendChild(hb); body.appendChild(h);
    body.appendChild(el("p", "pcard__meta", t("type." + p.type) + " · " + t("spec.size") + " " + p.size + " · " + s.alias + " · " + t(s.type === "particular" ? "seller.particular" : "seller.pro")));

    var pr = el("div", "pcard__price");
    pr.appendChild(el("span", "price num", money(a ? a.unit : p.price)));
    pr.appendChild(el("span", "taxnote", a ? tt.title : t("card.only", { country: cname(s.country) })));
    body.appendChild(pr);

    var act = el("div", "pcard__actions");
    var add = el("button", "btn btn--sm", t("pdp.addShort")); add.type = "button"; add.disabled = !sh.ok;
    add.addEventListener("click", function () { addToCart(p.id, true); });
    var more = el("button", "link", t("pdp.more")); more.type = "button";
    more.addEventListener("click", function () { openPdp(p); });
    act.appendChild(add); act.appendChild(more); body.appendChild(act);

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
    countEl.textContent = plural("count", list.length);
  }
  Object.keys(f).forEach(function (k) { f[k].addEventListener("change", renderGrid); });

  /* ---------- Ficha de producto ---------- */
  var pdp = $("#pdp"), pdpCurrent = null;
  function fillPdp(p) {
    var s = SELLERS[p.seller];
    var sh = TAX.shippable(s, dest);
    var a = sh.ok ? TAX.assess(p, s, dest) : null;

    var img = $("#pdp-img"); img.src = photo(p, 900, 1125); img.alt = loc(p, "title");
    var cr = $("#pdp-credit"); cr.textContent = t("photo") + " " + p.by;
    cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM;

    $("#pdp-ref").textContent = t("type." + p.type) + " · " + t("ref.no", { ref: p.ref });
    $("#pdp-title").textContent = loc(p, "title");

    var line = $("#pdp-seller"); line.textContent = "";
    var v = el("span", "badge badge--ok"); var ic = icon("i-check"); ic.style.cssText = "width:12px;height:12px"; v.appendChild(ic); v.appendChild(document.createTextNode(t("verified")));
    line.appendChild(v);
    line.appendChild(el("span", null, s.alias + " · " + cname(s.country)));
    line.appendChild(el("span", "badge", t(s.type === "particular" ? "seller.particular" : "seller.pro")));

    $("#pdp-price").textContent = money(a ? a.unit : p.price);

    var box = $("#pdp-tax"); box.textContent = "";
    if (a) {
      var tt = taxText(a, s, dest);
      box.appendChild(el("strong", null, tt.title));
      box.appendChild(el("p", null, tt.note));
      if (tt.extra) box.appendChild(el("p", "warn", tt.extra));
      box.appendChild(el("p", null, t("pdp.ship", { country: cname(dest), price: money(TAX.shippingFor(a.zone)) })));
    } else {
      box.appendChild(el("strong", null, t("pdp.off", { country: cname(dest) })));
      box.appendChild(el("p", "warn", t(sh.reasonKey, { country: cname(s.country) })));
    }

    var sp = $("#pdp-specs"); sp.textContent = "";
    [[t("spec.size"), p.size], [t("spec.use"), plural("days", p.days)], [t("spec.state"), t("spec.state.v")],
     [t("spec.material"), loc(p, "material")], [t("spec.colour"), loc(p, "colour")],
     [t("spec.from"), cname(s.country)], [t("spec.since"), String(s.since)]
    ].forEach(function (r) { sp.appendChild(el("dt", null, r[0])); sp.appendChild(el("dd", null, r[1])); });

    $("#pdp-add").disabled = !sh.ok;
    $("#pdp-report").href = "mailto:" + CONFIG.orderEmail + "?subject=" + encodeURIComponent("Denuncia del anuncio N.º " + p.ref) +
      "&body=" + encodeURIComponent("Anuncio: " + p.title + " (N.º " + p.ref + ")\nMotivo:\nExplicación:\nMi nombre y correo:\nDeclaro que esta denuncia se hace de buena fe y que es exacta y completa.");
  }
  function openPdp(p) { pdpCurrent = p; fillPdp(p); pdp.showModal(); }
  $("#pdp-add").addEventListener("click", function () { if (pdpCurrent) addToCart(pdpCurrent.id, true); });

  document.querySelectorAll("dialog").forEach(function (d) {
    d.addEventListener("click", function (e) { if (e.target === d && d.id !== "agegate") d.close(); });
    d.querySelectorAll("[data-close]").forEach(function (b) { b.addEventListener("click", function () { d.close(); }); });
  });

  /* ---------- Pedido ---------- */
  var cart = [];
  try { cart = JSON.parse(store.get("intimae_cart") || "[]").filter(function (id) { return !!byId(id); }); } catch (e) { cart = []; }
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
    var r = { lines: [], sub: 0, vat: 0, ship: 0, off: 0, sellers: 0 };
    var zones = {};
    cart.forEach(function (id) {
      var p = byId(id), s = SELLERS[p.seller], sh = TAX.shippable(s, dest);
      if (!sh.ok) { r.off++; r.lines.push({ p: p, s: s, ok: false }); return; }
      var a = TAX.assess(p, s, dest);
      r.sub += a.unit; r.vat += a.vatIncluded; zones[p.seller] = a.zone;
      r.lines.push({ p: p, s: s, ok: true, a: a });
    });
    Object.keys(zones).forEach(function (k) { r.ship += TAX.shippingFor(zones[k]); r.sellers++; });
    return r;
  }

  function renderCart() {
    var r = calc();
    $("#cart-count").textContent = cart.length;
    var box = $("#lines"); box.textContent = "";
    $("#o-country").value = cname(dest);

    if (!cart.length) {
      box.appendChild(el("p", "cart__empty", t("cart.empty")));
      $("#cart-foot").hidden = true;
      return;
    }
    $("#cart-foot").hidden = false;

    r.lines.forEach(function (l) {
      var row = el("div", "line");
      var im = new Image(); im.src = photo(l.p, 160, 200); im.alt = ""; im.width = 72; im.height = 90;
      row.appendChild(im);
      var info = el("div");
      info.appendChild(el("h3", null, loc(l.p, "title")));
      info.appendChild(el("small", null, l.s.alias + " · " + cname(l.s.country)));
      if (!l.ok) { var w = el("small", null, t("cart.off", { country: cname(dest) })); w.style.color = "var(--danger)"; info.appendChild(w); }
      var rm = el("button", "rm", t("cart.remove")); rm.type = "button";
      rm.addEventListener("click", function () { cart = cart.filter(function (x) { return x !== l.p.id; }); saveCart(); });
      info.appendChild(rm); row.appendChild(info);
      row.appendChild(el("span", "price num", l.ok ? money(l.a.unit) : "—"));
      box.appendChild(row);
    });

    var sum = $("#sum"); sum.textContent = "";
    function srow(a, b, cls) { var d = el("div", cls || null); d.appendChild(el("span", null, a)); d.appendChild(el("span", "num", b)); sum.appendChild(d); }
    srow(t("sum.subtotal"), money(r.sub));
    srow(r.sellers > 1 ? t("sum.ship.n", { n: r.sellers }) : t("sum.ship"), money(r.ship));
    if (r.vat > 0) srow(t("sum.vat"), money(r.vat), "muted");
    srow(t("sum.total"), money(r.sub + r.ship), "tot");

    var note = $("#cart-note"), msgs = [t("cart.note.demo")];
    if (!TAX.get(dest).open) msgs.push(t("cart.note.soon", { country: cname(dest) }));
    if (r.off) msgs.push(t("cart.note.remove"));
    note.textContent = msgs.join(" "); note.hidden = false;
  }

  var orderMsg = $("#order-msg");
  function setMsg(text, err) { orderMsg.textContent = text; orderMsg.className = "msg" + (err ? " err" : ""); }
  function mailto(to, subject, body) {
    window.location.href = "mailto:" + to + "?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body);
  }

  $("#order-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, r = calc();
    if (!cart.length) return setMsg(t("msg.empty"), true);
    if (!TAX.get(dest).open) return setMsg(t("msg.soon", { country: cname(dest) }), true);
    if (r.off) return setMsg(t("msg.off"), true);
    if (!form.checkValidity()) return setMsg(t("msg.invalid"), true);
    var d = new FormData(form);
    // El correo del pedido va siempre en español: es el idioma de trabajo del equipo.
    var fmt = function (n) { return n.toFixed(2).replace(".", ",") + " €"; };
    var lines = r.lines.map(function (l) {
      return "- N.º " + l.p.ref + " " + l.p.title + " · " + l.s.alias + " (" + l.s.country + ", " + l.s.type + ") · " + fmt(l.a.unit);
    });
    var body = "Pedido (idioma del comprador: " + I18N.current() + ")\n\n" + lines.join("\n") +
      "\n\nSubtotal: " + fmt(r.sub) + "\nEnvío estimado: " + fmt(r.ship) + "\nTotal: " + fmt(r.sub + r.ship) +
      "\n\nNombre: " + d.get("name") + "\nCorreo: " + d.get("email") + "\nEntrega: " + d.get("addr") + "\nPaís: " + dest +
      "\nPago: " + d.get("pay") + "\nPetición: " + (d.get("note") || "-") +
      "\n\nMayor de 18 años y condiciones aceptadas: sí\nConsentimiento expreso (art. 9.2.a RGPD): sí";
    mailto(CONFIG.orderEmail, "Nuevo pedido Intimae", body);
    setMsg(t("msg.sent"));
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

  /* ---------- Arranque ---------- */
  function renderAll() {
    fillDest(); renderGrid(); renderCart();
    if (pdp.open && pdpCurrent) fillPdp(pdpCurrent);
  }
  I18N.onChange(renderAll);
  I18N.start();
})();
