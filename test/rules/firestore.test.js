// Tests for the Firestore security rules (../../firestore.rules).
//
// They run against the emulator:
//   cd test/rules && npm test
//
// What they set out to prove, in order of severity:
//   1. One business neither sees nor touches another business's data.
//   2. Nobody raises their own role or moves themselves between businesses.
//   3. The employee can work (selling deducts stock) without being able to
//      edit the catalogue or delete history.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test, { before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, collection, getDocs, query, where } from 'firebase/firestore';

const aqui = dirname(fileURLToPath(import.meta.url));
const [host, puerto] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');

let env;

// --- Fixtures ---------------------------------------------------------------
// Two independent businesses, with their people. negB exists to prove that
// negA cannot reach it.

const HARINA = {
  nombre: 'Harina',
  categoria: 'Secos',
  unidad: 'g',
  costoPorUnidad: 5,
  stockActual: 1000,
  stockMinimo: 100,
  unidadCompra: 'kg',
  cantidadCompra: 1,
  precioPresentacion: 5000,
  proveedor: 'Proveedor X',
  especial: false,
};

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'negocios/negA'), {
      nombre: 'Dulce Nota', pais: 'CO', moneda: 'COP', idioma: 'es', duenoUid: 'duenoA',
    });
    await setDoc(doc(db, 'negocios/negB'), {
      nombre: 'Otro Negocio', pais: 'CO', moneda: 'COP', idioma: 'es', duenoUid: 'duenoB',
    });

    await setDoc(doc(db, 'usuarios/duenoA'), { negocioId: 'negA', rol: 'dueno', nombre: 'Ana' });
    await setDoc(doc(db, 'usuarios/socioA'), { negocioId: 'negA', rol: 'socio', nombre: 'Sara' });
    await setDoc(doc(db, 'usuarios/empleadoA'), { negocioId: 'negA', rol: 'empleado', nombre: 'Eli' });
    await setDoc(doc(db, 'usuarios/duenoB'), { negocioId: 'negB', rol: 'dueno', nombre: 'Beto' });

    await setDoc(doc(db, 'negocios/negA/insumos/harina'), HARINA);
    await setDoc(doc(db, 'negocios/negA/productos/torta'), { nombre: 'Torta', precio: 50000 });
    await setDoc(doc(db, 'negocios/negA/ventas/v1'), { descripcion: 'Torta', cantidad: 1 });
    await setDoc(doc(db, 'negocios/negA/cotizaciones/c1'), { cliente: 'Cliente', descuento: 0 });
    await setDoc(doc(db, 'negocios/negA/catalogos/cat1'), { nombre: 'Catálogo', url: 'x', path: 'y' });
    await setDoc(doc(db, 'negocios/negB/insumos/azucar'), { ...HARINA, nombre: 'Azúcar' });

    await setDoc(doc(db, 'invitaciones/ABC123'), {
      negocioId: 'negA', rol: 'empleado', estado: 'pendiente',
      creadoPor: 'duenoA', usadaPor: '',
    });
  });
}

const como = (uid) => env.authenticatedContext(uid).firestore();
const sinSesion = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-stocklet',
    firestore: {
      // STOCKLET_RULES allows running the same suite against a different rules
      // file (for example the one deployed today) to compare them.
      rules: readFileSync(
        process.env.STOCKLET_RULES ?? resolve(aqui, '../../firestore.rules'), 'utf8'),
      host,
      port: Number(puerto),
    },
  });
});

after(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});

// --- 1. Isolation between businesses ---------------------------------------

test('without a session nothing is readable', async () => {
  await assertFails(getDoc(doc(sinSesion(), 'negocios/negA')));
  await assertFails(getDoc(doc(sinSesion(), 'negocios/negA/insumos/harina')));
});

test('another business owner cannot read the other business', async () => {
  await assertFails(getDoc(doc(como('duenoB'), 'negocios/negA')));
});

