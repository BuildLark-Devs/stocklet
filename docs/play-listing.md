# Google Play listing — Stocklet

Screenshot script and listing copy. Everything is taken from the demo business
*Postres Aurora* (see "Demo business" in docs/DEVELOPMENT.md), never from the
real one.

The **listing copy itself stays in Spanish**: it is the text that ships on the
Colombian Play listing, not source prose. Only the instructions around it are in
English.

> Last reviewed: 2026-09-17, version 1.1.0+2.

---

## How to take them

The cleanest route is an **Android emulator with a Pixel profile** (1080×1920):
it comes out at the size Play prefers, with no messy status bar and no personal
notifications on top.

```
firebase emulators:start --only auth,firestore,storage --project mi-reposteria-app
```

```
cd tool/demo && npm run seed
```

```
flutter run --dart-define=STOCKLET_EMULATOR=true
```

Sign in with `demo@stocklet.app` / `demo1234`.

Before shooting: light mode, Spanish language, and the emulator full screen. If
a screenshot comes out wrong, seed again and it is identical.

---

## The script

Play shows the screenshots in order and **many people only see the first two**.
So the order is not "walk the menu" but tell a story: the problem it solves
first, then how.

### 1. Home — the whole business at a glance

**Screen**: Home, just after signing in.
**What is visible**: sales for the month, the six-month trend, the overdue-order
and low-stock notices.
**Why it goes first**: it is the only screenshot that answers "what is this?" in
two seconds.
**Suggested caption**: *Tu negocio completo, en una pantalla*

### 2. Costing breakdown — what nobody else tells you

**Screen**: Products → Cheesecake de maracuyá → costing breakdown.
**What is visible**: raw materials, waste, packaging, labour, energy and fixed
costs adding up to the real cost per unit, with the suggested price beside it
and the product flagged as underpriced.
**Why it goes second**: it is **the differentiator**. Any app records sales;
this one tells you what it actually costs you and what you should charge. The
cheesecake is underpriced on purpose so the traffic light is seen working.
**Suggested caption**: *Sabe cuánto te cuesta. Y cuánto deberías cobrar*

### 3. Money you are not earning

**Screen**: Home → opportunity panel (or the comparator screen).
**What is visible**: the monthly amount lost to products priced below their
suggested price.
**Why**: it turns costing into a figure that stings. This is the screenshot that
sells.
**Suggested caption**: *Cuánto estás dejando sobre la mesa cada mes*

### 4. Stock that deducts itself

**Screen**: Inventory, with Chocolate de cobertura below its minimum.
**What is visible**: supplies with their stock, the one in red, and the search
box.
**Why**: stock goes down by itself when selling or delivering orders; that is
what saves daily work.
**Suggested caption**: *El inventario baja solo cuando vendes*

### 5. Quote and send over WhatsApp

**Screen**: Quote → the "Matrimonio Vélez" quote, open.
**What is visible**: lines, add-ons, delivery, total, and the share buttons.
**Why**: this is work done today by hand, in voice notes and on paper.
**Suggested caption**: *Cotiza en un minuto y envíala por WhatsApp*

### 6. From accepted quote to order

**Screen**: the "Empresa Nutresa" quote (accepted, not converted) with the
create-order dialog open.
**What is visible**: the summary with customer and total, and the notice of what
will deduct stock.
**Why**: it is the newest feature and the one that best shows the app
understands the whole flow, not isolated screens.
**Suggested caption**: *El cliente acepta: el pedido se crea solo*

### 7. Orders with a delivery date

**Screen**: Orders, with the overdue one visible.
**What is visible**: pending, delivered, and the one running late.
**Suggested caption**: *Nunca más se te pasa una entrega*

### 8. Your team, with permissions

**Screen**: Settings → Members and invitations.
**What is visible**: the code invitation and the roles.
**Why**: it separates Stocklet from a personal notebook. It goes last because it
only matters to someone who already has a team.
**Suggested caption**: *Invita a tu equipo, sin darles todo el control*

> **Minimum viable set**: if you are only going to take four, take 1, 2, 3 and
> 5. Those four tell the whole story.

