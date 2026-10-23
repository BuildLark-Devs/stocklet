import '../unidades.dart';

class Insumo {
  String id;
  String nombre;
  String categoria;
  // BASE unit of the supply: 'g' | 'ml' | 'unidad'. Cost and stock are both
  // expressed in this unit. Derived from the purchase unit.
  String unidad;
  double costoPorUnidad; // costo por unidad base (fuente de cálculo)
  double stockActual; // en unidad base
  double stockMinimo; // en unidad base

  // Purchase presentation (for display and re-editing). E.g. 1 kg at $4,000.
  String unidadCompra;
  double cantidadCompra;
  double precioPresentacion;

  String proveedor;
  bool especial; // insumo de la línea sin azúcar añadida

  Insumo({
    String? id,
    required this.nombre,
    this.categoria = 'Otros',
    required this.unidad,
    required this.costoPorUnidad,
    required this.stockActual,
    this.stockMinimo = 0,
    String? unidadCompra,
    double? cantidadCompra,
    double? precioPresentacion,
    this.proveedor = '',
    this.especial = false,
  })  : unidadCompra = unidadCompra ?? unidad,
        cantidadCompra = cantidadCompra ?? 1,
        precioPresentacion = precioPresentacion ?? costoPorUnidad,
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Builds a supply from a purchase presentation, converting to the base
  /// unit. E.g. 1 kg at $4,000 -> unit 'g', cost 4/g, stock 1000 g.
  factory Insumo.desdePresentacion({
    String? id,
    required String nombre,
    String categoria = 'Otros',
    required double cantidadCompra,
    required String unidadCompra,
    required double precioPresentacion,
    double? stockActual,
    double stockMinimo = 0,
    String proveedor = '',
    bool especial = false,
  }) {
    final base = baseDeUnidad(unidadCompra);
    final costo = costoBaseDesde(precioPresentacion, cantidadCompra, unidadCompra);
    return Insumo(
      id: id,
      nombre: nombre,
      categoria: categoria,
      unidad: base,
      costoPorUnidad: costo,
      stockActual:
          stockActual ?? cantidadBaseDesde(cantidadCompra, unidadCompra),
      stockMinimo: stockMinimo,
      unidadCompra: unidadCompra,
      cantidadCompra: cantidadCompra,
      precioPresentacion: precioPresentacion,
      proveedor: proveedor,
      especial: especial,
    );
  }

  // Below its minimum? (0 = no minimum, no warning)
  bool get bajoMinimo => stockMinimo > 0 && stockActual < stockMinimo;

  String get rotUnidadBase => rotBase(unidad);

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'unidad': unidad,
      'costoPorUnidad': costoPorUnidad,
      'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      'unidadCompra': unidadCompra,
      'cantidadCompra': cantidadCompra,
      'precioPresentacion': precioPresentacion,
      'proveedor': proveedor,
      'especial': especial,
    };
  }

  factory Insumo.fromMap(String id, Map<String, dynamic> map) {
    final unidad = map['unidad'] as String? ?? 'g';
    final costo = (map['costoPorUnidad'] as num?)?.toDouble() ?? 0;
    return Insumo(
      id: id,
      nombre: map['nombre'] as String,
      categoria: map['categoria'] as String? ?? 'Otros',
      unidad: unidad,
      costoPorUnidad: costo,
      stockActual: (map['stockActual'] as num?)?.toDouble() ?? 0,
      stockMinimo: (map['stockMinimo'] as num?)?.toDouble() ?? 0,
      // Compat: old supplies carry no presentation -> assume 1 base unit.
      unidadCompra: map['unidadCompra'] as String? ?? unidad,
      cantidadCompra: (map['cantidadCompra'] as num?)?.toDouble() ?? 1,
      precioPresentacion:
          (map['precioPresentacion'] as num?)?.toDouble() ?? costo,
      proveedor: map['proveedor'] as String? ?? '',
      especial: map['especial'] as bool? ?? false,
    );
  }
}
