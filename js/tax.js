/*
 * Motor fiscal orientativo de Intimae. No sustituye el consejo de un asesor fiscal.
 * Reglas y fuentes en iva.html y vendedores/impuestos.html.
 *
 * Devuelve claves de traducción (no frases) para que la interfaz las muestre en el idioma del usuario.
 *
 * Modelo operativo:
 *  - Vendedores de la UE envían a la UE. Reino Unido, Suiza y Noruega: próximamente
 *    (el mercado debe cobrar el IVA local en el pago).
 *  - Vendedores de fuera de la UE solo venden en su propio país: importar a la UE exige IOSS
 *    y el derecho de 3 € por artículo.
 *  - Canarias (código IC) está fuera del territorio de IVA de la UE: allí se aplica el IGIC. Solo se admiten
 *    envíos dentro de Canarias; entre Canarias y el resto se requieren trámites aduaneros y fiscales (DUA)
 *    que la plataforma no gestiona. Tipo y régimen: ESTIMACIÓN PENDIENTE DE VALIDAR por un asesor fiscal canario.
 */
(function () {
  "use strict";

  // Tipos generales de IVA (%). Verificar en la base de datos de la Comisión Europea antes de operar.
  var C = [
    ["DE", 19], ["AT", 20], ["BE", 21], ["BG", 20], ["CY", 19], ["HR", 25], ["DK", 25], ["SK", 23],
    ["SI", 22], ["ES", 21], ["EE", 24], ["FI", 25.5], ["FR", 20], ["GR", 24], ["HU", 27], ["IE", 23],
    ["IT", 22], ["LV", 21], ["LT", 21], ["LU", 17], ["MT", 18], ["NL", 21], ["PL", 23], ["PT", 23],
    ["CZ", 21], ["RO", 21], ["SE", 25]
  ].map(function (c) { return { code: c[0], vat: c[1], eu: true, open: true }; });

  var NON_EU = [
    { code: "NO", vat: 25, eu: false, open: false },
    { code: "GB", vat: 20, eu: false, open: false },
    { code: "CH", vat: 8.1, eu: false, open: false }
  ];

  // Canarias: IGIC, tipo general 7 % (estimación pendiente de validar).
  var CANARIAS = [{ code: "IC", vat: 7, eu: true, open: true, igic: true }];

  var ALL = C.concat(CANARIAS, NON_EU);
  var BY = {};
  ALL.forEach(function (c) { BY[c.code] = c; });

  // Tarifas de envío de demostración (€ por vendedor). Se sustituirán por las del transportista.
  var SHIPPING = { domestic: 4.9, eu: 7.9, export: 14.9 };

  function zone(sellerCode, destCode) {
    var s = BY[sellerCode], d = BY[destCode];
    if (!s || !d) return "unknown";
    if ((s.code === "IC") !== (d.code === "IC")) return "customs"; // Canarias <-> resto: DUA
    if (s.code === d.code) return "domestic";
    if (s.eu && d.eu) return "eu";
    if (s.eu && !d.eu) return "export";
    return "blocked"; // vendedor de fuera de la UE hacia otro país
  }

  function shippable(seller, destCode) {
    var z = zone(seller.country, destCode);
    if (z === "customs") return { ok: false, zone: z, reasonKey: "tax.off.customs" };
    if (z === "blocked") return { ok: false, zone: z, reasonKey: "tax.off.reason", reasonVars: { country: seller.country } };
    return { ok: true, zone: z };
  }

  function round2(n) { return Math.round(n * 100) / 100; }

  /*
   * Cómo se trata fiscalmente una línea para un destino.
   *  unit: precio que paga el comprador (€).
   *  vatIncluded: IVA contenido en ese precio (solo régimen general, se desglosa).
   *  kind: particular | used | general.
   */
  function assess(product, seller, destCode) {
    var z = zone(seller.country, destCode);
    var r = BY[seller.country] ? BY[seller.country].vat : 0;
    var out = { zone: z, unit: product.price, vatIncluded: 0, rate: r, extraKey: null, extraVars: null };

    if (seller.type === "particular") {
      out.kind = "particular";
      out.titleKey = "tax.title.final"; out.noteKey = "tax.note.particular";
    } else if (seller.vat === "margin") {
      out.kind = "used";
      out.titleKey = seller.country === "IC" ? "tax.title.usedigic" : "tax.title.used";
      out.noteKey = seller.country === "IC" ? "tax.note.usedigic" : "tax.note.used";
    } else {
      out.kind = "general";
      if (z === "export") {
        out.unit = round2(product.price / (1 + r / 100));
        out.titleKey = "tax.title.export"; out.noteKey = "tax.note.export";
      } else {
        out.vatIncluded = round2(product.price - product.price / (1 + r / 100));
        out.titleKey = seller.country === "IC" ? "tax.title.igic" : "tax.title.vat";
        out.noteKey = seller.country === "IC" ? "tax.note.igic" : "tax.note.vat";
      }
    }

    if (z === "export") { out.extraKey = "tax.extra.soon"; out.extraVars = { dest: destCode }; }
    return out;
  }

  function shippingFor(zoneName) { return SHIPPING[zoneName] || 0; }

  window.TAX = {
    countries: ALL,
    get: function (code) { return BY[code]; },
    zone: zone,
    shippable: shippable,
    assess: assess,
    shippingFor: shippingFor
  };
})();
