import 'ingrediente_de_receta.dart';
import 'insumo.dart';
import 'item_pedido.dart';

// The list of types. To add a new one, just append it here.
const List<String> tiposDeProducto = [
  'Tortas',
  'Alfajores',
  'Brownies',
  'New York Cookies',
  'Otro',
];

class Producto {
  String id;
  String nombre;
  String tipo;

  // Ingredients per BATCH (the recipe yields `rendimiento` units).
  List<IngredienteDeReceta> receta;
  // Empaque por UNIDAD vendida.
  List<IngredienteDeReceta> empaque;

  double precioVenta; // lo que cobras hoy por unidad
  double rendimiento; // unidades que salen del lote
  double mermaPct; // % que se pierde/daña
  double minutosPrep; // minutos de trabajo por lote
  double minutosHorno; // minutos de horno por lote
  String metodoMargen; // '' = usar el del negocio | 'venta' | 'markup'
  double? margenPct; // null = usar el del negocio
  bool sinAzucar; // línea sin azúcar añadida (margen especial)
  double unidadesMesEstimadas; // opcional, para el panel de oportunidad

  Producto({
    String? id,
    required this.nombre,
    this.tipo = 'Otro',
    required this.receta,
    List<IngredienteDeReceta>? empaque,
    required this.precioVenta,
    this.rendimiento = 1,
    this.mermaPct = 0,
    this.minutosPrep = 0,
    this.minutosHorno = 0,
    this.metodoMargen = '',
    this.margenPct,
    this.sinAzucar = false,
    this.unidadesMesEstimadas = 0,
  })  : empaque = empaque ?? [],
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  double get _rend => rendimiento <= 0 ? 1 : rendimiento;

  // Raw materials for the batch (the sum of the ingredients).
  double materiaLote() {
    double total = 0;
    for (final ing in receta) {
      total += ing.costo;
    }
    return total;
  }

  double empaqueUnidad() {
    double total = 0;
    for (final e in empaque) {
      total += e.costo;
    }
    return total;
  }

  // Direct cost per unit: materials (with waste) prorated + packaging.
  // Excludes labour and fixed costs (the costing engine computes those).
  double costoProduccion() {
    final merma = mermaPct.clamp(0, 95).toDouble();
    final conMerma = materiaLote() / (1 - merma / 100);
    return conMerma / _rend + empaqueUnidad();
  }

  double get ganancia => precioVenta - costoProduccion();
  double get margen => precioVenta > 0 ? ganancia / precioVenta : 0;

  // Supply consumption per UNIT sold (materials prorated by yield +
  // packaging). Used as the recipe snapshot when adding to an order.
  List<RecetaItem> consumoPorUnidad() {
    return [
      for (final ing in receta)
        RecetaItem(insumoId: ing.insumo.id, cantidad: ing.cantidad / _rend),
      for (final e in empaque)
        RecetaItem(insumoId: e.insumo.id, cantidad: e.cantidad),
    ];
  }

  // Deducts from stock what selling `cantidadVendida` units consumes:
  // materials prorated by yield + packaging per unit.
  void descontarStock(double cantidadVendida) {
    for (final ing in receta) {
      ing.insumo.stockActual -= (ing.cantidad / _rend) * cantidadVendida;
    }
    for (final e in empaque) {
      e.insumo.stockActual -= e.cantidad * cantidadVendida;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'precioVenta': precioVenta,
      'receta': receta.map((ing) => ing.toMap()).toList(),
      'empaque': empaque.map((e) => e.toMap()).toList(),
      'rendimiento': rendimiento,
      'mermaPct': mermaPct,
      'minutosPrep': minutosPrep,
      'minutosHorno': minutosHorno,
      'metodoMargen': metodoMargen,
      'margenPct': margenPct,
      'sinAzucar': sinAzucar,
      'unidadesMesEstimadas': unidadesMesEstimadas,
    };
  }

  static List<IngredienteDeReceta> _leerLineas(
    dynamic lista,
    List<Insumo> insumosDisponibles,
  ) {
    final res = <IngredienteDeReceta>[];
    if (lista is! List) return res;
    for (final item in lista) {
      final ingMap = item as Map<String, dynamic>;
      Insumo? insumo;
      for (final ins in insumosDisponibles) {
        if (ins.id == ingMap['insumoId']) {
          insumo = ins;
          break;
        }
      }
      if (insumo == null) continue;
      res.add(IngredienteDeReceta(
        insumo: insumo,
        cantidad: (ingMap['cantidad'] as num).toDouble(),
      ));
    }
    return res;
  }

  factory Producto.fromMap(
    String id,
    Map<String, dynamic> map,
    List<Insumo> insumosDisponibles,
  ) {
    return Producto(
      id: id,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String? ?? 'Otro',
      precioVenta: (map['precioVenta'] as num).toDouble(),
      receta: _leerLineas(map['receta'], insumosDisponibles),
      empaque: _leerLineas(map['empaque'], insumosDisponibles),
      rendimiento: (map['rendimiento'] as num?)?.toDouble() ?? 1,
      mermaPct: (map['mermaPct'] as num?)?.toDouble() ?? 0,
      minutosPrep: (map['minutosPrep'] as num?)?.toDouble() ?? 0,
      minutosHorno: (map['minutosHorno'] as num?)?.toDouble() ?? 0,
      metodoMargen: map['metodoMargen'] as String? ?? '',
      margenPct: (map['margenPct'] as num?)?.toDouble(),
      sinAzucar: map['sinAzucar'] as bool? ?? false,
      unidadesMesEstimadas:
          (map['unidadesMesEstimadas'] as num?)?.toDouble() ?? 0,
    );
  }
}
