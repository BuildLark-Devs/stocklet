// Seeds a demo business into the Firebase EMULATORS.
//
// Why: Google Play listing screenshots cannot come from the real business.
// Stocklet screens show customer names and phone numbers, sales, costs and
// margins; a screenshot on Play is public and permanent. With this script the
// screenshots come from invented data and, on top of that, are repeatable: if
// Play asks for them again, seed again and the result is identical.
//
// It never touches production: if it does not find the emulators, it refuses
// to run.
//
// Usage:
//   1. firebase emulators:start --only auth,firestore,storage --project mi-reposteria-app
//   2. cd tool/demo && npm install && npm run seed
//   3. flutter run --dart-define=STOCKLET_EMULATOR=true
//   4. Sign in with the credentials it prints at the end.

import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

// --- Guard: emulators only ---------------------------------------------------
//
// The projectId HAS to match the one the app uses (`firebase_options.dart`),
// because the Firestore emulator partitions data by project: seeding into a
// different one leaves the app looking at an empty database.
//
// So the project name cannot be the safeguard. What actually keeps production
// out of reach is that the requests go to the emulator, so we check it is
// listening before writing anything.
const HOST_FIRESTORE =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const HOST_AUTH =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = HOST_FIRESTORE;
process.env.FIREBASE_AUTH_EMULATOR_HOST = HOST_AUTH;

const PROYECTO = process.env.GCLOUD_PROJECT || 'mi-reposteria-app';

async function exigirEmuladores() {
  for (const [nombre, host] of [
    ['Firestore', HOST_FIRESTORE],
    ['Auth', HOST_AUTH],
  ]) {
    try {
      const res = await fetch(`http://${host}/`, { signal: AbortSignal.timeout(3000) });
      if (!res.ok && res.status !== 404) throw new Error(`HTTP ${res.status}`);
    } catch (e) {
      console.error(
        `\nCannot find the ${nombre} emulator at ${host}.\n` +
        'This script only seeds against emulators; without them it writes nothing.\n\n' +
        '  firebase emulators:start --only auth,firestore,storage ' +
        `--project ${PROYECTO}\n`);
      process.exit(1);
    }
  }
}

initializeApp({ projectId: PROYECTO });
const db = getFirestore();
const auth = getAuth();

// Emulator credentials. Useless outside it: the Auth emulator does not share
// users with the real project.
const CORREO = 'demo@stocklet.app';
const CLAVE = 'demo1234';

const NEGOCIO = 'negocio-demo';
const ts = (d) => Timestamp.fromDate(d);
const diasAtras = (n) => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
};
const enDias = (n) => {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return d;
};

// --- Supplies ----------------------------------------------------------------
// costoPorUnidad is in the BASE unit (g / ml / each), the same conversion the
// app does on the purchase presentation.
const insumos = [
  ['harina', 'Harina de trigo', 'Harinas y almidones', 'g', 4.2, 12000, 3000, 'kg', 1, 4200, 'Distribuidora El Molino'],
  ['azucar', 'Azúcar', 'Azúcares y sustitutos', 'g', 3.8, 9000, 2000, 'kg', 1, 3800, 'Distribuidora El Molino'],
  ['mantequilla', 'Mantequilla', 'Grasas', 'g', 18, 2800, 1000, 'kg', 1, 18000, 'Lácteos del Valle'],
  ['huevos', 'Huevos', 'Lácteos y huevos', 'unidad', 800, 48, 24, 'doc', 1, 9600, 'Granja La Esperanza'],
  ['chocolate', 'Chocolate de cobertura', 'Chocolates y cacao', 'g', 32, 1800, 2000, 'kg', 1, 32000, 'Cacao Andino'],
  ['leche', 'Leche entera', 'Lácteos y huevos', 'ml', 3.5, 6000, 2000, 'l', 1, 3500, 'Lácteos del Valle'],
  ['polvo', 'Polvo de hornear', 'Leudantes', 'g', 25, 700, 200, 'g', 1, 25, 'Distribuidora El Molino'],
  ['vainilla', 'Esencia de vainilla', 'Saborizantes y aditivos', 'ml', 90, 220, 100, 'ml', 1, 90, 'Cacao Andino'],
  ['queso', 'Queso crema', 'Lácteos y huevos', 'g', 24, 3000, 1000, 'kg', 1, 24000, 'Lácteos del Valle'],
  ['caja', 'Caja para torta', 'Empaques', 'unidad', 1200, 35, 15, 'unidad', 1, 1200, 'Empaques Rionegro'],
  ['base', 'Base para brownie', 'Empaques', 'unidad', 350, 120, 50, 'unidad', 1, 350, 'Empaques Rionegro'],
  ['bolsa', 'Bolsa de galletas', 'Empaques', 'unidad', 250, 200, 60, 'unidad', 1, 250, 'Empaques Rionegro'],
];