test('another business owner cannot read the other supplies', async () => {
  await assertFails(getDoc(doc(como('duenoB'), 'negocios/negA/insumos/harina')));
});

test('another business owner cannot read the other sales', async () => {
  await assertFails(getDocs(collection(como('duenoB'), 'negocios/negA/ventas')));
});

test('another business owner cannot write to the other business', async () => {
  await assertFails(setDoc(doc(como('duenoB'), 'negocios/negA/insumos/harina'), HARINA));
});

test('a user with no record reaches nothing', async () => {
  await assertFails(getDoc(doc(como('fantasma'), 'negocios/negA')));
  await assertFails(getDoc(doc(como('fantasma'), 'negocios/negA/insumos/harina')));
});

test('a user with a record but no business reaches nothing', async () => {
  // The edge case: a missing negocioId reads as '' and must not match any
  // document, not even another one whose field is also empty.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios/huerfano'), { nombre: 'Sin negocio' });
  });
  await assertFails(getDoc(doc(como('huerfano'), 'negocios/negA')));
  await assertFails(getDoc(doc(como('huerfano'), 'negocios/negA/insumos/harina')));
  await assertFails(getDoc(doc(como('huerfano'), 'usuarios/empleadoA')));
});

test('a member does read their own', async () => {
  await assertSucceeds(getDoc(doc(como('empleadoA'), 'negocios/negA')));
  await assertSucceeds(getDoc(doc(como('empleadoA'), 'negocios/negA/insumos/harina')));
});

// --- 2. Nobody promotes themselves -----------------------------------------

test('an employee cannot raise their role to owner', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'usuarios/empleadoA'),
    { negocioId: 'negA', rol: 'dueno', nombre: 'Eli' }));
});

test('an employee cannot raise their role to partner', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'usuarios/empleadoA'),
    { negocioId: 'negA', rol: 'socio', nombre: 'Eli' }));
});

test('an employee cannot move themselves to another business', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'usuarios/empleadoA'),
    { negocioId: 'negB', rol: 'empleado', nombre: 'Eli' }));
});

test('an employee can edit their own personal data', async () => {
  await assertSucceeds(setDoc(doc(como('empleadoA'), 'usuarios/empleadoA'),
    { negocioId: 'negA', rol: 'empleado', nombre: 'Eli Nuevo', celular: '3110000000' }));
});

test('nobody edits the record of another business\'s member', async () => {
  await assertFails(setDoc(doc(como('duenoB'), 'usuarios/empleadoA'),
    { negocioId: 'negA', rol: 'empleado', nombre: 'Hackeado' }, { merge: true }));
});

// --- 3. The owner manages their people, within limits -----------------------

test('the owner changes a member role', async () => {
  await assertSucceeds(setDoc(doc(como('duenoA'), 'usuarios/empleadoA'),
    { rol: 'socio' }, { merge: true }));
});

test('the owner cannot manufacture another owner', async () => {
  await assertFails(setDoc(doc(como('duenoA'), 'usuarios/empleadoA'),
    { rol: 'dueno' }, { merge: true }));
});

test('the owner cannot move a member to another business', async () => {
  await assertFails(setDoc(doc(como('duenoA'), 'usuarios/empleadoA'),
    { negocioId: 'negB' }, { merge: true }));
});

test('the owner removes a member from their business', async () => {
  await assertSucceeds(deleteDoc(doc(como('duenoA'), 'usuarios/empleadoA')));
});

test('an employee cannot remove another member', async () => {
  await assertFails(deleteDoc(doc(como('empleadoA'), 'usuarios/socioA')));
});

// --- 4. The employee works, but does not rule -------------------------------

test('the employee deducts stock when selling', async () => {
  // The app saves the whole supply document; the only thing that changes is stock.
  await assertSucceeds(setDoc(doc(como('empleadoA'), 'negocios/negA/insumos/harina'),
    { ...HARINA, stockActual: 750 }));
});

