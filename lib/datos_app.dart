import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/insumo.dart';
import 'models/producto.dart';
import 'models/venta.dart';
import 'models/gasto.dart';
import 'models/cliente.dart';
import 'models/pedido.dart';
import 'models/ingrediente_de_receta.dart';
import 'models/resumen_mensual.dart';
import 'models/negocio.dart';
import 'models/cotizacion.dart';
import 'costeo.dart';
import 'formato.dart';
import 'models/guia_receta.dart';
import 'models/item_pedido.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/catalogo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'servicios/push_service.dart';
import 'servicios/suscripcion_service.dart';

// Sentinel that distinguishes "leave alone" from "set to null" in parameters.
class _Sentinel {
  const _Sentinel();
}
const _sinCambio = _Sentinel();

enum EstadoApp { cargando, sinSesion, sinNegocio, listo }

const _mesesCorto = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
];

class PuntoTendencia {
  final String etiqueta;
  final double valor;
  PuntoTendencia(this.etiqueta, this.valor);
}

enum RangoTendencia { mes, tres, seis, anio }

class ProductoVendido {
  final String nombre;
  final double cantidad;
  final double total;
  ProductoVendido(this.nombre, this.cantidad, this.total);
}

class LineaCompraInsumo {
  final Insumo insumo;
  final double cantidad;
  final double total;
  LineaCompraInsumo(this.insumo, this.cantidad, this.total);
}

class AnalisisVentas {
  final int numVentas;
  final double totalVendido;
  final double ticketPromedio;
  final List<MapEntry<String, double>> porMes;      // 'Mmm aaaa' -> total
  final List<MapEntry<int, double>> porDiaSemana;   // 1=Lun..7=Dom -> total
  final List<MapEntry<DateTime, double>> fechasPico; // día -> total
  AnalisisVentas({
    required this.numVentas,
    required this.totalVendido,
    required this.ticketPromedio,
    required this.porMes,
    required this.porDiaSemana,
    required this.fechasPico,
  });
}

// A code invitation for joining a business.
class Invitacion {
  final String codigo;
  final String rol; // 'socio' | 'empleado'
  final String estado; // 'pendiente' | 'usada'
  final String usadaPor;
  Invitacion({
    required this.codigo,
    required this.rol,
    required this.estado,
    required this.usadaPor,
  });
}

// A business member (for the owner panel).
class MiembroNegocio {
  final String uid;
  final String nombre;
  final String rol; // 'dueno' | 'socio' | 'empleado'
  MiembroNegocio({required this.uid, required this.nombre, required this.rol});
}

class DatosApp extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  String? _negocioId; // a qué negocio pertenece el usuario actual
  EstadoApp estado = EstadoApp.cargando;
  Negocio? negocio;
  String perfilNombre = '';
  String perfilCelular = '';
  String perfilFotoUrl = '';
  bool notifPedidos = true;
  bool notifInsumos = true;
  String acentoId = 'verde';
  String modoTemaId = 'claro'; // 'claro' | 'oscuro' | 'auto'
  // Language chosen by the user. null = follow the device language.
  String? idiomaId;
  // Current user's role in the business: 'dueno' | 'socio' | 'empleado'.
  // Defaults to 'empleado' (fewest privileges) until the real one loads.
  String rolUsuario = 'empleado';

  List<Insumo> insumos = [];
  List<Producto> productos = [];
  List<Cliente> clientes = [];
  List<Venta> ventas = [];
  List<Gasto> gastos = [];
  List<Pedido> pedidos = [];
  List<GuiaReceta> recetas = [];
  List<Catalogo> catalogos = [];
  List<Cotizacion> cotizaciones = [];

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _productosRaw = [];
  final List<StreamSubscription> _suscripciones = [];

  DatosApp() {
    _cargarPrefsNotif();
    // When the Pro state changes (RevenueCat), refresh the UI.
    SuscripcionService.instance.esPro.addListener(notifyListeners);
    FirebaseAuth.instance.authStateChanges().listen((usuario) async {
      if (usuario != null) {
        estado = EstadoApp.cargando;
        notifyListeners();
        await _cargarNegocioId(usuario.uid);
        // The subscription is tied to the uid, not to the installation.
        await SuscripcionService.instance.identificar(usuario.uid);
        if (_negocioId != null) {
          _escucharTodo();
          estado = EstadoApp.listo;
          PushService.instance.guardarToken(usuario.uid);
          guardarIdiomaUsuario();
        } else {
          estado = EstadoApp.sinNegocio;
        }
        notifyListeners();
      } else {
        estado = EstadoApp.sinSesion;
        _negocioId = null;
        negocio = null;        // limpia el negocio anterior
        reiniciarMoneda();     // vuelve la moneda a la de por defecto
        // Unlink the subscription: the next user on this device must not
        // inherit the previous one's Pro.
        await SuscripcionService.instance.cerrarSesion();
        _detenerYLimpiar();
      }
    });
  }

  /// `true` if the user has Pro (or if monetisation is inactive).
  /// Mirrors the RevenueCat state via [SuscripcionService].
  bool get esPro => SuscripcionService.instance.esPro.value;