// --- Products ----------------------------------------------------------------
const r = (insumoId, cantidad) => ({ insumoId, cantidad });

const productos = [
  {
    id: 'torta-chocolate',
    nombre: 'Torta de chocolate',
    tipo: 'Tortas',
    precioVenta: 76000,
    rendimiento: 1,
    mermaPct: 5,
    minutosPrep: 55,
    minutosHorno: 45,
    unidadesMesEstimadas: 14,
    receta: [r('harina', 350), r('azucar', 300), r('mantequilla', 220),
             r('huevos', 4), r('chocolate', 260), r('leche', 200), r('polvo', 15)],
    empaque: [r('caja', 1)],
  },
  {
    id: 'brownies',
    nombre: 'Brownies',
    tipo: 'Brownies',
    precioVenta: 5000,
    rendimiento: 24,
    mermaPct: 8,
    minutosPrep: 40,
    minutosHorno: 35,
    unidadesMesEstimadas: 220,
    receta: [r('harina', 400), r('azucar', 600), r('mantequilla', 350),
             r('huevos', 6), r('chocolate', 500), r('vainilla', 10)],
    empaque: [r('base', 1)],
  },
  {
    id: 'galletas-vainilla',
    nombre: 'Galletas de vainilla',
    tipo: 'New York Cookies',
    precioVenta: 2800,
    rendimiento: 50,
    mermaPct: 6,
    minutosPrep: 35,
    minutosHorno: 25,
    unidadesMesEstimadas: 380,
    receta: [r('harina', 900), r('azucar', 500), r('mantequilla', 400),
             r('huevos', 4), r('vainilla', 20), r('polvo', 20)],
    empaque: [r('bolsa', 1)],
  },
  {
    // Deliberately below its suggested price, so the opportunity panel and
    // the price traffic light have something to show.
    id: 'cheesecake',
    nombre: 'Cheesecake de maracuyá',
    tipo: 'Tortas',
    precioVenta: 9000,
    rendimiento: 12,
    mermaPct: 5,
    minutosPrep: 50,
    minutosHorno: 40,
    unidadesMesEstimadas: 60,
    receta: [r('queso', 900), r('azucar', 350), r('huevos', 5),
             r('mantequilla', 150), r('harina', 200), r('vainilla', 8)],
    empaque: [r('caja', 1)],
  },
];

// --- Sales: six months of history, so the charts have a shape ---------------
const catalogoVentas = [
  ['Torta de chocolate', 76000, 59515],
  ['Brownies', 5000, 2100],
  ['Galletas de vainilla', 2800, 1150],
  ['Cheesecake de maracuyá', 9000, 7014],
];

function generarVentas() {
  const ventas = [];
  let semilla = 7;
  const aleatorio = () => {
    semilla = (semilla * 9301 + 49297) % 233280;
    return semilla / 233280;
  };
  for (let dia = 175; dia >= 0; dia -= 1) {
    const fecha = diasAtras(dia);
    const finDeSemana = fecha.getDay() === 0 || fecha.getDay() === 6;
    // They sell something every day: a zero leaves the trend chart with a
    // downward spike that reads as an app bug rather than a slow day. And the
    // volume has to cover the fixed expenses of the month comfortably: a demo
    // business running at a loss is a terrible first screenshot.
    const cuantas = finDeSemana ? Math.floor(aleatorio() * 5) + 5
                                : Math.floor(aleatorio() * 4) + 3;
    for (let i = 0; i < cuantas; i += 1) {
      const [nombre, precio, costo] = catalogoVentas[
        Math.floor(aleatorio() * catalogoVentas.length)];
      const cantidad = precio > 50000 ? 1 : Math.floor(aleatorio() * 6) + 1;
      ventas.push({
        fecha: ts(fecha),
        descripcion: nombre,
        cantidad,
        precioUnitario: precio,
        costoUnitario: costo,
      });
    }
  }
  return ventas;
}

