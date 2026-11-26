/* Intimae · tienda (zona de compradores) */
(function () {
  "use strict";

  // Configuración: se completará cuando haya titularidad y correos reales.
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
  function photo(p, w, h) { if (p.img.indexOf("data:") === 0) return p.img; return p.img + "?ixlib=rb-4.1.0&auto=format&fit=crop&crop=entropy&w=" + w + "&h=" + h + "&q=75"; }
  function byId(id) { return window.PRODUCTS.filter(function (p) { return p.id === id; })[0]; }
  function user() { return INT.buyer.current(); }
  function toAccount(next) { window.location.href = "cuenta/?next=" + next; }
  function toggleFav(p) {
    var u = user(); if (!u) return toAccount("store");
    INT.fav.toggle(u.id, p.id);
  }
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
  var f = { q: $("#f-q"), pmin: $("#f-pmin"), pmax: $("#f-pmax"), color: $("#f-color"), country: $("#f-country"), rating: $("#f-rating"), type: $("#f-type"), size: $("#f-size"), days: $("#f-days"), sort: $("#f-sort") };

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
    if (s.seed) media.appendChild(el("span", "tag tag--sample", t("sample.tag")));
    if (p.by) {
      var cr = el("a", "credit", t("photo") + " " + p.by);
      cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM;
      cr.target = "_blank"; cr.rel = "noopener noreferrer";
      media.appendChild(cr);
    }
    var u0 = user(), on = !!(u0 && INT.fav.has(u0.id, p.id));
    var fb = el("button", "favbtn" + (on ? " on" : "")); fb.type = "button"; fb.appendChild(icon("i-heart"));
    fb.setAttribute("aria-label", t(on ? "fav.remove" : "fav.add")); fb.setAttribute("aria-pressed", String(on));
    fb.addEventListener("click", function (e) { e.stopPropagation(); toggleFav(p); });
    media.appendChild(fb);
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

  function opt(v, label) { var o = el("option", null, label); o.value = v; return o; }
  function visible() { var u = user(); return window.PRODUCTS.filter(function (p) { return !(u && INT.block.has(u.id, p.seller)); }); }
  function favCount(p) { return INT.data().favs.filter(function (x) { return x.listing === p.id; }).length; }

  // Colores, países y sugerencias de búsqueda según el catálogo que hay en cada momento
  function fillFilters() {
    var all = visible(), keepC = f.color.value, keepK = f.country.value, colors = {}, countries = {};
    all.forEach(function (p) { if (p.colour && p.colour !== "—") colors[p.colour] = loc(p, "colour"); countries[SELLERS[p.seller].country] = 1; });
    f.color.textContent = ""; f.color.appendChild(opt("", t("opt.all")));
    Object.keys(colors).sort().forEach(function (c) { f.color.appendChild(opt(c, colors[c])); });
    f.color.value = colors[keepC] != null ? keepC : "";
    f.country.textContent = ""; f.country.appendChild(opt("", t("opt.all")));
    Object.keys(countries).sort(function (a, b) { return cname(a).localeCompare(cname(b), I18N.current()); }).forEach(function (c) { f.country.appendChild(opt(c, cname(c))); });
    f.country.value = countries[keepK] ? keepK : "";
    var dl = $("#f-q-list"), seen = {}; dl.textContent = "";
    all.forEach(function (p) { [loc(p, "title"), loc(p, "colour"), loc(p, "material")].forEach(function (w) { if (w && w !== "—" && !seen[w]) { seen[w] = 1; var o = document.createElement("option"); o.value = w; dl.appendChild(o); } }); });
  }
  function renderCats() {
    var box = $("#cats"); box.textContent = "";
    [["", t("opt.all")]].concat(["braga", "tanga", "sujetador", "camison", "conjunto"].map(function (k) { return [k, t("type." + k)]; })).forEach(function (c) {
      var on = f.type.value === c[0], b = el("button", "chip" + (on ? " on" : ""), c[1]); b.type = "button"; b.setAttribute("aria-pressed", String(on));
      b.addEventListener("click", function () { f.type.value = c[0]; renderGrid(); renderCats(); }); box.appendChild(b);
    });
  }
  function renderSellers() {
    var sec = $("#tiendas"), box = $("#shops"), u = user(); box.textContent = "";
    var data = Object.keys(SELLERS).filter(function (id) { return !(u && INT.block.has(u.id, id)); }).map(function (id) { return { id: id, s: SELLERS[id], n: window.PRODUCTS.filter(function (p) { return p.seller === id; }).length }; })
      .filter(function (x) { return x.n > 0; }).sort(function (a, b) { return b.n - a.n; }).slice(0, 6);
    sec.hidden = !data.length;
    data.forEach(function (x) {
      var a = el("a", "shop"); a.href = "tienda/?s=" + encodeURIComponent(x.id);
      var body = el("span", "shop__body"), rt = INT.seller.rating(x.id);
      body.appendChild(el("strong", null, x.s.alias));
      body.appendChild(el("small", null, cname(x.s.country) + " · " + t(x.s.type === "particular" ? "seller.particular" : "seller.pro")));
      body.appendChild(el("small", null, (rt.n ? t("rate." + (rt.n === 1 ? "one" : "other"), { avg: I18N.number(rt.avg), n: rt.n }) : t("rate.none")) + " · " + plural("count", x.n)));
      a.appendChild(el("span", "shop__av", x.s.alias.charAt(0).toUpperCase())); a.appendChild(body);
      if (x.s.seed) a.appendChild(el("span", "badge", t("sample.tag")));
      a.appendChild(el("span", "shop__go", t("shop.view"))); box.appendChild(a);
    });
  }
  function renderBars() {
    var n = window.PRODUCTS.length, any = window.PRODUCTS.some(function (p) { return p.seed; });
    $(".demobar").hidden = n > 0 && !any;
    var u = user(), c = u ? INT.msg.forBuyer(u.id).reduce(function (a, th) { return a + INT.msg.unread(th, "buyer"); }, 0) : 0, mb = $("#mn-msgs");
    mb.hidden = !c; mb.textContent = c;
  }

  function renderGrid() {
    var all = visible(), minDays = +f.days.value, q = f.q.value.trim().toLowerCase(), pmin = +f.pmin.value || 0, pmax = +f.pmax.value || 0, rmin = +f.rating.value || 0;
    var list = all.filter(function (p) {
      var hay = q ? [loc(p, "title"), loc(p, "material"), loc(p, "colour"), t("type." + p.type), p.ref].join(" ").toLowerCase() : "";
      return (!f.type.value || p.type === f.type.value) && (!f.size.value || p.size === f.size.value) && p.days >= minDays && (!q || hay.indexOf(q) !== -1) &&
        (!pmin || p.price >= pmin) && (!pmax || p.price <= pmax) && (!f.color.value || p.colour === f.color.value) &&
        (!f.country.value || SELLERS[p.seller].country === f.country.value) && (!rmin || INT.seller.rating(p.seller).avg >= rmin);
    });
    var so = f.sort.value;
    list.sort(function (a, b) {
      if (so === "asc") return a.price - b.price;
      if (so === "desc") return b.price - a.price;
      if (so === "days") return b.days - a.days;
      if (so === "rating") return INT.seller.rating(b.seller).avg - INT.seller.rating(a.seller).avg;
      if (so === "pop") return favCount(b) - favCount(a);
      return a.date < b.date ? 1 : -1;
    });
    grid.textContent = "";
    list.forEach(function (p) { grid.appendChild(card(p)); });
    var none = all.length === 0;
    empty.hidden = list.length > 0 || none; $("#founder-empty").hidden = !none; grid.hidden = none;
    countEl.textContent = none ? "" : plural("count", list.length);
  }
  Object.keys(f).forEach(function (k) { f[k].addEventListener(k === "q" || k === "pmin" || k === "pmax" ? "input" : "change", function () { renderGrid(); renderCats(); }); });
  $("#save-search").addEventListener("click", function () {
    var u = user(), m = $("#search-msg");
    if (!u) { m.className = "msg err"; m.textContent = t("search.login"); return; }
    try { INT.search.save(u.id, { q: f.q.value, type: f.type.value, size: f.size.value, color: f.color.value, pmin: f.pmin.value, pmax: f.pmax.value, country: f.country.value }); m.className = "msg"; m.textContent = t("search.saved"); }
    catch (e) { m.className = "msg err"; m.textContent = e.code === "empty" ? t("search.empty") : e.message; }
  });

  /* ---------- Ficha de producto ---------- */
  var pdp = $("#pdp"), pdpCurrent = null;
  function fillPdp(p) {
    var s = SELLERS[p.seller];
    var sh = TAX.shippable(s, dest);
    var a = sh.ok ? TAX.assess(p, s, dest) : null;

    var img = $("#pdp-img"); img.src = photo(p, 900, 1125); img.alt = loc(p, "title");
    var cr = $("#pdp-credit"); cr.hidden = !p.by;
    if (p.by) { cr.textContent = t("photo") + " " + p.by; cr.href = "https://unsplash.com/@" + encodeURIComponent(p.handle) + UTM; }

    $("#pdp-ref").textContent = t("type." + p.type) + " · " + t("ref.no", { ref: p.ref });
    $("#pdp-title").textContent = loc(p, "title");

    var line = $("#pdp-seller"); line.textContent = "";
    var v = el("span", "badge badge--ok"); var ic = icon("i-check"); ic.style.cssText = "width:12px;height:12px"; v.appendChild(ic); v.appendChild(document.createTextNode(t("verified")));
    line.appendChild(v);
    line.appendChild(el("span", null, s.alias + " · " + cname(s.country)));
    line.appendChild(el("span", "badge", t(s.type === "particular" ? "seller.particular" : "seller.pro")));
    var rt = INT.seller.rating(p.seller);
    line.appendChild(el("span", "badge", rt.n ? t("rate." + (rt.n === 1 ? "one" : "other"), { avg: I18N.number(rt.avg), n: rt.n }) : t("rate.none")));
    if (s.seed) line.appendChild(el("span", "badge", t("sample.tag")));
    $("#pdp-shop").href = "tienda/?s=" + encodeURIComponent(p.seller);
    var u1 = user(), fon = !!(u1 && INT.fav.has(u1.id, p.id));
    $("#pdp-fav-t").textContent = t(fon ? "fav.saved" : "fav.save"); $("#pdp-fav").setAttribute("aria-pressed", String(fon));

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
     [t("spec.from"), cname(s.country)]].concat(sh.ok ? [[t("spec.eta"), t("eta." + sh.zone)]] : [], [[t("spec.since"), String(s.since)]])
    .forEach(function (r) { sp.appendChild(el("dt", null, r[0])); sp.appendChild(el("dd", null, r[1])); });

    $("#pdp-add").disabled = !sh.ok;
  }
  function openPdp(p) { pdpCurrent = p; INT.listing.view(p.id); fillPdp(p); $("#pdp-askbox").hidden = true; $("#ask-msg").textContent = ""; pdp.showModal(); }
  $("#pdp-fav").addEventListener("click", function () { if (pdpCurrent) { toggleFav(pdpCurrent); if (user()) fillPdp(pdpCurrent); } });

  // Preguntar al vendedor
  $("#pdp-ask").addEventListener("click", function () {
    var box = $("#pdp-askbox"), u = user(), hint = $("#pdp-ask-login");
    box.hidden = !box.hidden; if (box.hidden) return;
    hint.hidden = !!u; $("#ask-form").hidden = !u;
    if (!u) { hint.textContent = ""; var a = el("a", "link", t("cart.cta")); a.href = "cuenta/?next=store"; hint.appendChild(document.createTextNode(t("pdp.ask.login") + " ")); hint.appendChild(a); }
  });
  $("#ask-form").addEventListener("submit", function (e) {
    e.preventDefault(); var u = user(), m = $("#ask-msg"); if (!u || !pdpCurrent) return;
    var text = e.target.elements.text.value;
    if (INT.msg.blocked(text)) { m.className = "msg err"; m.textContent = t("pdp.ask.blocked"); return; }
    try { INT.msg.start(u.id, pdpCurrent.id, text); e.target.reset(); m.className = "msg"; m.textContent = t("pdp.ask.sent"); }
    catch (err) { m.className = "msg err"; m.textContent = err.message; }
  });

  // Denuncia de contenido
  var repDlg = $("#report");
  $("#pdp-report").addEventListener("click", function () {
    if (!pdpCurrent) return; $("#rep-target").textContent = t("ref.no", { ref: pdpCurrent.ref }) + " · " + loc(pdpCurrent, "title");
    $("#rep-msg").textContent = ""; $("#report-form").reset(); repDlg.showModal();
  });
  $("#report-form").addEventListener("submit", function (e) {
    e.preventDefault(); var d = new FormData(e.target), m = $("#rep-msg");
    if (!d.get("good")) { m.className = "msg err"; m.textContent = t("rep.invalid"); return; }
    try { var r = INT.report.create({ listing: pdpCurrent.id, reason: d.get("reason"), text: d.get("text"), email: d.get("email"), good: true }); m.className = "msg"; m.textContent = t("rep.sent", { no: r.no }); e.target.reset(); }
    catch (err) { m.className = "msg err"; m.textContent = err.message; }
  });
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

  var lastOrder = "";
  function addToCart(id, open) {
    lastOrder = "";
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
      var p = byId(id); if (!p) return;
      var s = SELLERS[p.seller], sh = TAX.shippable(s, dest);
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
      if (lastOrder) {
        box.appendChild(el("p", "cart__empty", t("msg.paid", { no: lastOrder })));
        var lk = el("a", "link", t("o.link")); lk.href = "cuenta/#pedidos"; lk.style.cssText = "display:inline-block;margin:0 24px 24px"; box.appendChild(lk);
      } else box.appendChild(el("p", "cart__empty", t("cart.empty")));
      $("#cart-foot").hidden = true;
      return;
    }
    $("#cart-foot").hidden = false;
    // Para pagar hace falta una cuenta de comprador con la edad verificada
    var u = user(), gate = $("#cart-gate"), form = $("#order-form");
    if (!u || !u.ageVerified) {
      gate.hidden = false; form.hidden = true;
      $("#cart-gate-text").textContent = t(u ? "cart.age" : "cart.login");
      var cta = $("#cart-gate-cta"); cta.textContent = t(u ? "cart.cta.age" : "cart.cta"); cta.href = "cuenta/?next=cart" + (u ? "#datos" : "");
    } else {
      gate.hidden = true; form.hidden = false;
      form.elements.email.value = u.email;
      if (!form.elements.name.value) form.elements.name.value = u.name;
      if (!form.elements.addr.value) form.elements.addr.value = u.addr;
    }

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
    var form = e.target, r = calc(), u = user();
    if (!u) return setMsg(t("cart.login"), true);
    if (!u.ageVerified) return setMsg(t("cart.age"), true);
    if (!cart.length) return setMsg(t("msg.empty"), true);
    if (!TAX.get(dest).open) return setMsg(t("msg.soon", { country: cname(dest) }), true);
    if (r.off) return setMsg(t("msg.off"), true);
    if (!form.checkValidity()) return setMsg(t("msg.invalid"), true);
    var d = new FormData(form), note = String(d.get("note") || "").trim();
    if (note && INT.msg.blocked(note)) return setMsg(t("pdp.ask.blocked"), true);
    var made;
    try { made = INT.orders.create(u.id, cart.slice(), dest, { name: d.get("name"), line: d.get("addr") }); }
    catch (err) {
      var k = { stock: "msg.stock", age: "cart.age", addr: "msg.addr", auth: "cart.login", ship: "msg.off", dest: "msg.off" }[err.code];
      return setMsg(k ? t(k) : err.message, true);
    }
    if (note) { try { INT.msg.start(u.id, made[0].items[0].listing, "[" + made[0].no + "] " + note); } catch (x) {} }
    INT.buyer.update({ name: d.get("name"), addr: d.get("addr"), country: dest });
    lastOrder = made.map(function (o) { return o.no; }).join(", ");
    cart = []; form.reset(); saveCart(); setMsg("");
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
    cart = cart.filter(function (id) { return !!byId(id); });
    fillDest(); fillFilters(); renderCats(); renderSellers(); renderBars(); renderGrid(); renderCart();
    if (pdp.open && pdpCurrent) fillPdp(pdpCurrent);
  }
  I18N.onChange(renderAll);
  INT.onChange(renderAll);
  cartDlg.addEventListener("close", function () { lastOrder = ""; });
  I18N.start().then(function () {
    // Enlaces desde la cuenta: ?p=ID abre una ficha y ?cart=1 abre el pedido
    var qp = new URLSearchParams(window.location.search), pid = +qp.get("p");
    if (gate.open) return;
    if (pid && byId(pid)) openPdp(byId(pid));
    else if (qp.get("cart") === "1") { renderCart(); cartDlg.showModal(); }
  });
})();
