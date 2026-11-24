// Catálogo de demostración. Vendedores y datos ficticios.
// Las fotos son de muestra, de Unsplash (https://unsplash.com): solo prendas, sin personas.
// price: precio final en € (con IVA incluido cuando el vendedor lo cobra).
window.SELLERS = {
  lunaroja:  { alias: "Lunaroja",  country: "ES", type: "profesional", vat: "margin",   since: 2025 },
  cleo:      { alias: "Cleo",      country: "GB", type: "profesional", vat: "standard", since: 2025 },
  maribel:   { alias: "Maribel_V", country: "ES", type: "particular",  vat: "none",     since: 2026 },
  sofiluz:   { alias: "Sofi.Luz",  country: "PT", type: "particular",  vat: "none",     since: 2026 },
  carlota:   { alias: "Carlota",   country: "FR", type: "profesional", vat: "margin",   since: 2025 },
  aitana:    { alias: "Aitana",    country: "DE", type: "profesional", vat: "standard", since: 2025 },
  noa:       { alias: "Noa",       country: "ES", type: "particular",  vat: "none",     since: 2026 },
  mar:       { alias: "Mar",       country: "IT", type: "particular",  vat: "none",     since: 2026 },
  fitirene:  { alias: "Fit_Irene", country: "NL", type: "profesional", vat: "margin",   since: 2026 }
};

window.PRODUCTS = [
  { id: 1, ref: "0001", type: "tanga",     title: "Tanga de encaje negro",         seller: "lunaroja", size: "S", days: 2, price: 24, material: "Encaje calado",     colour: "Negro",   desc: "Encaje calado sobre base suave. Dos días de uso.",              date: "2026-11-20", img: "https://images.unsplash.com/photo-1584061677142-c729839e341f", by: "Uliana Kopanytsia",  handle: "ulian_ka" },
  { id: 2, ref: "0002", type: "conjunto",  title: "Lote de lencería surtida",      seller: "cleo",     size: "M", days: 4, price: 55, material: "Varios",            colour: "Surtido", desc: "Sujetadores y bragas de varios estilos, preparados en un solo envío.", date: "2026-11-18", img: "https://images.unsplash.com/photo-1568441556126-f36ae0900180", by: "Fahad Waseem",       handle: "fahadzia" },
  { id: 3, ref: "0003", type: "sujetador", title: "Sujetador negro de encaje",     seller: "maribel",  size: "M", days: 3, price: 35, material: "Encaje y microfibra", colour: "Negro",   desc: "Copa suave con detalle de encaje y cierre trasero.",            date: "2026-11-17", img: "https://images.unsplash.com/photo-1572358764342-612d02e2d2d2", by: "Danijela Prijovic",  handle: "dacakockica" },
  { id: 4, ref: "0004", type: "sujetador", title: "Bralette burdeos de encaje",    seller: "sofiluz",  size: "S", days: 6, price: 32, material: "Encaje elástico",   colour: "Burdeos", desc: "Sin aros, encaje en tono vino con tirantes cruzados.",          date: "2026-11-15", img: "https://images.unsplash.com/photo-1572109754335-3807540beef2", by: "Ivana Batalović",    handle: "ivanabatalovic" },
  { id: 5, ref: "0005", type: "sujetador", title: "Sujetador azul de encaje",      seller: "carlota",  size: "L", days: 4, price: 36, material: "Encaje",            colour: "Azul",    desc: "Encaje azul con aros, copa completa.",                          date: "2026-11-14", img: "https://images.unsplash.com/photo-1620228681518-5f0e3e29940d", by: "Nataliya Melnychuk", handle: "natinati" },
  { id: 6, ref: "0006", type: "sujetador", title: "Sujetador azul, copa completa", seller: "aitana",   size: "M", days: 5, price: 34, material: "Encaje elástico",   colour: "Azul",    desc: "Encaje elástico, cierre trasero de tres posiciones.",           date: "2026-11-12", img: "https://images.unsplash.com/photo-1620228757753-b28dacf3015a", by: "Nataliya Melnychuk", handle: "natinati" },
  { id: 7, ref: "0007", type: "camison",   title: "Camisón de satén rosa",         seller: "noa",      size: "S", days: 2, price: 40, material: "Satén",             colour: "Rosa",    desc: "Satén con tirantes finos y remate de encaje.",                  date: "2026-11-10", img: "https://images.unsplash.com/photo-1594631775771-890a902ae42d", by: "Laura Chouette",     handle: "laurachouette" },
  { id: 8, ref: "0008", type: "camison",   title: "Top de satén rojo con encaje",  seller: "mar",      size: "M", days: 3, price: 38, material: "Satén y encaje",    colour: "Rojo",    desc: "Satén rojo con remate de encaje.",                              date: "2026-11-08", img: "https://images.unsplash.com/photo-1624819153654-5cfb66a0fc68", by: "Emilio Garcia",      handle: "piensaenpixel" },
  { id: 9, ref: "0009", type: "braga",     title: "Braga beige de satén",          seller: "fitirene", size: "M", days: 8, price: 29, material: "Satén",             colour: "Beige",   desc: "Tono piel, uso intenso durante una semana.",                    date: "2026-11-06", img: "https://images.unsplash.com/photo-1633699124189-17c808027f4a", by: "hidefumi ohmichi",   handle: "hidefu" }
];