const gastos = [
  [2, 'Compra de insumos del mes', 'insumos', 640000],
  [5, 'Arriendo del local', 'servicios', 800000],
  [6, 'Energía y agua', 'servicios', 245000],
  [9, 'Cajas y bolsas', 'empaques', 180000],
  [14, 'Internet', 'servicios', 92000],
  [21, 'Mantenimiento del horno', 'otros', 150000],
  [33, 'Compra de insumos del mes', 'insumos', 580000],
  [35, 'Arriendo del local', 'servicios', 800000],
  [48, 'Publicidad en redes', 'otros', 120000],
];

// --- Orders ------------------------------------------------------------------
const item = (nombre, cantidad, precio, costo, receta) => ({
  nombre, cantidad, precioUnitario: precio, costoUnitario: costo, receta,
});

const pedidos = [
  {
    id: 'pedido-hoy',
    cliente: { nombre: 'Laura Restrepo', telefono: '3115558842' },
    descripcion: '1x Torta de chocolate, 24x Brownies',
    fechaPedido: ts(diasAtras(4)),
    fechaEntrega: ts(new Date()),
    precio: 215000,
    costo: 91400,
    entregado: false,
    archivado: false,
    otroValor: 0,
    items: [
      item('Torta de chocolate', 1, 95000, 41000,
           [r('harina', 350), r('azucar', 300), r('chocolate', 260), r('caja', 1)]),
      item('Brownies', 24, 5000, 2100, [r('base', 1), r('chocolate', 21)]),
    ],
  },
  {
    // Overdue: triggers the pending-orders notice on the Home screen.
    id: 'pedido-atrasado',
    cliente: { nombre: 'Andrés Gómez', telefono: '3004471290' },
    descripcion: '50x Galletas de vainilla',
    fechaPedido: ts(diasAtras(9)),
    fechaEntrega: ts(diasAtras(2)),
    precio: 140000,
    costo: 57500,
    entregado: false,
    archivado: false,
    otroValor: 0,
    items: [item('Galletas de vainilla', 50, 2800, 1150,
                 [r('harina', 18), r('bolsa', 1)])],
  },
  {
    id: 'pedido-entregado',
    cliente: { nombre: 'Cafetería La Plaza', telefono: '3201118834' },
    descripcion: '12x Cheesecake de maracuyá',
    fechaPedido: ts(diasAtras(18)),
    fechaEntrega: ts(diasAtras(12)),
    precio: 108000,
    costo: 84168,
    entregado: true,
    archivado: false,
    otroValor: 0,
    items: [item('Cheesecake de maracuyá', 12, 9000, 7014, [r('queso', 75)])],
  },
];

// --- Quotes ------------------------------------------------------------------
const linea = (nombre, precio, cantidad, productoId) =>
  ({ nombre, precioUnitario: precio, cantidad, productoId: productoId ?? null });

const cotizaciones = [
  {
    id: 'cotiza-enviada',
    cliente: 'Matrimonio Vélez',
    fecha: ts(diasAtras(3)),
    estado: 'enviada',
    lineas: [
      linea('Torta de chocolate', 95000, 2, 'torta-chocolate'),
      linea('Brownies', 5000, 60, 'brownies'),
    ],
    adiciones: [{ nombre: 'Decoración personalizada', valor: 45000 }],
    domicilio: 15000,
    descuento: 0,
    aplicaIva: false,
    tasaIva: 19,
    notas: 'Entrega en el salón, montaje incluido.',
    pedidoId: '',
  },
  {
    // Accepted and not yet converted, so the "create order" button shows.
    id: 'cotiza-aceptada',
    cliente: 'Empresa Nutresa',
    fecha: ts(diasAtras(1)),
    estado: 'aceptada',
    lineas: [
      linea('Galletas de vainilla', 2800, 120, 'galletas-vainilla'),
      linea('Brownies', 5000, 80, 'brownies'),
    ],
    adiciones: [],
    domicilio: 20000,
    descuento: 30000,
    aplicaIva: false,
    tasaIva: 19,
    notas: 'Pedido corporativo, fin de mes.',
    pedidoId: '',
  },
];

// --- Team --------------------------------------------------------------------
// A business with a single member does not show off the roles, which is
// exactly what separates Stocklet from a personal notebook.
const miembros = [
  ['socio-demo', 'Mariana Ochoa', 'socio', '3145567821'],
  ['empleado-demo', 'Julián Mesa', 'empleado', '3179923410'],
];

// A pending invitation, so the invite-code mechanism is visible.
const invitaciones = [
  ['K7M2QP', 'empleado', 'pendiente', ''],
];