Future<void> _cargarNegocioId(String uid) async {
    // 1) Which business do I belong to? This decides whether you get in.
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      _negocioId = doc.exists ? (doc.data()?['negocioId'] as String?) : null;
      perfilNombre = (doc.data()?['nombre'] as String?) ?? '';
      perfilCelular = (doc.data()?['celular'] as String?) ?? '';
      perfilFotoUrl = (doc.data()?['fotoUrl'] as String?) ?? '';
      rolUsuario = (doc.data()?['rol'] as String?) ?? 'empleado';
    } catch (e) {
      _negocioId = null;
      return;
    }

    // 2) Fetch the business data (currency, name). On failure we do NOT
    //    lose the negocioId: you still get in, with the default currency.
    if (_negocioId != null) {
      try {
        final negDoc = await _db.collection('negocios').doc(_negocioId).get();
        if (negDoc.exists) {
          negocio = Negocio.fromMap(negDoc.id, negDoc.data()!);
          configurarMoneda(
            moneda: negocio!.moneda,
            idioma: negocio!.idioma,
            pais: negocio!.pais,
          );
        }
      } catch (e) {
        // Default currency; what matters is that you reach your business.
      }
    }
  }

  // Creates a new business and links the current user to it
  Future<void> crearNegocio({
    required String nombre,
    required String pais,
    required String moneda,
    required String idioma,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _db.collection('negocios').doc();
    await ref.set({
      'nombre': nombre,
      'pais': pais,
      'moneda': moneda,
      'idioma': idioma,
      'duenoUid': uid,
    });
    await _db.collection('usuarios').doc(uid).set({
      'negocioId': ref.id,
      'rol': 'dueno',
    });
    _negocioId = ref.id;
    negocio = Negocio(
      id: ref.id,
      nombre: nombre,
      pais: pais,
      moneda: moneda,
      idioma: idioma,
      duenoUid: uid,
    );
    rolUsuario = 'dueno';
    configurarMoneda(moneda: moneda, idioma: idioma, pais: pais);
    _escucharTodo();
    estado = EstadoApp.listo;
    PushService.instance.guardarToken(uid);
    guardarIdiomaUsuario();
    notifyListeners();
  }

  // --- Roles and permissions (UX layer; real security lives in the rules) ---
  String get _uidActual => FirebaseAuth.instance.currentUser?.uid ?? '';
  // Owner if their role is 'dueno' or they created the business (duenoUid).
  bool get esDueno =>
      rolUsuario == 'dueno' ||
      (negocio != null && negocio!.duenoUid == _uidActual);
  bool get _duenoOSocio => esDueno || rolUsuario == 'socio';
  // May delete any record (owner or partner).
  bool get puedeEliminar => _duenoOSocio;
  // May create/edit the catalogue: products, supplies and recipes.
  bool get puedeGestionarCatalogo => _duenoOSocio;
  // May edit the sales and expenses history.
  bool get puedeEditarFinanzas => _duenoOSocio;

  // --- Invitations and members (the invite-code centre) ---
  static String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin ambiguos (0/O, 1/I)
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // The owner generates an invitation with a role ('socio' | 'empleado').
  Future<String> crearInvitacion(String rol) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final codigo = _generarCodigo();
    await _db.collection('invitaciones').doc(codigo).set({
      'negocioId': _negocioId,
      'rol': rol,
      'estado': 'pendiente',
      'creadoPor': uid,
      'fecha': FieldValue.serverTimestamp(),
      'usadaPor': '',
    });
    return codigo;
  }

  Future<List<Invitacion>> cargarInvitaciones() async {
    if (_negocioId == null) return [];
    final snap = await _db
        .collection('invitaciones')
        .where('negocioId', isEqualTo: _negocioId)
        .get();
    final lista = snap.docs
        .map((d) => Invitacion(
              codigo: d.id,
              rol: (d.data()['rol'] as String?) ?? '',
              estado: (d.data()['estado'] as String?) ?? '',
              usadaPor: (d.data()['usadaPor'] as String?) ?? '',
            ))
        .toList();
    // Pendientes primero.
    lista.sort((a, b) => a.estado.compareTo(b.estado));
    return lista;
  }

  Future<void> revocarInvitacion(String codigo) async {
    await _db.collection('invitaciones').doc(codigo).delete();
  }

  Future<List<MiembroNegocio>> cargarMiembros() async {
    if (_negocioId == null) return [];
    final snap = await _db
        .collection('usuarios')
        .where('negocioId', isEqualTo: _negocioId)
        .get();
    return snap.docs
        .map((d) => MiembroNegocio(
              uid: d.id,
              nombre: (d.data()['nombre'] as String?) ?? '',
              rol: (d.data()['rol'] as String?) ?? 'empleado',
            ))
        .toList();
  }

  Future<void> cambiarRolMiembro(String uid, String nuevoRol) async {
    await _db
        .collection('usuarios')
        .doc(uid)
        .set({'rol': nuevoRol}, SetOptions(merge: true));
  }

  Future<void> quitarMiembro(String uid) async {
    await _db.collection('usuarios').doc(uid).delete();
  }

  // The guest joins with a code. Returns null on success, or an error key:
  // 'sesion' | 'noExiste' | 'usada' | 'invalida' | 'error'.
  Future<String?> unirsePorCodigo(String codigo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'sesion';
    try {
      final ref = _db.collection('invitaciones').doc(codigo.trim().toUpperCase());
      final snap = await ref.get();
      if (!snap.exists) return 'noExiste';
      final data = snap.data()!;
      if (data['estado'] != 'pendiente') return 'usada';
      final negId = data['negocioId'] as String?;
      final rol = data['rol'] as String?;
      if (negId == null || rol == null || rol == 'dueno') return 'invalida';

      // 1) Claim the code.
      await ref.update({'estado': 'usada', 'usadaPor': uid});
      // 2) Create the user -> business link.
      await _db.collection('usuarios').doc(uid).set({
        'negocioId': negId,
        'rol': rol,
        'invitacionCodigo': ref.id,
      }, SetOptions(merge: true));

      // 3) Enter the business.
      _negocioId = negId;
      rolUsuario = rol;
      final negDoc = await _db.collection('negocios').doc(negId).get();
      if (negDoc.exists) {
        negocio = Negocio.fromMap(negDoc.id, negDoc.data()!);
        configurarMoneda(
          moneda: negocio!.moneda,
          idioma: negocio!.idioma,
          pais: negocio!.pais,
        );
      }
      _escucharTodo();
      estado = EstadoApp.listo;
      PushService.instance.guardarToken(uid);
      guardarIdiomaUsuario();
      notifyListeners();
      return null;
    } catch (e) {
      return 'error';
    }
  }

  // Saves the user personal data (in usuarios/{uid})
  Future<void> guardarPerfil(
      {required String nombre, required String celular}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('usuarios').doc(uid).set(
      {'nombre': nombre, 'celular': celular},
      SetOptions(merge: true),
    );
    perfilNombre = nombre;
    perfilCelular = celular;
    notifyListeners();
  }

  Future<void> _cargarPrefsNotif() async {
    final prefs = await SharedPreferences.getInstance();
    notifPedidos = prefs.getBool('notifPedidos') ?? true;
    notifInsumos = prefs.getBool('notifInsumos') ?? true;
    acentoId = prefs.getString('acentoId') ?? 'verde';
    modoTemaId = prefs.getString('modoTemaId') ?? 'claro';
    idiomaId = prefs.getString('idiomaId'); // null si nunca se ha elegido
    notifyListeners();
  }

  Future<void> setNotif({bool? pedidos, bool? insumos}) async {
    final prefs = await SharedPreferences.getInstance();
    if (pedidos != null) {
      notifPedidos = pedidos;
      await prefs.setBool('notifPedidos', pedidos);
    }
    if (insumos != null) {
      notifInsumos = insumos;
      await prefs.setBool('notifInsumos', insumos);
    }
    notifyListeners();
  }

  Future<void> setAcento(String id) async {
    acentoId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('acentoId', id);
    notifyListeners();
  }

  Future<void> setModoTema(String id) async {
    modoTemaId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modoTemaId', id);
    notifyListeners();
  }

  // Changes the app language. Pass null to go back to the device language.
  // Stored as a GLOBAL preference (it does not depend on the business).
  Future<void> setIdioma(String? id) async {
    idiomaId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('idiomaId');
    } else {
      await prefs.setString('idiomaId', id);
    }
    guardarIdiomaUsuario();
    notifyListeners();
  }

  // Effective language (the chosen one, or the device one), clamped to supported.
  String get _idiomaEfectivo {
    final code = idiomaId ?? PlatformDispatcher.instance.locale.languageCode;
    const soportados = {'es', 'en', 'pt', 'fr'};
    return soportados.contains(code) ? code : 'en';
  }

  // Saves the user language in Firestore so push notifications can be
  // localised (the server cannot see the preference stored on the device).
  Future<void> guardarIdiomaUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('usuarios')
          .doc(uid)
          .update({'idioma': _idiomaEfectivo});
    } catch (_) {
      // The doc may not exist yet; it is written on joining a business.
    }
  }

  // Reauthenticates with the password and deletes the account and its data
  // (through the eliminarCuenta Cloud Function). If they are the owner, the
  // whole business goes. Returns null on success, or 'password' | 'error'.
  Future<String?> eliminarCuenta(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return 'error';
    try {
      final cred =
          EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'password';
      }
      return 'error';
    } catch (_) {
      return 'error';
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('eliminarCuenta').call();
      await FirebaseAuth.instance.signOut();
      return null;
    } catch (_) {
      return 'error';
    }
  }

  // --- Avisos en-app (respetan los interruptores) ---
  List<Pedido> get avisosPedidos {
    if (!notifPedidos) return [];
    return pedidos.where((p) {
      if (p.entregado || p.archivado) return false;
      final hoy = DateTime.now();
      final a = DateTime(hoy.year, hoy.month, hoy.day);
      final b = DateTime(
          p.fechaEntrega.year, p.fechaEntrega.month, p.fechaEntrega.day);
      return b.difference(a).inDays <= 1; // atrasados, hoy y mañana
    }).toList()
      ..sort((x, y) => x.fechaEntrega.compareTo(y.fechaEntrega));
  }

  List<Insumo> get avisosInsumos {
    if (!notifInsumos) return [];
    return insumos.where((i) => i.bajoMinimo).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  int get totalAvisos => avisosPedidos.length + avisosInsumos.length;

  // Shortcut: collection X INSIDE my business
  CollectionReference<Map<String, dynamic>> _col(String nombre) =>
      _db.collection('negocios').doc(_negocioId).collection(nombre);

  // --- Adding to the catalogue ---
  void agregarInsumo(Insumo insumo) {
    insumos.add(insumo);
    _col('insumos').doc(insumo.id).set(insumo.toMap());
    notifyListeners();
  }

  void agregarProducto(Producto producto) {
    productos.add(producto);
    _col('productos').doc(producto.id).set(producto.toMap());
    notifyListeners();
  }

  void agregarCliente(Cliente cliente) {
    clientes.add(cliente);
    notifyListeners();
  }

  // --- Registrar movimientos ---
  void registrarVenta(Producto producto, double cantidad) {
    final venta = Venta(
      fecha: DateTime.now(),
      descripcion: producto.nombre,
      cantidad: cantidad,
      precioUnitario: producto.precioVenta,
      costoUnitario: producto.costoProduccion(),
    );
    ventas.add(venta);
    producto.descontarStock(cantidad);

    _col('ventas').doc(venta.id).set(venta.toMap());
    final tocados = <String, Insumo>{};
    for (final ing in producto.receta) {
      tocados[ing.insumo.id] = ing.insumo;
    }
    for (final e in producto.empaque) {
      tocados[e.insumo.id] = e.insumo;
    }
    for (final ins in tocados.values) {
      _col('insumos').doc(ins.id).set(ins.toMap());
    }
    notifyListeners();
  }

  void registrarVentaManual(String descripcion, double valor) {
    final venta = Venta(
      fecha: DateTime.now(),
      descripcion: descripcion,
      cantidad: 1,
      precioUnitario: valor,
      costoUnitario: 0,
    );
    ventas.add(venta);
    _col('ventas').doc(venta.id).set(venta.toMap());
    notifyListeners();
  }

  void registrarGasto(Gasto gasto) {
    gastos.add(gasto);
    _col('gastos').doc(gasto.id).set(gasto.toMap());
    notifyListeners();
  }

  // Buying supplies: restocks (weighted average) and records the expense.
  void comprarInsumos({
    required List<LineaCompraInsumo> lineas,
    required String descripcion,
  }) {
    double totalGasto = 0;
    for (final l in lineas) {
      totalGasto += l.total;
      final insumo = l.insumo;
      final costoCompraUnit =
          l.cantidad > 0 ? l.total / l.cantidad : insumo.costoPorUnidad;
      // Weighted average; negative old stock does not weigh on the cost.
      final viejoPositivo = insumo.stockActual > 0 ? insumo.stockActual : 0.0;
      final denom = viejoPositivo + l.cantidad;
      final nuevoCosto = denom > 0
          ? (viejoPositivo * insumo.costoPorUnidad +
                  l.cantidad * costoCompraUnit) /
              denom
          : insumo.costoPorUnidad;
      insumo.stockActual = insumo.stockActual + l.cantidad;
      insumo.costoPorUnidad = nuevoCosto;
      _col('insumos').doc(insumo.id).set(insumo.toMap());
    }

    final gasto = Gasto(
      fecha: DateTime.now(),
      descripcion: descripcion.trim().isEmpty
          ? 'Compra de insumos'
          : descripcion.trim(),
      categoria: CategoriaGasto.insumos,
      monto: totalGasto,
    );
    gastos.add(gasto);
    _col('gastos').doc(gasto.id).set(gasto.toMap());
    notifyListeners();
  }

  void registrarPedido(Pedido pedido) {
    pedidos.add(pedido);
    _col('pedidos').doc(pedido.id).set(pedido.toMap());
    notifyListeners();
  }

  // Delivers the order: deducts supplies (per the recipe snapshot each
  // catalogue item kept) and records the income. Returns the supplies left
  // negative, so they can be flagged.
  List<String> marcarPedidoEntregado(Pedido pedido) {
    pedido.entregado = true;
    _col('pedidos').doc(pedido.id).set(pedido.toMap());

    // The same calculation the insufficient-stock warning uses when converting
    // a quote: one single source, so warning and deduction cannot disagree.
    final descuento = consumoDeInsumos(pedido);

    final negativos = <String>[];
    descuento.forEach((insumoId, cantidad) {
      final idx = insumos.indexWhere((i) => i.id == insumoId);
      if (idx == -1) return; // el insumo fue eliminado: no se descuenta
      final insumo = insumos[idx];
      insumo.stockActual -= cantidad;
      _col('insumos').doc(insumo.id).set(insumo.toMap());
      if (insumo.stockActual < 0) negativos.add(insumo.nombre);
    });

    // The order income is recorded as a sale of its own, so it shows up in
    // the history and stays independent of the order.
    final venta = Venta(
      fecha: DateTime.now(),
      descripcion: 'Pedido: ${pedido.cliente.nombre} — ${pedido.descripcion}',
      cantidad: 1,
      precioUnitario: pedido.precio,
      costoUnitario: pedido.costo,
    );
    ventas.add(venta);
    _col('ventas').doc(venta.id).set(venta.toMap());

    notifyListeners();
    return negativos;
  }

  void archivarPedido(Pedido pedido) {
    pedido.archivado = true;
    _col('pedidos').doc(pedido.id).set(pedido.toMap());
    notifyListeners();
  }

  void desarchivarPedido(Pedido pedido) {
    pedido.archivado = false;
    _col('pedidos').doc(pedido.id).set(pedido.toMap());
    notifyListeners();
  }

  // Adds several supplies at once (taken from the reference catalogue).
  void agregarInsumosDesdeCatalogo(List<Insumo> nuevos) {
    for (final ins in nuevos) {
      insumos.add(ins);
      _col('insumos').doc(ins.id).set(ins.toMap());
    }
    notifyListeners();
  }

  // --- Editar y eliminar insumos ---
  void editarInsumo(
    Insumo insumo, {
    required String nombre,
    required String unidad,
    required double costoPorUnidad,
    required double stockActual,
    required double stockMinimo,
    String? categoria,
    String? unidadCompra,
    double? cantidadCompra,
    double? precioPresentacion,
    String? proveedor,
    bool? especial,
  }) {
    insumo.nombre = nombre;
    insumo.unidad = unidad;
    insumo.costoPorUnidad = costoPorUnidad;
    insumo.stockActual = stockActual;
    insumo.stockMinimo = stockMinimo;
    if (categoria != null) insumo.categoria = categoria;
    if (unidadCompra != null) insumo.unidadCompra = unidadCompra;
    if (cantidadCompra != null) insumo.cantidadCompra = cantidadCompra;
    if (precioPresentacion != null) {
      insumo.precioPresentacion = precioPresentacion;
    }
    if (proveedor != null) insumo.proveedor = proveedor;
    if (especial != null) insumo.especial = especial;
    _col('insumos').doc(insumo.id).set(insumo.toMap());
    notifyListeners();
  }

  bool insumoEstaEnUso(Insumo insumo) {
    for (var producto in productos) {
      for (var ing in producto.receta) {
        if (ing.insumo == insumo) return true;
      }
    }
    return false;
  }

  void eliminarInsumo(Insumo insumo) {
    insumos.remove(insumo);
    _col('insumos').doc(insumo.id).delete();
    notifyListeners();
  }

  // --- Editar y eliminar gastos ---
  void editarGasto(
    Gasto gasto, {
    required String descripcion,
    required CategoriaGasto categoria,
    required double monto,
  }) {
    gasto.descripcion = descripcion;
    gasto.categoria = categoria;
    gasto.monto = monto;
    _col('gastos').doc(gasto.id).set(gasto.toMap());
    notifyListeners();
  }

  void eliminarGasto(Gasto gasto) {
    gastos.remove(gasto);
    _col('gastos').doc(gasto.id).delete();
    notifyListeners();
  }

  // --- Editar y eliminar ventas ---
  void editarVenta(
    Venta venta, {
    required String descripcion,
    required double cantidad,
    required double precioUnitario,
  }) {
    venta.descripcion = descripcion;
    venta.cantidad = cantidad;
    venta.precioUnitario = precioUnitario;
    _col('ventas').doc(venta.id).set(venta.toMap());
    notifyListeners();
  }

  void eliminarVenta(Venta venta) {
    ventas.remove(venta);
    _col('ventas').doc(venta.id).delete();
    notifyListeners();
  }

  // --- Editar y eliminar productos ---
  void editarProducto(
    Producto producto, {
    required String nombre,
    required String tipo,
    required double precioVenta,
    required List<IngredienteDeReceta> receta,
    List<IngredienteDeReceta>? empaque,
    double? rendimiento,
    double? mermaPct,
    double? minutosPrep,
    double? minutosHorno,
    String? metodoMargen,
    Object? margenPct = _sinCambio,
    bool? sinAzucar,
    double? unidadesMesEstimadas,
  }) {
    producto.nombre = nombre;
    producto.tipo = tipo;
    producto.precioVenta = precioVenta;
    producto.receta = receta;
    if (empaque != null) producto.empaque = empaque;
    if (rendimiento != null) producto.rendimiento = rendimiento;
    if (mermaPct != null) producto.mermaPct = mermaPct;
    if (minutosPrep != null) producto.minutosPrep = minutosPrep;
    if (minutosHorno != null) producto.minutosHorno = minutosHorno;
    if (metodoMargen != null) producto.metodoMargen = metodoMargen;
    if (!identical(margenPct, _sinCambio)) {
      producto.margenPct = margenPct as double?;
    }
    if (sinAzucar != null) producto.sinAzucar = sinAzucar;
    if (unidadesMesEstimadas != null) {
      producto.unidadesMesEstimadas = unidadesMesEstimadas;
    }
    _col('productos').doc(producto.id).set(producto.toMap());
    notifyListeners();
  }

  void eliminarProducto(Producto producto) {
    productos.remove(producto);
    _col('productos').doc(producto.id).delete();
    notifyListeners();
  }

  // --- Editar y eliminar pedidos ---
  void editarPedido(
    Pedido pedido, {
    required String clienteNombre,
    required String clienteTelefono,
    required String descripcion,
    required DateTime fechaEntrega,
    required double precio,
    required double costo,
    required List<ItemPedido> items,
    required double otroValor,
  }) {
    pedido.cliente.nombre = clienteNombre;
    pedido.cliente.telefono = clienteTelefono;
    pedido.descripcion = descripcion;
    pedido.fechaEntrega = fechaEntrega;
    pedido.precio = precio;
    pedido.costo = costo;
    pedido.items = items;
    pedido.otroValor = otroValor;
    _col('pedidos').doc(pedido.id).set(pedido.toMap());
    notifyListeners();
  }

  void eliminarPedido(Pedido pedido) {
    pedidos.remove(pedido);
    _col('pedidos').doc(pedido.id).delete();
    notifyListeners();
  }

  // --- Cotizaciones ---
  void guardarCotizacion(Cotizacion c) {
    final i = cotizaciones.indexWhere((x) => x.id == c.id);
    if (i == -1) {
      cotizaciones.add(c);
    } else {
      cotizaciones[i] = c;
    }
    _col('cotizaciones').doc(c.id).set(c.toMap());
    notifyListeners();
  }

  /// Creates the order matching an accepted quote and links the two. Returns
  /// the created order, or `null` if the quote had already generated one.
  ///
  /// **It does not touch inventory**: the deduction happens when the order is
  /// marked delivered, exactly as with any hand-made order.
  Pedido? convertirCotizacionEnPedido(
    Cotizacion cotizacion, {
    required String telefono,
    required DateTime fechaEntrega,
    required String descripcionFallback,
  }) {
    if (cotizacion.convertida) return null;
    final pedido = Pedido.desdeCotizacion(
      cotizacion,
      productos: productos,
      telefono: telefono,
      fechaEntrega: fechaEntrega,
      descripcionFallback: descripcionFallback,
    );
    registrarPedido(pedido);
    cotizacion.pedidoId = pedido.id;
    guardarCotizacion(cotizacion);
    return pedido;
  }

  void eliminarCotizacion(Cotizacion c) {
    cotizaciones.removeWhere((x) => x.id == c.id);
    _col('cotizaciones').doc(c.id).delete();
    notifyListeners();
  }

  void agregarReceta(GuiaReceta r) {
    recetas.add(r);
    _col('recetas').doc(r.id).set(r.toMap());
    notifyListeners();
  }

  void editarReceta(GuiaReceta r,
      {required String titulo,
      required List<String> ingredientes,
      required List<String> pasos}) {
    r.titulo = titulo;
    r.ingredientes = ingredientes;
    r.pasos = pasos;
    r.fecha = DateTime.now();
    _col('recetas').doc(r.id).set(r.toMap());
    notifyListeners();
  }

  void eliminarReceta(GuiaReceta r) {
    recetas.remove(r);
    _col('recetas').doc(r.id).delete();
    notifyListeners();
  }

  Future<void> agregarCatalogo({
    required String nombre,
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = 'negocios/$_negocioId/catalogos/${id}_$nombreArchivo';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();
    final cat = Catalogo(
        id: id, nombre: nombre, url: url, path: path, fecha: DateTime.now());
    await _col('catalogos').doc(id).set(cat.toMap());
    notifyListeners();
  }

  Future<void> eliminarCatalogo(Catalogo c) async {
    try {
      await _storage.ref(c.path).delete();
    } catch (_) {
      // If the file is already gone, delete the record anyway.
    }
    await _col('catalogos').doc(c.id).delete();
    catalogos.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  // --- Reportes ---
  double get ingresosTotales {
    double total = 0;
    for (Venta v in ventas) {
      total += v.total;
    }
    return total;
  }

  double get gastosTotales {
    double total = 0;
    for (Gasto g in gastos) {
      total += g.monto;
    }
    return total;
  }

  double get ganancia => ingresosTotales - gastosTotales;

  // --- Totals within a range (for the home panel) ---
  (DateTime, DateTime) _limitesRango(RangoTendencia rango) {
    final ahora = DateTime.now();
    final fin = DateTime(ahora.year, ahora.month + 1, 1);
    if (rango == RangoTendencia.mes) {
      return (DateTime(ahora.year, ahora.month, 1), fin);
    }
    final n = rango == RangoTendencia.tres
        ? 3
        : (rango == RangoTendencia.seis ? 6 : 12);
    return (DateTime(ahora.year, ahora.month - (n - 1), 1), fin);
  }

  double ingresosEnRango(RangoTendencia rango) {
    final (ini, fin) = _limitesRango(rango);
    double total = 0;
    for (final v in ventas) {
      if (!v.fecha.isBefore(ini) && v.fecha.isBefore(fin)) total += v.total;
    }
    return total;
  }

  double gastosEnRango(RangoTendencia rango) {
    final (ini, fin) = _limitesRango(rango);
    double total = 0;
    for (final g in gastos) {
      if (!g.fecha.isBefore(ini) && g.fecha.isBefore(fin)) total += g.monto;
    }
    return total;
  }

  double gananciaEnRango(RangoTendencia rango) =>
      ingresosEnRango(rango) - gastosEnRango(rango);
  
  // --- Top products (only names that exist in the catalogue) ---
  List<ProductoVendido> topProductos(int anio, int mes) {
    final nombres = productos.map((p) => p.nombre).toSet();
    final cant = <String, double>{};
    final tot = <String, double>{};
    for (final v in ventas) {
      if (v.fecha.year != anio || v.fecha.month != mes) continue;
      if (!nombres.contains(v.descripcion)) continue;
      cant[v.descripcion] = (cant[v.descripcion] ?? 0) + v.cantidad;
      tot[v.descripcion] = (tot[v.descripcion] ?? 0) + v.total;
    }
    final lista = cant.keys
        .map((n) => ProductoVendido(n, cant[n]!, tot[n]!))
        .toList()
      ..sort((a, b) => b.cantidad.compareTo(a.cantidad));
    return lista;
  }

  // Months (day 1) with at least one sale of a catalogue product.
  List<DateTime> mesesConVentasDeProductos() {
    final nombres = productos.map((p) => p.nombre).toSet();
    final vistos = <String>{};
    final lista = <DateTime>[];
    for (final v in ventas) {
      if (!nombres.contains(v.descripcion)) continue;
      final clave = '${v.fecha.year}-${v.fecha.month}';
      if (vistos.add(clave)) lista.add(DateTime(v.fecha.year, v.fecha.month, 1));
    }
    lista.sort((a, b) => b.compareTo(a)); // más reciente primero
    return lista;
  }

  // --- Analysis of every sale (products, manual ones and orders) ---
  // [etiquetaMes] lets the UI inject the localised month name (with intl,
  // for instance). Without it, the default Spanish abbreviations are used.
  AnalisisVentas analisisVentas({
    String Function(int year, int month)? etiquetaMes,
  }) {
    if (ventas.isEmpty) {
      return AnalisisVentas(
        numVentas: 0,
        totalVendido: 0,
        ticketPromedio: 0,
        porMes: const [],
        porDiaSemana: const [],
        fechasPico: const [],
      );
    }

    double total = 0;
    final porMesMapa = <String, double>{};
    final ordenMes = <String, DateTime>{};
    final porDia = <int, double>{};
    final porFecha = <DateTime, double>{};

    for (final v in ventas) {
      total += v.total;

      final claveMes = etiquetaMes != null
          ? etiquetaMes(v.fecha.year, v.fecha.month)
          : '${_mesesCorto[v.fecha.month - 1]} ${v.fecha.year}';
      porMesMapa[claveMes] = (porMesMapa[claveMes] ?? 0) + v.total;
      ordenMes[claveMes] = DateTime(v.fecha.year, v.fecha.month, 1);

      porDia[v.fecha.weekday] = (porDia[v.fecha.weekday] ?? 0) + v.total;

      final dia = DateTime(v.fecha.year, v.fecha.month, v.fecha.day);
      porFecha[dia] = (porFecha[dia] ?? 0) + v.total;
    }

    // Months in chronological order
    final porMes = porMesMapa.entries.toList()
      ..sort((a, b) => ordenMes[a.key]!.compareTo(ordenMes[b.key]!));

    // Weekday ordered Mon..Sun
    final porDiaSemana = [
      for (int d = 1; d <= 7; d++) MapEntry(d, porDia[d] ?? 0.0)
    ];

    // Peak dates: top 5 days by total
    final fechasPico = porFecha.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnalisisVentas(
      numVentas: ventas.length,
      totalVendido: total,
      ticketPromedio: total / ventas.length,
      porMes: porMes,
      porDiaSemana: porDiaSemana,
      fechasPico: fechasPico.take(5).toList(),
    );
  }

  List<ResumenMensual> get resumenPorMes {
    final mapa = <String, ResumenMensual>{};
    ResumenMensual delMes(int anio, int mes) {
      return mapa.putIfAbsent('$anio-$mes', () => ResumenMensual(anio, mes));
    }
    for (final v in ventas) {
      delMes(v.fecha.year, v.fecha.month).ingresos += v.total;
    }
    for (final g in gastos) {
      delMes(g.fecha.year, g.fecha.month).gastos += g.monto;
    }
    final lista = mapa.values.toList();
    lista.sort((a, b) {
      if (a.anio != b.anio) return a.anio.compareTo(b.anio);
      return a.mes.compareTo(b.mes);
    });
    return lista;
  }

  // [etiquetaMesCorto] lets the localised month abbreviation be injected.
  List<PuntoTendencia> tendenciaGanancia(
    RangoTendencia rango, {
    String Function(int year, int month)? etiquetaMesCorto,
  }) {
    final ahora = DateTime.now();

    // Profit over the interval [ini, fin)  (fin is exclusive)
    double gananciaEntre(DateTime ini, DateTime fin) {
      double ing = 0, gas = 0;
      for (final v in ventas) {
        if (!v.fecha.isBefore(ini) && v.fecha.isBefore(fin)) ing += v.total;
      }
      for (final g in gastos) {
        if (!g.fecha.isBefore(ini) && g.fecha.isBefore(fin)) gas += g.monto;
      }
      return ing - gas;
    }

    final puntos = <PuntoTendencia>[];

    if (rango == RangoTendencia.mes) {
      // Day by day, from the 1st until today
      for (int d = 1; d <= ahora.day; d++) {
        final ini = DateTime(ahora.year, ahora.month, d);
        final fin = DateTime(ahora.year, ahora.month, d + 1);
        puntos.add(PuntoTendencia('$d', gananciaEntre(ini, fin)));
      }
    } else {
      final n = rango == RangoTendencia.tres
          ? 3
          : (rango == RangoTendencia.seis ? 6 : 12);
      for (int i = n - 1; i >= 0; i--) {
        final ini = DateTime(ahora.year, ahora.month - i, 1);
        final fin = DateTime(ahora.year, ahora.month - i + 1, 1);
        final etq = etiquetaMesCorto != null
            ? etiquetaMesCorto(ini.year, ini.month)
            : _mesesCorto[ini.month - 1];
        puntos.add(PuntoTendencia(etq, gananciaEntre(ini, fin)));
      }
    }
    return puntos;
  }

  // --- Listening to the cloud live, inside the business ---
  void _escucharTodo() {
    if (_negocioId == null) return;       // sin negocio, no hay qué escuchar
    if (_suscripciones.isNotEmpty) return;

    // Performance at scale: sales and expenses are only listened to for the
    // last ~12 months (a rolling window). Older data is not loaded live.
    final ahora = DateTime.now();
    final corteHistorial =
        Timestamp.fromDate(DateTime(ahora.year - 1, ahora.month, 1));

    _suscripciones.add(
      _col('insumos').snapshots().listen((snap) {
        insumos = snap.docs.map((d) => Insumo.fromMap(d.id, d.data())).toList();
        _reconstruirProductos();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('productos').snapshots().listen((snap) {
        _productosRaw = snap.docs;
        _reconstruirProductos();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('gastos')
          .where('fecha', isGreaterThanOrEqualTo: corteHistorial)
          .snapshots()
          .listen((snap) {
        gastos = snap.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('ventas')
          .where('fecha', isGreaterThanOrEqualTo: corteHistorial)
          .snapshots()
          .listen((snap) {
        ventas = snap.docs.map((d) => Venta.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('pedidos').snapshots().listen((snap) {
        pedidos = snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('recetas').snapshots().listen((snap) {
        recetas =
            snap.docs.map((d) => GuiaReceta.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('catalogos').snapshots().listen((snap) {
        catalogos =
            snap.docs.map((d) => Catalogo.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
    _suscripciones.add(
      _col('cotizaciones').snapshots().listen((snap) {
        cotizaciones =
            snap.docs.map((d) => Cotizacion.fromMap(d.id, d.data())).toList();
        notifyListeners();
      }),
    );
  }

  void _detenerYLimpiar() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();
    insumos = [];
    productos = [];
    clientes = [];
    ventas = [];
    gastos = [];
    pedidos = [];
    recetas = [];
    catalogos = [];
    cotizaciones = [];
    perfilNombre = '';
    perfilCelular = '';
    perfilFotoUrl = '';
    rolUsuario = 'empleado';
    _productosRaw = [];
    notifyListeners();
  }

  // Uploads/replaces the business logo (owner only, per the rules)
  Future<void> guardarLogo(Uint8List bytes, String contentType) async {
    if (_negocioId == null || negocio == null) return;
    final ref = _storage.ref('negocios/$_negocioId/logo/imagen');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _db.collection('negocios').doc(_negocioId).set(
      {'logoUrl': url},
      SetOptions(merge: true),
    );
    negocio!.logoUrl = url;
    notifyListeners();
  }

  // Remove the profile photo (deletes the file and clears the URL)
  Future<void> eliminarFotoPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _storage.ref('usuarios/$uid/foto_perfil').delete();
    } catch (_) {
      // If the file is already gone, clear the URL anyway.
    }
    await _db.collection('usuarios').doc(uid).set(
      {'fotoUrl': ''},
      SetOptions(merge: true),
    );
    perfilFotoUrl = '';
    notifyListeners();
  }

  // Remove the company logo (owner only, per the rules)
  Future<void> eliminarLogo() async {
    if (_negocioId == null || negocio == null) return;
    try {
      await _storage.ref('negocios/$_negocioId/logo/imagen').delete();
    } catch (_) {
      // If the file is already gone, clear the URL anyway.
    }
    await _db.collection('negocios').doc(_negocioId).set(
      {'logoUrl': ''},
      SetOptions(merge: true),
    );
    negocio!.logoUrl = '';
    notifyListeners();
  }

  // Updates the company data (owner only, per the rules)
  Future<void> editarNegocioDatos({
    required String nombre,
    required String nit,
    required String correo,
    required String tel,
    required String ubicacion,
  }) async {
    if (_negocioId == null || negocio == null) return;
    await _db.collection('negocios').doc(_negocioId).set(
      {
        'nombre': nombre,
        'nit': nit,
        'correo': correo,
        'tel': tel,
        'ubicacion': ubicacion,
      },
      SetOptions(merge: true),
    );
    negocio!.nombre = nombre;
    negocio!.nit = nit;
    negocio!.correo = correo;
    negocio!.tel = tel;
    negocio!.ubicacion = ubicacion;
    notifyListeners();
  }

  // Costing configuration derived from the business.
  ConfigCosteo get configCosteo => ConfigCosteo.deNegocio(negocio);

  // Saves the costing settings (rate, energy, fixed costs, margins, VAT).
  Future<void> guardarAjustesCosteo({
    required double tarifaHora,
    required double costoEnergiaHora,
    required List<GastoFijo> gastosFijos,
    required double lotesMes,
    required String metodoMargen,
    required double margenPct,
    required double margenEspecialPct,
    required bool ivaAplica,
    required double ivaTasa,
  }) async {
    if (_negocioId == null || negocio == null) return;
    negocio!.tarifaHora = tarifaHora;
    negocio!.costoEnergiaHora = costoEnergiaHora;
    negocio!.gastosFijos = gastosFijos;
    negocio!.lotesMes = lotesMes;
    negocio!.metodoMargen = metodoMargen;
    negocio!.margenPct = margenPct;
    negocio!.margenEspecialPct = margenEspecialPct;
    negocio!.ivaAplica = ivaAplica;
    negocio!.ivaTasa = ivaTasa;
    await _db.collection('negocios').doc(_negocioId).set(
      {
        'tarifaHora': tarifaHora,
        'costoEnergiaHora': costoEnergiaHora,
        'gastosFijos': gastosFijos.map((g) => g.toMap()).toList(),
        'lotesMes': lotesMes,
        'metodoMargen': metodoMargen,
        'margenPct': margenPct,
        'margenEspecialPct': margenEspecialPct,
        'ivaAplica': ivaAplica,
        'ivaTasa': ivaTasa,
      },
      SetOptions(merge: true),
    );
    notifyListeners();
  }

  // Uploads/replaces the (private) profile photo and stores its URL
  Future<void> guardarFotoPerfil(Uint8List bytes, String contentType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _storage.ref('usuarios/$uid/foto_perfil');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _db.collection('usuarios').doc(uid).set(
      {'fotoUrl': url},
      SetOptions(merge: true),
    );
    perfilFotoUrl = url;
    notifyListeners();
  }

  void _reconstruirProductos() {
    productos = _productosRaw
        .map((d) => Producto.fromMap(d.id, d.data(), insumos))
        .toList();
  }
}