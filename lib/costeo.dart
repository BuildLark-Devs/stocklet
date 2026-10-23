import 'dart:math';
import 'models/producto.dart';
import 'models/negocio.dart';

// Costing configuration (comes from the business).
class ConfigCosteo {
  final double tarifaHora;
  final double costoEnergiaHora;
  final double gastosMes;
  final double lotesMes;
  final String metodoMargen; // 'venta' | 'markup'
  final double margenPct;
  final double margenEspecialPct;

  const ConfigCosteo({
    this.tarifaHora = 0,
    this.costoEnergiaHora = 0,
    this.gastosMes = 0,
    this.lotesMes = 0,
    this.metodoMargen = 'venta',
    this.margenPct = 40,
    this.margenEspecialPct = 50,
  });

  factory ConfigCosteo.deNegocio(Negocio? n) {
    if (n == null) return const ConfigCosteo();
    return ConfigCosteo(
      tarifaHora: n.tarifaHora,
      costoEnergiaHora: n.costoEnergiaHora,
      gastosMes: n.gastosFijosMes,
      lotesMes: n.lotesMes,
      metodoMargen: n.metodoMargen,
      margenPct: n.margenPct,
      margenEspecialPct: n.margenEspecialPct,
    );
  }

  bool get fijosIncompletos => !(gastosMes > 0 && lotesMes > 0);
}

enum EstadoPrecio { sinPrecio, perdida, bajo, bien }

class ResultadoCosteo {
  final double materiaPrima;
  final double conMerma;
  final double materiaUnidad;
  final double empaqueUnidad;
  final double manoObraUnidad;
  final double energiaUnidad;
  final double fijosUnidad;
  final double costoUnidad;
  final double costoVariableUnidad;
  final String metodo;
  final double margen;
  final double precioSugerido;
  final double utilidad;
  final double margenSobreVenta;
  final double contribucion;
  final double? equilibrio;
  final bool fijosIncompletos;
  final bool usaEspecial;
  final double precioActual;
  final EstadoPrecio estado;

  const ResultadoCosteo({
    required this.materiaPrima,
    required this.conMerma,
    required this.materiaUnidad,
    required this.empaqueUnidad,
    required this.manoObraUnidad,
    required this.energiaUnidad,
    required this.fijosUnidad,
    required this.costoUnidad,
    required this.costoVariableUnidad,
    required this.metodo,
    required this.margen,
    required this.precioSugerido,
    required this.utilidad,
    required this.margenSobreVenta,
    required this.contribucion,
    required this.equilibrio,
    required this.fijosIncompletos,
    required this.usaEspecial,
    required this.precioActual,
    required this.estado,
  });
}

// Monthly money left on the table: for every product priced below its
// suggested price, the per-unit gap × estimated units/month.
double dineroMesOportunidad(List<Producto> productos, ConfigCosteo cfg) {
  double total = 0;
  for (final p in productos) {
    if (p.unidadesMesEstimadas <= 0) continue;
    final r = costear(p, cfg);
    if (r.estado == EstadoPrecio.bajo || r.estado == EstadoPrecio.perdida) {
      final brecha = r.precioSugerido - p.precioVenta;
      if (brecha > 0) total += brecha * p.unidadesMesEstimadas;
    }
  }
  return total;
}

int productosPorDebajo(List<Producto> productos, ConfigCosteo cfg) {
  var n = 0;
  for (final p in productos) {
    final e = costear(p, cfg).estado;
    if (e == EstadoPrecio.bajo || e == EstadoPrecio.perdida) n++;
  }
  return n;
}

ResultadoCosteo costear(Producto p, ConfigCosteo cfg,
    {double factorInsumos = 1.0}) {
  final rend = max(1.0, p.rendimiento);

  // 1. Raw materials (per batch). factorInsumos simulates a supply price rise.
  double materiaPrima = 0;
  for (final ing in p.receta) {
    materiaPrima += ing.costo * factorInsumos;
  }

  // 2. Waste (a division: losing 10% raises the cost by 11.1%)
  final mermaPct = p.mermaPct.clamp(0, 95).toDouble();
  final conMerma = materiaPrima / (1 - mermaPct / 100);
  final materiaUnidad = conMerma / rend;

  // 3. Empaque (por unidad)
  double empaqueUnidad = 0;
  for (final e in p.empaque) {
    empaqueUnidad += e.costo * factorInsumos;
  }

  // 4. Labour and 5. energy (per unit)
  final manoObraUnidad = (p.minutosPrep / 60) * cfg.tarifaHora / rend;
  final energiaUnidad = (p.minutosHorno / 60) * cfg.costoEnergiaHora / rend;

  // 6. Fixed costs prorated PER BATCH, not per unit.
  // Every preparation carries an equal share of the month's costs, and that
  // share is split across the units it yields. So a cake (a batch of one)
  // carries a whole batch, and a batch of 50 cookies carries the same amount
  // split across the 50: occupying the oven costs the same either way.
  final fijosLote = cfg.lotesMes > 0 ? cfg.gastosMes / cfg.lotesMes : 0.0;
  final fijosUnidad = fijosLote / rend;

  // 7. Costo total por unidad
  final costoUnidad = materiaUnidad +
      empaqueUnidad +
      manoObraUnidad +
      energiaUnidad +
      fijosUnidad;
  final costoVariableUnidad = costoUnidad - fijosUnidad;

  // 8. Precio sugerido
  final usaEspecial = p.sinAzucar;
  final metodo = p.metodoMargen.isNotEmpty ? p.metodoMargen : cfg.metodoMargen;
  double margen = p.margenPct ??
      (usaEspecial ? cfg.margenEspecialPct : cfg.margenPct);
  if (metodo == 'venta') margen = min(margen, 95);
  final precioSugerido = metodo == 'markup'
      ? costoUnidad * (1 + margen / 100)
      : costoUnidad / (1 - margen / 100);

  // 9. Derivados
  final utilidad = precioSugerido - costoUnidad;
  final margenSobreVenta =
      precioSugerido > 0 ? utilidad / precioSugerido * 100 : 0.0;
  final contribucion = precioSugerido - costoVariableUnidad;
  final equilibrio =
      contribucion > 0 ? cfg.gastosMes / contribucion : null;

  final precioActual = p.precioVenta;
  EstadoPrecio estado;
  if (precioActual <= 0) {
    estado = EstadoPrecio.sinPrecio;
  } else if (precioActual < costoUnidad) {
    estado = EstadoPrecio.perdida;
  } else if (precioActual < precioSugerido - 0.5) {
    estado = EstadoPrecio.bajo;
  } else {
    estado = EstadoPrecio.bien;
  }

  return ResultadoCosteo(
    materiaPrima: materiaPrima,
    conMerma: conMerma,
    materiaUnidad: materiaUnidad,
    empaqueUnidad: empaqueUnidad,
    manoObraUnidad: manoObraUnidad,
    energiaUnidad: energiaUnidad,
    fijosUnidad: fijosUnidad,
    costoUnidad: costoUnidad,
    costoVariableUnidad: costoVariableUnidad,
    metodo: metodo,
    margen: margen,
    precioSugerido: precioSugerido,
    utilidad: utilidad,
    margenSobreVenta: margenSobreVenta,
    contribucion: contribucion,
    equilibrio: equilibrio,
    fijosIncompletos: cfg.fijosIncompletos,
    usaEspecial: usaEspecial,
    precioActual: precioActual,
    estado: estado,
  );
}
