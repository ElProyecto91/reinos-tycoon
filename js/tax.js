/*
 * Motor fiscal orientativo de Intimae.
 * No sustituye el consejo de un asesor fiscal. Reglas y fuentes en iva.html.
 *
 * Modelo operativo que implementa (ver docs/ESTUDIO-LEGAL-Y-MERCADO.md):
 *  - Vendedores de la UE envían a la UE. Reino Unido, Suiza y Noruega: próximamente (el mercado debe cobrar el IVA local).
 *  - Vendedores de fuera de la UE solo venden en su propio país. Importar a la UE
 *    desde terceros países obliga a IOSS, derecho de 3 € por artículo y mucha carga.
 */
(function () {
  "use strict";

  // Tipos generales de IVA (%). Verificar en la base de datos de la Comisión Europea antes de operar.
  var C = [
    ["DE", "Alemania", 19], ["AT", "Austria", 20], ["BE", "Bélgica", 21], ["BG", "Bulgaria", 20],
    ["CY", "Chipre", 19], ["HR", "Croacia", 25], ["DK", "Dinamarca", 25], ["SK", "Eslovaquia", 23],
    ["SI", "Eslovenia", 22], ["ES", "España", 21], ["EE", "Estonia", 24], ["FI", "Finlandia", 25.5],
    ["FR", "Francia", 20], ["GR", "Grecia", 24], ["HU", "Hungría", 27], ["IE", "Irlanda", 23],
    ["IT", "Italia", 22], ["LV", "Letonia", 21], ["LT", "Lituania", 21], ["LU", "Luxemburgo", 17],
    ["MT", "Malta", 18], ["NL", "Países Bajos", 21], ["PL", "Polonia", 23], ["PT", "Portugal", 23],
    ["CZ", "República Checa", 21], ["RO", "Rumanía", 21], ["SE", "Suecia", 25]
  ].map(function (c) { return { code: c[0], name: c[1], vat: c[2], eu: true, open: true }; });

  var NON_EU = [
    { code: "NO", name: "Noruega", vat: 25, eu: false, open: false },
    { code: "GB", name: "Reino Unido", vat: 20, eu: false, open: false },
    { code: "CH", name: "Suiza", vat: 8.1, eu: false, open: false }
  ];

  var ALL = C.concat(NON_EU);
  var BY = {};
  ALL.forEach(function (c) { BY[c.code] = c; });

  // Tarifas de envío de demostración (€ por vendedor). Se sustituirán por las del transportista.
  var SHIPPING = { domestic: 4.9, eu: 7.9, export: 14.9 };

  function zone(sellerCode, destCode) {
    var s = BY[sellerCode], d = BY[destCode];
    if (!s || !d) return "unknown";
    if (s.code === d.code) return "domestic";
    if (s.eu && d.eu) return "eu";
    if (s.eu && !d.eu) return "export";
    return "blocked"; // vendedor de fuera de la UE hacia otro país
  }

  function shippable(product, seller, destCode) {
    var z = zone(seller.country, destCode);
    if (z === "blocked") {
      return {
        ok: false,
        reason: "Este vendedor está en " + BY[seller.country].name + " y por ahora solo envía dentro de su país. " +
                "Importar a otro país implica impuestos y aranceles que la plataforma aún no gestiona."
      };
    }
    return { ok: true, zone: z };
  }

  function money(n) { return n.toFixed(2).replace(".", ",") + " €"; }

  /*
   * Devuelve cómo se trata fiscalmente una línea para un destino.
   * unit: precio unitario que paga el comprador (€).
   * vatIncluded: IVA contenido en ese precio, solo si es régimen general y se desglosa.
   */
  function assess(product, seller, destCode) {
    var z = zone(seller.country, destCode);
    var out = { zone: z, unit: product.price, vatIncluded: 0, badge: "", title: "", note: "", extra: "" };
    var r = BY[seller.country] ? BY[seller.country].vat : 0;

    if (seller.type === "particular") {
      out.badge = "Particular";
      out.title = "Precio final, sin IVA";
      out.note = "El vendedor es un particular: no cobra IVA. Al no ser una venta profesional, no se aplican las normas de consumo de la UE (desistimiento y garantía legal).";
    } else if (seller.vat === "margin") {
      out.badge = "Profesional · bienes usados";
      out.title = "IVA incluido (régimen de bienes usados)";
      out.note = "Vendedor profesional acogido al régimen especial de bienes usados. El IVA va incluido en el precio y, por ley, no se desglosa. Se aplican las normas de consumo.";
    } else {
      out.badge = "Profesional";
      if (z === "export") {
        out.unit = round2(product.price / (1 + r / 100));
        out.title = "Sin IVA de origen (exportación)";
        out.note = "Las exportaciones fuera de la UE están exentas de IVA en origen, así que el precio baja a " + money(out.unit) + ". Se aplican las normas de consumo.";
      } else {
        out.vatIncluded = round2(product.price - product.price / (1 + r / 100));
        out.title = "IVA incluido: " + money(out.vatIncluded) + " (" + fmtRate(r) + " %)";
        out.note = "Vendedor profesional en régimen general. Precio con IVA de " + BY[seller.country].name + ". Si el vendedor supera 10.000 € de ventas a consumidores de otros países de la UE, el IVA será el del país de destino. Se aplican las normas de consumo.";
      }
    }

    if (z === "export") {
      out.extra = "Los envíos a " + BY[destCode].name + " estarán disponibles próximamente: exigen que el mercado cobre el IVA local en el pago y aún no estamos registrados para ello.";
    }
    return out;
  }

  function round2(n) { return Math.round(n * 100) / 100; }
  function fmtRate(r) { return String(r).replace(".", ","); }

  function shippingFor(zoneName) { return SHIPPING[zoneName] || 0; }

  window.TAX = {
    countries: ALL,
    get: function (code) { return BY[code]; },
    zone: zone,
    shippable: shippable,
    assess: assess,
    shippingFor: shippingFor,
    money: money,
    fmtRate: fmtRate
  };
})();
