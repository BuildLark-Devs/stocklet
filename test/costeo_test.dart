// The costing engine: from recipe to suggested price.
//
// The numbers that come out of here are Stocklet selling point. Each test
// pins one rule of the calculation down with hand-worked figures, so a
// refactor cannot quietly change what the business charges.

import 'package:flutter_test/flutter_test.dart';
import 'package:reposteria_app/costeo.dart';
import 'package:reposteria_app/models/insumo.dart';
import 'package:reposteria_app/models/ingrediente_de_receta.dart';
import 'package:reposteria_app/models/producto.dart';

// A supply costing `costo` per base unit.
Insumo insumo(String nombre, double costo) => Insumo(
      id: nombre,
      nombre: nombre,
      unidad: 'g',
      costoPorUnidad: costo,
      stockActual: 1000,
    );

IngredienteDeReceta ing(double costoUnitario, double cantidad) =>
    IngredienteDeReceta(insumo: insumo('x$costoUnitario', costoUnitario), cantidad: cantidad);

Producto producto({
  List<IngredienteDeReceta>? receta,
  List<IngredienteDeReceta>? empaque,
  double precioVenta = 0,
  double rendimiento = 1,
  double mermaPct = 0,
  double minutosPrep = 0,
  double minutosHorno = 0,
  String metodoMargen = '',
  double? margenPct,
  bool sinAzucar = false,
  double unidadesMesEstimadas = 0,
}) =>
    Producto(
      id: 'p',
      nombre: 'Producto',
      receta: receta ?? [ing(10, 100)], // $1.000 de materia prima por lote
      empaque: empaque,
      precioVenta: precioVenta,
      rendimiento: rendimiento,
      mermaPct: mermaPct,
      minutosPrep: minutosPrep,
      minutosHorno: minutosHorno,
      metodoMargen: metodoMargen,
      margenPct: margenPct,
      sinAzucar: sinAzucar,
      unidadesMesEstimadas: unidadesMesEstimadas,
    );