test('the employee cannot change a supply price', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA/insumos/harina'),
    { ...HARINA, costoPorUnidad: 1 }));
});

test('the employee cannot rename a supply while deducting stock', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA/insumos/harina'),
    { ...HARINA, nombre: 'Otra cosa', stockActual: 750 }));
});

test('the employee neither creates nor deletes supplies', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA/insumos/nuevo'), HARINA));
  await assertFails(deleteDoc(doc(como('empleadoA'), 'negocios/negA/insumos/harina')));
});

test('the partner does manage the catalogue', async () => {
  await assertSucceeds(setDoc(doc(como('socioA'), 'negocios/negA/insumos/harina'),
    { ...HARINA, costoPorUnidad: 7 }));
  await assertSucceeds(setDoc(doc(como('socioA'), 'negocios/negA/productos/torta'),
    { nombre: 'Torta grande', precio: 70000 }));
});

test('the employee does not touch products', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA/productos/torta'),
    { nombre: 'Torta', precio: 1 }));
});

test('the employee records a sale but cannot delete it', async () => {
  await assertSucceeds(setDoc(doc(como('empleadoA'), 'negocios/negA/ventas/v2'),
    { descripcion: 'Torta', cantidad: 1 }));
  await assertFails(deleteDoc(doc(como('empleadoA'), 'negocios/negA/ventas/v1')));
});

// Quoting is any member's job; catalogues are read-only for the employee.
// An explicit product-owner decision (2026-09-17).

test('the employee quotes: creates and corrects one', async () => {
  await assertSucceeds(setDoc(doc(como('empleadoA'), 'negocios/negA/cotizaciones/c2'),
    { cliente: 'Nuevo cliente', descuento: 0 }));
  await assertSucceeds(setDoc(doc(como('empleadoA'), 'negocios/negA/cotizaciones/c1'),
    { cliente: 'Cliente', descuento: 5000 }));
});

test('the employee does not delete quotes', async () => {
  await assertFails(deleteDoc(doc(como('empleadoA'), 'negocios/negA/cotizaciones/c1')));
});

test('the partner does delete quotes', async () => {
  await assertSucceeds(deleteDoc(doc(como('socioA'), 'negocios/negA/cotizaciones/c1')));
});

test('the employee cannot quote for another business', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negB/cotizaciones/c9'),
    { cliente: 'Ajeno', descuento: 0 }));
});

test('the employee reads catalogues but neither uploads nor deletes them', async () => {
  await assertSucceeds(getDoc(doc(como('empleadoA'), 'negocios/negA/catalogos/cat1')));
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA/catalogos/cat2'),
    { nombre: 'Mío', url: 'x', path: 'y' }));
  await assertFails(deleteDoc(doc(como('empleadoA'), 'negocios/negA/catalogos/cat1')));
});

test('the partner does upload catalogues', async () => {
  await assertSucceeds(setDoc(doc(como('socioA'), 'negocios/negA/catalogos/cat2'),
    { nombre: 'Nuevo', url: 'x', path: 'y' }));
});

test('the partner does correct history', async () => {
  await assertSucceeds(deleteDoc(doc(como('socioA'), 'negocios/negA/ventas/v1')));
});

// --- 5. Business and settings -----------------------------------------------

test('anyone creates their own business, but not in someone else\'s name', async () => {
  const base = { nombre: 'Nuevo', pais: 'CO', moneda: 'COP', idioma: 'es' };
  await assertSucceeds(setDoc(doc(como('nuevo'), 'negocios/negC'), { ...base, duenoUid: 'nuevo' }));
  await assertFails(setDoc(doc(como('nuevo'), 'negocios/negD'), { ...base, duenoUid: 'duenoA' }));
});

test('the employee does not change business settings', async () => {
  await assertFails(setDoc(doc(como('empleadoA'), 'negocios/negA'),
    { moneda: 'USD' }, { merge: true }));
});

