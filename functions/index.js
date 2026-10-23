// Cloud Functions for Stocklet push notifications.
// They send a push when: (1) a supply drops below its minimum, (2) the daily
// reminder of orders due (today or overdue).
// Each user gets the text in THEIR language (stored in usuarios/{uid}.idioma).
//
// Needs the Blaze plan. Deploy with:  firebase deploy --only functions
//
// Node 22 and firebase-admin 14. SDK 14 removed the namespace, so
// admin.firestore() and friends no longer exist: everything comes in through
// modular imports. And deploying has to go through the npm CLI, not the winget
// one, which bundles Node 20 and cannot load this code. See docs/DEVELOPMENT.md.

const {onDocumentUpdated} =
    require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');

initializeApp();

const IDIOMAS = ['es', 'en', 'pt', 'fr'];
const IDIOMA_DEFECTO = 'es';

// Notification copy per language. Parameters are passed as a function.
const T = {
  es: {
    invTitulo: 'Inventario bajo',
    invBody: (nombre) => nombre + ' está por debajo del mínimo.',
    pedTitulo: 'Pedidos por entregar',
    pedBody: (n) => 'Tienes ' + n + ' pedido(s) para hoy o atrasados.',
  },
  en: {
    invTitulo: 'Low inventory',
    invBody: (nombre) => nombre + ' is below the minimum.',
    pedTitulo: 'Orders to deliver',
    pedBody: (n) => 'You have ' + n + ' order(s) due today or overdue.',
  },
  pt: {
    invTitulo: 'Estoque baixo',
    invBody: (nombre) => nombre + ' está abaixo do mínimo.',
    pedTitulo: 'Pedidos para entregar',
    pedBody: (n) => 'Você tem ' + n + ' pedido(s) para hoje ou atrasados.',
  },
  fr: {
    invTitulo: 'Stock faible',
    invBody: (nombre) => nombre + ' est en dessous du minimum.',
    pedTitulo: 'Commandes à livrer',
    pedBody: (n) => 'Vous avez ' + n + ' commande(s) pour aujourd\'hui ou en retard.',
  },
};

// Returns the members' tokens grouped by language:
//   { es: [...], en: [...] }
async function tokensPorIdioma(negocioId, excluyeUid) {
  const snap = await getFirestore()
      .collection('usuarios')
      .where('negocioId', '==', negocioId)
      .get();
  const grupos = {};
  snap.forEach((doc) => {
    if (excluyeUid && doc.id === excluyeUid) return;
    const arr = doc.get('fcmTokens') || [];
    if (!arr.length) return;
    let lang = doc.get('idioma') || IDIOMA_DEFECTO;
    if (!IDIOMAS.includes(lang)) lang = IDIOMA_DEFECTO;
    grupos[lang] = (grupos[lang] || []).concat(arr);
  });
  Object.keys(grupos).forEach((l) => {
    grupos[l] = [...new Set(grupos[l])];
  });
  return grupos;
}

// Sends each language group its own copy. `construir(t)` returns {title, body}.
async function enviarPorIdioma(grupos, construir) {
  for (const lang of Object.keys(grupos)) {
    const {title, body} = construir(T[lang]);
    await getMessaging().sendEachForMulticast({
      tokens: grupos[lang],
      notification: {title, body},
      data: {tipo: 'notificaciones'},
    });
  }
}

// (1) A supply crossing below its minimum stock.
exports.inventarioBajo = onDocumentUpdated(
    'negocios/{negocioId}/insumos/{insumoId}', async (event) => {
      const antes = event.data.before.data();
      const despues = event.data.after.data();
      const min = despues.stockMinimo || 0;
      if (min <= 0) return;
      const cruzaAbajo =
          (antes.stockActual >= min) && (despues.stockActual < min);
      if (!cruzaAbajo) return;
      const grupos = await tokensPorIdioma(event.params.negocioId, null);
      const nombre = despues.nombre || '';
      await enviarPorIdioma(grupos, (t) => ({
        title: t.invTitulo,
        body: t.invBody(nombre),
      }));
    });

// (2) Daily reminder of orders due (today or overdue).
exports.recordatorioPedidos = onSchedule(
    {schedule: 'every day 08:00', timeZone: 'America/Bogota'}, async () => {
      const ahora = new Date();
      const finDia = new Date(
          ahora.getFullYear(), ahora.getMonth(), ahora.getDate(),
          23, 59, 59);
      const snap = await getFirestore()
          .collectionGroup('pedidos')
          .where('entregado', '==', false)
          .get();
      const porNegocio = {};
      snap.forEach((doc) => {
        const d = doc.data();
        if (d.archivado === true) return;
        const fe = d.fechaEntrega;
        if (!fe) return;
        const fecha = fe.toDate ? fe.toDate() : new Date(fe);
        if (fecha <= finDia) {
          const negocioId = doc.ref.parent.parent.id;
          porNegocio[negocioId] = (porNegocio[negocioId] || 0) + 1;
        }
      });
      for (const negocioId of Object.keys(porNegocio)) {
        const n = porNegocio[negocioId];
        const grupos = await tokensPorIdioma(negocioId, null);
        await enviarPorIdioma(grupos, (t) => ({
          title: t.pedTitulo,
          body: t.pedBody(n),
        }));
      }
    });

// (3) Account deletion (a store requirement). The client has already
// reauthenticated before calling. If the user is the OWNER, the WHOLE business
// is deleted and the other members are detached. If they are a partner or
// employee, only their own account goes. Finally the Firebase Auth user is
// removed.
exports.eliminarCuenta = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  const db = getFirestore();
  const bucket = getStorage().bucket();

  const miDoc = await db.collection('usuarios').doc(uid).get();
  const negocioId = miDoc.exists ? miDoc.get('negocioId') : null;
  const rol = miDoc.exists ? miDoc.get('rol') : null;

  if (negocioId && rol === 'dueno') {
    // --- OWNER: delete the whole business ---
    // 1) Every member of the business (the owner included).
    const miembros = await db.collection('usuarios')
        .where('negocioId', '==', negocioId).get();
    const batch = db.batch();
    miembros.forEach((d) => batch.delete(d.ref));
    // 2) That business's pending invitations.
    const invitaciones = await db.collection('invitaciones')
        .where('negocioId', '==', negocioId).get();
    invitaciones.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    // 3) The entire business tree (subcollections included).
    await db.recursiveDelete(db.collection('negocios').doc(negocioId));
    // 4) The business files in Storage.
    try {
      await bucket.deleteFiles({prefix: `negocios/${negocioId}/`});
    } catch (e) {
      console.error('Error borrando storage del negocio', e);
    }
  } else if (miDoc.exists) {
    // --- Partner / employee: delete only their account ---
    await miDoc.ref.delete();
  }

  // The user's personal files in Storage.
  try {
    await bucket.deleteFiles({prefix: `usuarios/${uid}/`});
  } catch (e) {
    console.error('Error borrando storage del usuario', e);
  }

  // Finally, remove the Firebase Auth user.
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    console.error('Error borrando el usuario de Auth', e);
    throw new HttpsError('internal', 'No se pudo eliminar la cuenta.');
  }

  return {ok: true};
});