---

## Specifications Play requires

| Asset | Requirement |
|---|---|
| Phone screenshots | Between 2 and 8. 24-bit JPEG or PNG with no transparency. Short side at least 320 px, long side at most 3840 px. 1080×1920 recommended |
| 7" and 10" tablet screenshots | Optional, but **without them Play may flag the app as not optimised for tablets** |
| Icon | 512×512 32-bit PNG with alpha |
| Feature graphic | 1024×500 24-bit JPEG or PNG, no transparency. Mandatory. Generated with `tool/graphic/` |
| Short description | 80 characters maximum |
| Full description | 4000 characters maximum |
| Promo video | Optional, a YouTube link |

The feature graphic is cropped on many surfaces: **keep text away from the
edges** and avoid dropping a whole screenshot inside it.

---

## Listing copy (Spanish — ships as is)

### Short description (71 / 80)

```
Controla inventario, costos y precios de tu negocio. Sabe cuánto ganas.
```

### Full description

```
Stocklet es la app de gestión para negocios pequeños que quieren saber, de
verdad, cuánto ganan.

No es otra libreta de ventas. Stocklet calcula cuánto te cuesta producir cada
cosa —incluyendo la merma, el empaque, tu tiempo, la energía y los gastos fijos
del mes— y te dice a qué precio deberías venderla para no trabajar gratis.

QUÉ RESUELVE

• Cuánto te cuesta cada producto, de principio a fin
Materia prima, merma, empaque, mano de obra, energía y gastos fijos prorrateados
por lote. El costo real, no el aproximado.

• A qué precio vender
Stocklet sugiere el precio según el margen que quieras y te marca en rojo los
productos que estás vendiendo por debajo de lo que cuestan.

• Cuánto estás dejando de ganar
Un panel te muestra, en pesos y al mes, lo que pierdes por tener productos mal
cobrados.

• Inventario sin contar a mano
Registra la venta y el inventario baja solo, según la receta de cada producto.
Te avisa cuando un insumo está por acabarse.

• Cotizaciones que se vuelven pedidos
Arma la cotización, envíala por WhatsApp o PDF, y cuando el cliente acepte,
conviértela en pedido sin volver a escribir nada.

• Pedidos con fecha de entrega
Con recordatorio de lo que hay que entregar hoy y aviso de lo que va atrasado.

• Tu equipo, con permisos
Invita socios y empleados por código. Cada rol ve y hace lo que le corresponde.

• Reportes que se entienden
Ventas por mes, por día de semana, productos más vendidos y comparador entre
productos. Además, un simulador para ver qué pasa con tus precios si suben los
insumos.

PARA QUIÉN ES

Reposterías, panaderías, cocinas caseras, talleres y cualquier negocio pequeño
que produzca por lotes y venda por unidad.

Funciona en español, inglés, portugués y francés, con la moneda de tu país.

Empieza gratis. Tus datos quedan sincronizados y puedes trabajar desde el
teléfono y desde el computador.
```

*(1,925 characters out of 4,000: there is room left for use cases or
testimonials later.)*

---

## Short descriptions in the other languages

The app ships in four languages, so it is worth localising at least the short
description of each listing.

| Language | Text | Characters |
|---|---|---|
| English | `Track inventory, costs and prices. Know what your business really earns.` | 72 |
| Portuguese | `Controle estoque, custos e preços. Saiba quanto seu negócio realmente ganha.` | 76 |
| French | `Gérez stock, coûts et prix. Sachez ce que votre activité gagne vraiment.` | 72 |

The full description in those three languages is still pending; to launch in
Colombia the Spanish one is enough, and the others get added as each market
opens.

---

## Before uploading

- [ ] Screenshots taken from the demo business, **never the real one** (see
      `docs/data-safety.md`: the app stores customer data)
- [ ] No screenshot shows a real person's email or phone number
- [ ] Feature graphic 1024×500 with no text against the edges
- [ ] Short description within 80 characters
- [ ] Privacy policy URL set on the listing
- [ ] Account deletion URL set on the listing
- [ ] Data Safety form filled in from `docs/data-safety.md`
