import 'package:cloud_firestore/cloud_firestore.dart';
import '../formato.dart';
import 'cliente.dart';
import 'cotizacion.dart';
import 'insumo.dart';
import 'item_pedido.dart';
import 'producto.dart';

class Pedido {
  String id;
  Cliente cliente;
  String descripcion;
  DateTime fechaPedido;
  DateTime fechaEntrega;
  double precio;
  double costo;
  bool entregado;
  bool archivado;
  List<ItemPedido> items;
  double otroValor;

  Pedido({
    String? id,
    required this.cliente,
    required this.descripcion,
    required this.fechaPedido,
    required this.fechaEntrega,
    required this.precio,
    required this.costo,
    this.entregado = false,
    this.archivado = false,
    this.items = const [],
    this.otroValor = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Builds the order matching an accepted quote.
  ///
  /// Pure: touches neither Firestore nor `DatosApp`, so it can be tested
  /// without an emulator.
  ///
  /// Two different truths live here. The **price** of each line is the quoted
  /// one and is frozen, because that is what was promised to the customer.
  /// The **cost and the recipe** are taken from the product as it stands
  /// today, because that is what the kitchen will actually consume.
  ///
  /// A line with no catalogue product — written by hand, or from a product
  /// already deleted — comes in with no cost and no recipe: on delivery it
  /// will not deduct stock.
  ///
  /// Guarantees that `precio == cotizacion.total`.
  factory Pedido.desdeCotizacion(
    Cotizacion cotizacion, {
    required List<Producto> productos,
    required String telefono,
    required DateTime fechaEntrega,
    required String descripcionFallback,
  }) {
    final items = <ItemPedido>[];
    for (final linea in cotizacion.lineas) {
      final pid = linea.productoId;
      Producto? prod;
      if (pid != null && pid.isNotEmpty) {
        for (final p in productos) {
          if (p.id == pid) {
            prod = p;
            break;
          }
        }
      }
      items.add(ItemPedido(
        nombre: linea.nombre,
        cantidad: linea.cantidad,
        precioUnitario: linea.precioUnitario,
        costoUnitario: prod?.costoProduccion() ?? 0,
        receta: prod?.consumoPorUnidad() ?? const [],
      ));
    }

    final precioItems = items.fold<double>(0, (s, i) => s + i.precioTotal);
    final costoTotal = items.fold<double>(0, (s, i) => s + i.costoTotal);
    final partes =
        items.map((i) => '${cantidadStr(i.cantidad)}x ${i.nombre}').toList();

    return Pedido(
      cliente: Cliente(nombre: cotizacion.cliente, telefono: telefono),
      descripcion: partes.isEmpty ? descripcionFallback : partes.join(', '),
      fechaPedido: DateTime.now(),
      fechaEntrega: fechaEntrega,
      precio: cotizacion.total,
      costo: costoTotal,
      items: items,
      // Add-ons + delivery − discount + VAT, collapsed into a single number
      // so the order total is exactly the quoted one. It goes negative if
      // the discount outweighs the extras.
      otroValor: cotizacion.total - precioItems,
    );
  }

  double get ganancia => precio - costo;

  Map<String, dynamic> toMap() {
    return {
      'cliente': cliente.toMap(),
      'descripcion': descripcion,
      'fechaPedido': fechaPedido,
      'fechaEntrega': fechaEntrega,
      'precio': precio,
      'costo': costo,
      'entregado': entregado,
      'archivado': archivado,
      'items': items.map((i) => i.toMap()).toList(),
      'otroValor': otroValor,
    };
  }

  factory Pedido.fromMap(String id, Map<String, dynamic> map) {
    return Pedido(
      id: id,
      cliente: Cliente.fromMap(map['cliente'] as Map<String, dynamic>),
      descripcion: map['descripcion'] as String,
      fechaPedido: (map['fechaPedido'] as Timestamp).toDate(),
      fechaEntrega: (map['fechaEntrega'] as Timestamp).toDate(),
      precio: (map['precio'] as num).toDouble(),
      costo: (map['costo'] as num).toDouble(),
      entregado: map['entregado'] as bool,
      archivado: (map['archivado'] as bool?) ?? false,
      items: ((map['items'] as List?) ?? const [])
          .map((i) => ItemPedido.fromMap(i as Map<String, dynamic>))
          .toList(),
      otroValor: (map['otroValor'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// How much of each supply the order consumes, per the recipe snapshot each
/// item kept when it was added. Pure.
///
/// Two places use it: the advance insufficient-stock warning when converting
/// a quote, and the real deduction in `DatosApp.marcarPedidoEntregado`. Being
/// one single function is what keeps warning and deduction from disagreeing.
Map<String, double> consumoDeInsumos(Pedido pedido) {
  final consumo = <String, double>{};
  for (final item in pedido.items) {
    for (final r in item.receta) {
      consumo[r.insumoId] = (consumo[r.insumoId] ?? 0) + r.cantidad * item.cantidad;
    }
  }
  return consumo;
}

/// Names of the supplies whose current stock does not cover what the order
/// would consume. An empty list = there is enough for everything. Pure.
///
/// A supply no longer in the catalogue is not reported: it is not deducted on
/// delivery either, so warning about it would only confuse.
List<String> faltantesDeInventario(Pedido pedido, List<Insumo> insumos) {
  final faltantes = <String>[];
  consumoDeInsumos(pedido).forEach((insumoId, cantidad) {
    final idx = insumos.indexWhere((i) => i.id == insumoId);
    if (idx == -1) return;
    if (insumos[idx].stockActual < cantidad) faltantes.add(insumos[idx].nombre);
  });
  return faltantes;
}