void main() {
  group('raw materials and yield', () {
    test('raw materials are the sum of the batch recipe', () {
      final r = costear(
        producto(receta: [ing(10, 100), ing(5, 200)]),
        const ConfigCosteo(),
      );
      expect(r.materiaPrima, 2000); // 10*100 + 5*200
    });

    test('the yield splits the batch across the units', () {
      final r = costear(producto(rendimiento: 10), const ConfigCosteo());
      expect(r.materiaPrima, 1000);
      expect(r.materiaUnidad, 100);
    });

    test('an invalid yield is treated as 1', () {
      for (final rend in [0.0, -5.0, 0.5]) {
        final r = costear(producto(rendimiento: rend), const ConfigCosteo());
        expect(r.materiaUnidad, 1000, reason: 'rendimiento $rend');
      }
    });
  });

  group('waste', () {
    test('waste raises the cost by division, not by addition', () {
      // Losing 10% does not add 10% but 11.1%: what stays usable is 90% of
      // what was bought.
      final r = costear(producto(mermaPct: 10), const ConfigCosteo());
      expect(r.conMerma, closeTo(1111.11, 0.01));
    });

    test('with no waste nothing changes', () {
      final r = costear(producto(mermaPct: 0), const ConfigCosteo());
      expect(r.conMerma, 1000);
    });

    test('waste is capped at 95% so we never divide by zero', () {
      final r = costear(producto(mermaPct: 100), const ConfigCosteo());
      // 1000 / 0.05. With a tolerance, because 1 - 95/100 is not exactly
      // 0.05 in floating point.
      expect(r.conMerma, closeTo(20000, 0.01));
      expect(r.conMerma.isFinite, isTrue);
    });

    test('negative waste is treated as zero', () {
      final r = costear(producto(mermaPct: -10), const ConfigCosteo());
      expect(r.conMerma, 1000);
    });
  });

  group('packaging, labour and energy', () {
    test('packaging is per unit, not per batch', () {
      final r = costear(
        producto(empaque: [ing(50, 1)], rendimiento: 10),
        const ConfigCosteo(),
      );
      // Packaging is not divided by the yield.
      expect(r.empaqueUnidad, 50);
    });

    test('labour is prorated by hour and by unit', () {
      final r = costear(
        producto(minutosPrep: 30, rendimiento: 10),
        const ConfigCosteo(tarifaHora: 20000),
      );
      // Half an hour at $20,000 = $10,000 per batch, across 10 units.
      expect(r.manoObraUnidad, 1000);
    });

    test('energy is prorated the same way as labour', () {
      final r = costear(
        producto(minutosHorno: 60, rendimiento: 4),
        const ConfigCosteo(costoEnergiaHora: 2000),
      );
      expect(r.energiaUnidad, 500);
    });
  });

  group('fixed costs: split per batch, not per unit', () {
    // $1,000,000 a month across 20 batches = $50,000 per preparation.
    const cfg = ConfigCosteo(gastosMes: 1000000, lotesMes: 20);

    test('a batch of one unit carries the whole batch', () {
      // A cake occupies oven and shift just like any other batch.
      final r = costear(producto(rendimiento: 1), cfg);
      expect(r.fijosUnidad, 50000);
    });

    test('a batch of 50 carries the same, split across the 50', () {
      final r = costear(producto(rendimiento: 50), cfg);
      expect(r.fijosUnidad, 1000); // 50000 / 50
    });

    test('the batch always carries the same, whatever it yields', () {
      // The model invariant: fijosUnidad × yield is constant.
      for (final rend in [1.0, 4.0, 12.0, 50.0, 200.0]) {
        final r = costear(producto(rendimiento: rend), cfg);
        expect(r.fijosUnidad * rend, closeTo(50000, 0.01),
            reason: 'rendimiento $rend');
      }
    });

    test('the month recovers exactly the fixed costs', () {
      // Without this equality the proration would be wrongly framed: 20
      // batches a month have to add up to the million, no more, no less.
      final r = costear(producto(rendimiento: 50), cfg);
      final recuperadoAlMes = r.fijosUnidad * 50 * cfg.lotesMes;
      expect(recuperadoAlMes, closeTo(cfg.gastosMes, 0.01));
    });

    test('an invalid yield carries the whole batch', () {
      // A yield of 0 is treated as 1, as with raw materials.
      final r = costear(producto(rendimiento: 0), cfg);
      expect(r.fijosUnidad, 50000);
    });

    test('with no batches per month there is no proration, and it warns', () {
      final r = costear(producto(), const ConfigCosteo(gastosMes: 1000000));
      expect(r.fijosUnidad, 0);
      expect(r.fijosIncompletos, isTrue);
    });

    test('with costs and batches filled in, no warning', () {
      expect(costear(producto(), cfg).fijosIncompletos, isFalse);
    });

    test('the variable cost excludes the fixed ones', () {
      final r = costear(
        producto(),
        const ConfigCosteo(gastosMes: 100000, lotesMes: 100),
      );
      expect(r.fijosUnidad, 1000);
      expect(r.costoUnidad - r.costoVariableUnidad, 1000);
    });
  });

  group('suggested price', () {
    test('markup method: the margin is added to the cost', () {
      final r = costear(
        producto(metodoMargen: 'markup', margenPct: 50),
        const ConfigCosteo(),
      );
      expect(r.costoUnidad, 1000);
      expect(r.precioSugerido, 1500);
    });

    test('sale method: the margin is on the final price', () {
      // 40% on sale with a cost of 1000 -> 1000/0.6 = 1666.67, not 1400.
      final r = costear(
        producto(metodoMargen: 'venta', margenPct: 40),
        const ConfigCosteo(),
      );
      expect(r.precioSugerido, closeTo(1666.67, 0.01));
      expect(r.margenSobreVenta, closeTo(40, 0.01));
    });

    test('the on-sale margin is capped at 95%', () {
      final r = costear(
        producto(metodoMargen: 'venta', margenPct: 99),
        const ConfigCosteo(),
      );
      expect(r.margen, 95);
      expect(r.precioSugerido, closeTo(20000, 0.01));
      expect(r.precioSugerido.isFinite, isTrue);
    });

    test('the product inherits the business method and margin', () {
      final r = costear(
        producto(),
        const ConfigCosteo(metodoMargen: 'markup', margenPct: 25),
      );
      expect(r.metodo, 'markup');
      expect(r.margen, 25);
      expect(r.precioSugerido, 1250);
    });

    test('the product margin overrides the business one', () {
      final r = costear(
        producto(margenPct: 10),
        const ConfigCosteo(metodoMargen: 'markup', margenPct: 25),
      );
      expect(r.margen, 10);
    });

    test('the sugar-free line uses the special margin', () {
      final r = costear(
        producto(sinAzucar: true),
        const ConfigCosteo(
            metodoMargen: 'markup', margenPct: 40, margenEspecialPct: 60),
      );
      expect(r.usaEspecial, isTrue);
      expect(r.margen, 60);
      expect(r.precioSugerido, 1600);
    });
  });

  group('price status', () {
    ResultadoCosteo conPrecio(double precio) => costear(
          producto(precioVenta: precio, metodoMargen: 'markup', margenPct: 50),
          const ConfigCosteo(),
        );
    // cost 1000, suggested 1500.

    test('with no price entered', () {
      expect(conPrecio(0).estado, EstadoPrecio.sinPrecio);
      expect(conPrecio(-100).estado, EstadoPrecio.sinPrecio);
    });

    test('below cost is a loss', () {
      expect(conPrecio(900).estado, EstadoPrecio.perdida);
    });

    test('between cost and suggested it is low', () {
      expect(conPrecio(1200).estado, EstadoPrecio.bajo);
    });

    test('at the suggested price or above it is fine', () {
      expect(conPrecio(1500).estado, EstadoPrecio.bien);
      expect(conPrecio(2000).estado, EstadoPrecio.bien);
    });

    test('there is half a peso of tolerance below the suggested price', () {
      // Keeps a hand-rounded price from showing up red.
      expect(conPrecio(1499.6).estado, EstadoPrecio.bien);
      expect(conPrecio(1499.4).estado, EstadoPrecio.bajo);
    });

    test('charging exactly cost is not a loss, but it is a low price', () {
      expect(conPrecio(1000).estado, EstadoPrecio.bajo);
    });
  });

  group('derived figures', () {
    test('profit and contribution', () {
      final r = costear(
        producto(metodoMargen: 'markup', margenPct: 50),
        const ConfigCosteo(gastosMes: 100000, lotesMes: 100),
      );
      // cost 1000 + fixed 1000 = 2000; suggested 3000.
      expect(r.costoUnidad, 2000);
      expect(r.precioSugerido, 3000);
      expect(r.utilidad, 1000);
      expect(r.contribucion, 2000); // 3000 - variable 1000
    });

    test('break-even is fixed costs divided by contribution', () {
      final r = costear(
        producto(metodoMargen: 'markup', margenPct: 50),
        const ConfigCosteo(gastosMes: 100000, lotesMes: 100),
      );
      expect(r.equilibrio, closeTo(50, 0.01)); // 100000 / 2000
    });

    test('with no positive contribution there is no break-even to compute', () {
      final r = costear(
        producto(metodoMargen: 'markup', margenPct: 0),
        const ConfigCosteo(gastosMes: 100000, lotesMes: 0),
      );
      expect(r.contribucion, 0);
      expect(r.equilibrio, isNull);
    });
  });

  group('supply price rise simulator', () {
    test('factorInsumos raises recipe and packaging, not labour', () {
      final p = producto(empaque: [ing(100, 1)], minutosPrep: 60);
      const cfg = ConfigCosteo(tarifaHora: 6000);

      final base = costear(p, cfg);
      final alza = costear(p, cfg, factorInsumos: 1.2);

      expect(alza.materiaPrima, closeTo(base.materiaPrima * 1.2, 0.01));
      expect(alza.empaqueUnidad, closeTo(base.empaqueUnidad * 1.2, 0.01));
      expect(alza.manoObraUnidad, base.manoObraUnidad);
    });
  });

  group('opportunity panel', () {
    test('it sums the monthly gap of the underpriced products', () {
      final barato = producto(
        precioVenta: 1000, // sugerido 1500 -> brecha 500
        metodoMargen: 'markup',
        margenPct: 50,
        unidadesMesEstimadas: 10,
      );
      final bienCobrado = producto(
        precioVenta: 1500,
        metodoMargen: 'markup',
        margenPct: 50,
        unidadesMesEstimadas: 10,
      );
      expect(
        dineroMesOportunidad([barato, bienCobrado], const ConfigCosteo()),
        closeTo(5000, 0.01),
      );
    });

    test('a product with no estimated units adds nothing', () {
      final p = producto(
        precioVenta: 1000,
        metodoMargen: 'markup',
        margenPct: 50,
      );
      expect(dineroMesOportunidad([p], const ConfigCosteo()), 0);
    });

    test('productosPorDebajo counts losses and low prices', () {
      final enPerdida = producto(
          precioVenta: 500, metodoMargen: 'markup', margenPct: 50);
      final bajo = producto(
          precioVenta: 1200, metodoMargen: 'markup', margenPct: 50);
      final bien = producto(
          precioVenta: 1500, metodoMargen: 'markup', margenPct: 50);
      expect(
        productosPorDebajo([enPerdida, bajo, bien], const ConfigCosteo()),
        2,
      );
    });
  });

  group('ConfigCosteo.deNegocio', () {
    test('with no business it returns the defaults', () {
      final cfg = ConfigCosteo.deNegocio(null);
      expect(cfg.margenPct, 40);
      expect(cfg.metodoMargen, 'venta');
      expect(cfg.fijosIncompletos, isTrue);
    });
  });
}