test('the owner cannot hand the business to someone else from the client', async () => {
  await assertFails(setDoc(doc(como('duenoA'), 'negocios/negA'),
    { duenoUid: 'duenoB' }, { merge: true }));
});

test('nobody deletes the business from the client', async () => {
  await assertFails(deleteDoc(doc(como('duenoA'), 'negocios/negA')));
});

// --- 6. Invitations ---------------------------------------------------------

test('the owner lists their business invitations', async () => {
  const q = query(collection(como('duenoA'), 'invitaciones'), where('negocioId', '==', 'negA'));
  await assertSucceeds(getDocs(q));
});

test('nobody lists another business invitations', async () => {
  const q = query(collection(como('duenoB'), 'invitaciones'), where('negocioId', '==', 'negA'));
  await assertFails(getDocs(q));
});

test('the employee does not list their own business invitations', async () => {
  const q = query(collection(como('empleadoA'), 'invitaciones'), where('negocioId', '==', 'negA'));
  await assertFails(getDocs(q));
});

test('the owner cannot invite into another business', async () => {
  await assertFails(setDoc(doc(como('duenoA'), 'invitaciones/XXX999'), {
    negocioId: 'negB', rol: 'empleado', estado: 'pendiente',
    creadoPor: 'duenoA', usadaPor: '',
  }));
});

test('the owner cannot invite someone as owner', async () => {
  await assertFails(setDoc(doc(como('duenoA'), 'invitaciones/XXX998'), {
    negocioId: 'negA', rol: 'dueno', estado: 'pendiente',
    creadoPor: 'duenoA', usadaPor: '',
  }));
});

test('redeem an invitation and join the business', async () => {
  const db = como('recienLlegado');
  // 1) Claim the code.
  await assertSucceeds(setDoc(doc(db, 'invitaciones/ABC123'), {
    negocioId: 'negA', rol: 'empleado', estado: 'usada',
    creadoPor: 'duenoA', usadaPor: 'recienLlegado',
  }));
  // 2) Create the user record with what the invitation says.
  await assertSucceeds(setDoc(doc(db, 'usuarios/recienLlegado'), {
    negocioId: 'negA', rol: 'empleado', invitacionCodigo: 'ABC123',
  }));
});

test('cannot join with an invitation claimed by someone else', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'invitaciones/ABC123'), {
      negocioId: 'negA', rol: 'empleado', estado: 'usada',
      creadoPor: 'duenoA', usadaPor: 'otraPersona',
    });
  });
  await assertFails(setDoc(doc(como('colado'), 'usuarios/colado'), {
    negocioId: 'negA', rol: 'empleado', invitacionCodigo: 'ABC123',
  }));
});

test('redeeming an invitation does not let you pick your role', async () => {
  const db = como('ambicioso');
  await setDoc(doc(db, 'invitaciones/ABC123'), {
    negocioId: 'negA', rol: 'empleado', estado: 'usada',
    creadoPor: 'duenoA', usadaPor: 'ambicioso',
  });
  await assertFails(setDoc(doc(db, 'usuarios/ambicioso'), {
    negocioId: 'negA', rol: 'socio', invitacionCodigo: 'ABC123',
  }));
});

test('without an invitation you do not join another business', async () => {
  await assertFails(setDoc(doc(como('colado'), 'usuarios/colado'), {
    negocioId: 'negA', rol: 'empleado',
  }));
});

test('an already-used invitation cannot be redeemed again', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'invitaciones/ABC123'), {
      negocioId: 'negA', rol: 'empleado', estado: 'usada',
      creadoPor: 'duenoA', usadaPor: 'alguien',
    });
  });
  await assertFails(setDoc(doc(como('tardio'), 'invitaciones/ABC123'), {
    negocioId: 'negA', rol: 'empleado', estado: 'usada',
    creadoPor: 'duenoA', usadaPor: 'tardio',
  }));
});