// --- Seeding -----------------------------------------------------------------
async function limpiar() {
  await db.recursiveDelete(db.collection('negocios').doc(NEGOCIO));
  // usuarios and invitaciones are root collections: deleting the business does
  // not take them with it, and without cleaning them here seeding stops being
  // repeatable.
  for (const col of ['usuarios', 'invitaciones']) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

async function crearUsuario() {
  try {
    await auth.deleteUser('demo-uid');
  } catch { /* did not exist */ }
  await auth.createUser({
    uid: 'demo-uid',
    email: CORREO,
    password: CLAVE,
    displayName: 'Camila Ríos',
  });
  return 'demo-uid';
}

async function seed() {
  await exigirEmuladores();
  console.log(`Seeding project "${PROYECTO}" (emulators)...`);
  await limpiar();
  const uid = await crearUsuario();

  await db.collection('usuarios').doc(uid).set({
    negocioId: NEGOCIO,
    rol: 'dueno',
    nombre: 'Camila Ríos',
    celular: '3123456789',
    fotoUrl: '',
    idioma: 'es',
  });

  for (const [id, nombre, rol, celular] of miembros) {
    await db.collection('usuarios').doc(id).set({
      negocioId: NEGOCIO, rol, nombre, celular, fotoUrl: '', idioma: 'es',
    });
  }

  for (const [codigo, rol, estado, usadaPor] of invitaciones) {
    await db.collection('invitaciones').doc(codigo).set({
      negocioId: NEGOCIO, rol, estado, creadoPor: uid, usadaPor,
      fecha: ts(diasAtras(1)),
    });
  }

  await db.collection('negocios').doc(NEGOCIO).set({
    nombre: 'Postres Aurora',
    pais: 'CO',
    moneda: 'COP',
    idioma: 'es',
    duenoUid: uid,
    nit: '901.234.567-8',
    correo: 'hola@postresaurora.com',
    tel: '3123456789',
    ubicacion: 'Rionegro, Antioquia',
    logoUrl: '',
    tarifaHora: 12000,
    costoEnergiaHora: 2500,
    gastosFijos: [
      { nombre: 'Arriendo', valor: 800000 },
      { nombre: 'Servicios', valor: 245000 },
      { nombre: 'Internet', valor: 92000 },
    ],
    lotesMes: 45,
    metodoMargen: 'venta',
    margenPct: 40,
    margenEspecialPct: 55,
    ivaAplica: false,
    ivaTasa: 19,
  });

  const col = (n) => db.collection('negocios').doc(NEGOCIO).collection(n);

  for (const [id, nombre, categoria, unidad, costoPorUnidad, stockActual,
               stockMinimo, unidadCompra, cantidadCompra, precioPresentacion,
               proveedor] of insumos) {
    await col('insumos').doc(id).set({
      nombre, categoria, unidad, costoPorUnidad, stockActual, stockMinimo,
      unidadCompra, cantidadCompra, precioPresentacion, proveedor,
      especial: false,
    });
  }

  for (const p of productos) {
    const { id, ...datos } = p;
    await col('productos').doc(id).set({
      ...datos,
      metodoMargen: '',
      margenPct: null,
      sinAzucar: false,
    });
  }

  const ventas = generarVentas();
  let lote = db.batch();
  let n = 0;
  for (const v of ventas) {
    lote.set(col('ventas').doc(), v);
    n += 1;
    if (n % 400 === 0) { await lote.commit(); lote = db.batch(); }
  }
  await lote.commit();

  for (const [dias, descripcion, categoria, monto] of gastos) {
    await col('gastos').doc().set({
      fecha: ts(diasAtras(dias)), descripcion, categoria, monto,
    });
  }

  for (const p of pedidos) {
    const { id, ...datos } = p;
    await col('pedidos').doc(id).set(datos);
  }

  for (const c of cotizaciones) {
    const { id, ...datos } = c;
    await col('cotizaciones').doc(id).set(datos);
  }

  console.log(`
Done. Demo business "Postres Aurora":
  ${insumos.length} supplies (chocolate below its minimum, on purpose)
  ${productos.length} products with a recipe (the cheesecake underpriced, on purpose)
  ${ventas.length} sales across six months
  ${gastos.length} expenses, ${pedidos.length} orders, ${cotizaciones.length} quotes
  team: owner + ${miembros.length} members and ${invitaciones.length} pending invitation

Sign in to the app with:
  email:    ${CORREO}
  password: ${CLAVE}

  flutter run --dart-define=STOCKLET_EMULATOR=true
`);
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
