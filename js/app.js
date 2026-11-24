(function () {
  "use strict";

  // Configuración: cambia estos valores antes de publicar.
  var CONFIG = {
    orderEmail: "pedidos@example.com",
    sellerEmail: "vendedores@example.com",
    currency: "€"
  };

  var $ = function (s, el) { return (el || document).querySelector(s); };
  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };
  var money = function (n) { return n.toFixed(2).replace(".", ",") + " " + CONFIG.currency; };
  var TYPE_LABEL = { braga: "Braga", tanga: "Tanga", sujetador: "Sujetador", culotte: "Culotte" };

  /* ---------- Verificación de edad ---------- */
  var gate = $("#agegate");
  if (store.get("intimae_age_ok") !== "1") {
    gate.hidden = false;
    document.body.style.overflow = "hidden";
  }
  $("#ag-yes").addEventListener("click", function () {
    store.set("intimae_age_ok", "1");
    gate.hidden = true;
    document.body.style.overflow = "";
  });

  /* ---------- Ilustraciones SVG (sin imágenes explícitas) ---------- */
  function art(type, hue) {
    var a = "hsl(" + hue + ",65%,52%)", b = "hsl(" + hue + ",70%,28%)";
    var id = "g" + Math.random().toString(36).slice(2, 8);
    var shapes = {
      braga: '<path d="M18 40 Q100 18 182 40 L172 72 Q150 128 112 138 L100 148 L88 138 Q50 128 28 72 Z"/>',
      tanga: '<path d="M18 40 Q100 18 182 40 L162 62 Q112 82 106 148 L94 148 Q88 82 38 62 Z"/>',
      culotte: '<path d="M18 40 Q100 26 182 40 L178 112 Q146 124 112 100 L100 94 L88 100 Q54 124 22 112 Z"/>',
      sujetador: '<path d="M30 52 Q64 40 92 70 Q90 116 60 120 Q26 114 30 52 Z"/><path d="M170 52 Q136 40 108 70 Q110 116 140 120 Q174 114 170 52 Z"/><path d="M90 74 Q100 88 110 74 L108 100 Q100 108 92 100 Z"/><path d="M42 50 Q40 14 56 8 M158 50 Q160 14 144 8 M30 126 Q100 146 170 126" fill="none" stroke="url(#' + id + ')" stroke-width="5" stroke-linecap="round"/>'
    };
    return '<svg viewBox="0 0 200 160" role="img" aria-label="' + (TYPE_LABEL[type] || "Prenda") + '">' +
      '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + a + '"/><stop offset="1" stop-color="' + b + '"/></linearGradient></defs>' +
      '<g fill="url(#' + id + ')" stroke="rgba(255,255,255,.25)" stroke-width="1.5">' + (shapes[type] || shapes.braga) + '</g>' +
      '<path d="M26 46 Q100 26 174 46" fill="none" stroke="rgba(255,255,255,.35)" stroke-width="2" stroke-dasharray="3 5"/></svg>';
  }

  /* ---------- Catálogo ---------- */
  var grid = $("#grid"), empty = $("#empty");
  var f = { type: $("#f-type"), size: $("#f-size"), days: $("#f-days"), sort: $("#f-sort") };

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function card(p) {
    var c = el("article", "pcard");
    var artBox = el("div", "pcard__art");
    artBox.style.background = "linear-gradient(160deg,hsl(" + p.hue + ",45%,18%),hsl(" + p.hue + ",35%,9%))";
    artBox.innerHTML = art(p.type, p.hue);          // markup propio, sin datos de usuario
    artBox.appendChild(el("span", "tag", p.days + (p.days === 1 ? " día" : " días") + " de uso"));
    var body = el("div", "pcard__body");
    body.appendChild(el("h4", "pcard__title", p.title));
    body.appendChild(el("div", "pcard__meta", TYPE_LABEL[p.type] + " · Talla " + p.size + " · @" + p.seller));
    body.appendChild(el("p", "pcard__desc", p.desc));
    var foot = el("div", "pcard__foot");
    foot.appendChild(el("span", "price", money(p.price)));
    var b = el("button", "btn btn--primary btn--sm", "Añadir");
    b.addEventListener("click", function () { addToCart(p.id); });
    foot.appendChild(b);
    body.appendChild(foot);
    c.appendChild(artBox);
    c.appendChild(body);
    return c;
  }

  function renderGrid() {
    var minDays = +f.days.value;
    var list = window.PRODUCTS.filter(function (p) {
      return (!f.type.value || p.type === f.type.value) &&
             (!f.size.value || p.size === f.size.value) &&
             p.days >= minDays;
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
  }
  Object.keys(f).forEach(function (k) { f[k].addEventListener("change", renderGrid); });
  renderGrid();

  /* ---------- Carrito ---------- */
  var cart = [];
  try { cart = JSON.parse(store.get("intimae_cart") || "[]").filter(function (id) {
    return window.PRODUCTS.some(function (p) { return p.id === id; });
  }); } catch (e) { cart = []; }

  var drawer = $("#cart"), scrim = $("#scrim");
  function openCart() { drawer.classList.add("open"); drawer.setAttribute("aria-hidden", "false"); scrim.hidden = false; }
  function closeCart() { drawer.classList.remove("open"); drawer.setAttribute("aria-hidden", "true"); scrim.hidden = true; }
  $("#open-cart").addEventListener("click", openCart);
  $("#close-cart").addEventListener("click", closeCart);
  scrim.addEventListener("click", closeCart);
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") closeCart(); });

  function addToCart(id) {
    if (cart.indexOf(id) === -1) cart.push(id);   // cada prenda es única
    saveCart(); openCart();
  }
  function saveCart() { store.set("intimae_cart", JSON.stringify(cart)); renderCart(); }

  function renderCart() {
    var ul = $("#cart-items"); ul.textContent = "";
    var total = 0;
    cart.forEach(function (id) {
      var p = window.PRODUCTS.filter(function (x) { return x.id === id; })[0];
      if (!p) return;
      total += p.price;
      var li = el("li");
      var info = el("div");
      info.appendChild(el("span", null, p.title));
      info.appendChild(el("small", null, "@" + p.seller + " · " + money(p.price)));
      var rm = el("button", null, "Quitar");
      rm.addEventListener("click", function () { cart = cart.filter(function (x) { return x !== id; }); saveCart(); });
      li.appendChild(info); li.appendChild(rm); ul.appendChild(li);
    });
    if (!cart.length) ul.appendChild(el("li", "cart__empty", "Tu carrito está vacío."));
    $("#cart-total").textContent = money(total);
    $("#cart-count").textContent = cart.length;
  }
  renderCart();

  /* ---------- Formularios ---------- */
  function msg(node, text, err) { node.textContent = text; node.className = "form__msg" + (err ? " err" : ""); }

  function mailto(to, subject, body) {
    window.location.href = "mailto:" + to + "?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body);
  }

  $("#order-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, m = $("#order-msg");
    if (!cart.length) return msg(m, "Añade al menos una prenda.", true);
    if (!form.checkValidity()) return msg(m, "Completa los campos obligatorios y confirma que eres mayor de edad.", true);
    var d = new FormData(form), total = 0;
    var lines = cart.map(function (id) {
      var p = window.PRODUCTS.filter(function (x) { return x.id === id; })[0];
      total += p.price;
      return "- " + p.title + " (@" + p.seller + ", talla " + p.size + ") " + money(p.price);
    });
    var body = "Pedido\n\n" + lines.join("\n") + "\n\nTotal: " + money(total) +
      "\nNombre: " + d.get("name") + "\nEmail: " + d.get("email") +
      "\nEnvío: " + d.get("addr") + "\nPago: " + d.get("pay") + "\nPetición: " + (d.get("note") || "-");
    mailto(CONFIG.orderEmail, "Nuevo pedido Intimae", body);
    msg(m, "Se abrirá tu correo con el pedido. Te responderemos con los datos de pago.");
  });

  $("#seller-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var form = e.target, m = $("#seller-msg");
    var d = new FormData(form);
    if (+d.get("age") < 18) return msg(m, "Debes ser mayor de 18 años para vender.", true);
    if (!form.checkValidity()) return msg(m, "Completa todos los campos y acepta las condiciones.", true);
    mailto(CONFIG.sellerEmail, "Solicitud de vendedor: " + d.get("alias"),
      "Alias: " + d.get("alias") + "\nEmail: " + d.get("email") + "\nEdad: " + d.get("age") + "\n\n" + (d.get("about") || ""));
    msg(m, "Se abrirá tu correo con la solicitud. Te pediremos verificación de identidad.");
  });
})();
