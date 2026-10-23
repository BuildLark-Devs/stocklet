import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

// Possible states (keys; translated in the UI).
const List<String> kEstadosCotizacion = [
  'borrador',
  'enviada',
  'aceptada',
  'entregada',
  'rechazada',
];

class LineaCotizacion {
  String nombre;
  double precioUnitario;
  double cantidad;
  String? productoId;

  LineaCotizacion({
    required this.nombre,
    required this.precioUnitario,
    required this.cantidad,
    this.productoId,
  });

  double get subtotal => precioUnitario * cantidad;

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
        'productoId': productoId,
      };

  factory LineaCotizacion.fromMap(Map<String, dynamic> m) => LineaCotizacion(
        nombre: (m['nombre'] as String?) ?? '',
        precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
        cantidad: (m['cantidad'] as num?)?.toDouble() ?? 0,
        productoId: m['productoId'] as String?,
      );
}

class AdicionCotizacion {
  String nombre;
  double valor;
  AdicionCotizacion({required this.nombre, required this.valor});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'valor': valor};
  factory AdicionCotizacion.fromMap(Map<String, dynamic> m) =>
      AdicionCotizacion(
        nombre: (m['nombre'] as String?) ?? '',
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
      );
}

class Cotizacion {
  String id;
  String cliente;
  DateTime fecha;
  String estado;
  List<LineaCotizacion> lineas;
  List<AdicionCotizacion> adiciones;
  double domicilio;
  double descuento;
  bool aplicaIva;
  double tasaIva;
  String notas;
  /// Id of the order this quote generated. Empty = not converted yet.
  /// Once set it is never cleared: that is what prevents two orders.
  String pedidoId;

  Cotizacion({
    String? id,
    this.cliente = '',
    DateTime? fecha,
    this.estado = 'borrador',
    List<LineaCotizacion>? lineas,
    List<AdicionCotizacion>? adiciones,
    this.domicilio = 0,
    this.descuento = 0,
    this.aplicaIva = false,
    this.tasaIva = 19,
    this.notas = '',
    this.pedidoId = '',
  })  : fecha = fecha ?? DateTime.now(),
        lineas = lineas ?? [],
        adiciones = adiciones ?? [],
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  double get subtotal =>
      lineas.fold(0.0, (a, l) => a + l.subtotal) +
      adiciones.fold(0.0, (a, x) => a + x.valor);
  double get descuentoAplicado => min(descuento, subtotal);
  double get base => subtotal - descuentoAplicado + domicilio;
  double get iva => aplicaIva ? base * tasaIva / 100 : 0;
  double get total => base + iva;

  /// `true` if it already generated an order. This is what the screens read
  /// to decide whether to offer converting it.
  bool get convertida => pedidoId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'cliente': cliente,
        'fecha': fecha,
        'estado': estado,
        'lineas': lineas.map((l) => l.toMap()).toList(),
        'adiciones': adiciones.map((a) => a.toMap()).toList(),
        'domicilio': domicilio,
        'descuento': descuento,
        'aplicaIva': aplicaIva,
        'tasaIva': tasaIva,
        'notas': notas,
        'pedidoId': pedidoId,
      };

  factory Cotizacion.fromMap(String id, Map<String, dynamic> map) {
    final lineas = <LineaCotizacion>[];
    if (map['lineas'] is List) {
      for (final x in (map['lineas'] as List)) {
        lineas.add(LineaCotizacion.fromMap(x as Map<String, dynamic>));
      }
    }
    final adiciones = <AdicionCotizacion>[];
    if (map['adiciones'] is List) {
      for (final x in (map['adiciones'] as List)) {
        adiciones.add(AdicionCotizacion.fromMap(x as Map<String, dynamic>));
      }
    }
    return Cotizacion(
      id: id,
      cliente: (map['cliente'] as String?) ?? '',
      fecha: map['fecha'] is Timestamp
          ? (map['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      estado: (map['estado'] as String?) ?? 'borrador',
      lineas: lineas,
      adiciones: adiciones,
      domicilio: (map['domicilio'] as num?)?.toDouble() ?? 0,
      descuento: (map['descuento'] as num?)?.toDouble() ?? 0,
      aplicaIva: (map['aplicaIva'] as bool?) ?? false,
      tasaIva: (map['tasaIva'] as num?)?.toDouble() ?? 19,
      notas: (map['notas'] as String?) ?? '',
      // Missing = a quote from before this feature existed: not converted.
      pedidoId: (map['pedidoId'] as String?) ?? '',
    );
  }
}
