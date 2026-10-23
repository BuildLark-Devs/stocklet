// Converting an accepted quote into an order.
//
// What is pinned down here is what the customer ends up paying and what the
// kitchen ends up consuming. A mistake in either one goes unnoticed until it
// has already cost money.

import 'package:flutter_test/flutter_test.dart';
import 'package:reposteria_app/models/cotizacion.dart';
import 'package:reposteria_app/models/ingrediente_de_receta.dart';
import 'package:reposteria_app/models/insumo.dart';
import 'package:reposteria_app/models/pedido.dart';
import 'package:reposteria_app/models/producto.dart';

Insumo insumo(String id, double costo, {double stock = 1000}) => Insumo(
      id: id,
      nombre: id,
      unidad: 'g',
      costoPorUnidad: costo,
      stockActual: stock,
    );

/// A cake: $1,000 of raw materials per batch, yields 1, sells for 50k.
Producto torta({double rendimiento = 1}) => Producto(
      id: 'torta',
      nombre: 'Torta',
      receta: [IngredienteDeReceta(insumo: insumo('harina', 10), cantidad: 100)],
      precioVenta: 50000,
      rendimiento: rendimiento,
    );

LineaCotizacion linea(String nombre, double precio, double cantidad,
        {String? productoId}) =>
    LineaCotizacion(
      nombre: nombre,
      precioUnitario: precio,
      cantidad: cantidad,
      productoId: productoId,
    );

Cotizacion cotizacion({
  List<LineaCotizacion>? lineas,
  List<AdicionCotizacion>? adiciones,
  double domicilio = 0,
  double descuento = 0,
  bool aplicaIva = false,
  double tasaIva = 19,
}) =>
    Cotizacion(
      id: 'c1',
      cliente: 'Ana',
      estado: 'aceptada',
      lineas: lineas ?? [linea('Torta', 50000, 1, productoId: 'torta')],
      adiciones: adiciones,
      domicilio: domicilio,
      descuento: descuento,
      aplicaIva: aplicaIva,
      tasaIva: tasaIva,
    );

Pedido convertir(Cotizacion c, {List<Producto>? productos}) =>
    Pedido.desdeCotizacion(
      c,
      productos: productos ?? [torta()],
      telefono: '3110000000',
      fechaEntrega: DateTime(2026, 10, 1),
      descripcionFallback: 'Pedido',
    );

void main() {
  group('the money adds up', () {
    test('the order total is exactly the quote total', () {
      final c = cotizacion();
      expect(convertir(c).precio, c.total);
    });

    test('it adds up with add-ons, delivery, discount and VAT at once', () {
      final c = cotizacion(
        lineas: [linea('Torta', 50000, 2, productoId: 'torta')],
        adiciones: [AdicionCotizacion(nombre: 'Vela', valor: 3000)],
        domicilio: 8000,
        descuento: 5000,
        aplicaIva: true,
      );
      final p = convertir(c);
      expect(p.precio, closeTo(c.total, 0.001));
      // The items only carry the lines; everything else goes in the adjustment.
      expect(p.precio - p.otroValor, closeTo(100000, 0.001));
    });

    test('the adjustment goes negative if the discount outweighs the extras',
        () {
      final c = cotizacion(
        lineas: [linea('Torta', 50000, 1, productoId: 'torta')],
        descuento: 10000,
      );
      final p = convertir(c);
      expect(p.otroValor, closeTo(-10000, 0.001));
      expect(p.precio, closeTo(c.total, 0.001)); // sigue cuadrando
    });

    test('the order cost is the sum of its items costs', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 3, productoId: 'torta'),
      ]);
      // The cake costs $1,000 to make; 3 units = $3,000.
      expect(convertir(c).costo, closeTo(3000, 0.001));
    });
  });

  group('the quoted price rules', () {
    test('it is kept even if the product price went up', () {
      // It was quoted at 40,000; today the catalogue says 50,000.
      final c = cotizacion(
        lineas: [linea('Torta', 40000, 1, productoId: 'torta')],
      );
      final p = convertir(c);
      expect(p.items.first.precioUnitario, 40000);
      expect(p.precio, 40000);
    });

    test('but cost and recipe come from the product as it is today', () {
      final c = cotizacion(
        lineas: [linea('Torta', 40000, 1, productoId: 'torta')],
      );
      final p = convertir(c);
      expect(p.items.first.costoUnitario, closeTo(1000, 0.001));
      expect(p.items.first.receta, isNotEmpty);
    });
  });

  group('what deducts stock and what does not', () {
    test('a line with a product carries a recipe snapshot', () {
      final p = convertir(cotizacion());
      expect(p.items.first.receta.single.insumoId, 'harina');
      expect(p.items.first.receta.single.cantidad, 100);
    });

    test('the recipe is prorated by the product yield', () {
      // 100 g of flour per batch, and the batch yields 50 units.
      final p = convertir(cotizacion(),
          productos: [torta(rendimiento: 50)]);
      expect(p.items.first.receta.single.cantidad, closeTo(2, 0.001));
    });

    test('a hand-written line carries no cost and no recipe', () {
      final c = cotizacion(lineas: [linea('Decoración especial', 20000, 1)]);
      final p = convertir(c);
      expect(p.items.first.costoUnitario, 0);
      expect(p.items.first.receta, isEmpty);
    });

    test('a product deleted from the catalogue degrades, it does not blow up', () {
      final c = cotizacion(
        lineas: [linea('Torta', 50000, 1, productoId: 'ya-no-existe')],
      );
      final p = convertir(c);
      expect(p.items.first.nombre, 'Torta');
      expect(p.items.first.precioUnitario, 50000); // se respeta lo cotizado
      expect(p.items.first.costoUnitario, 0);
      expect(p.items.first.receta, isEmpty);
    });

    test('mixed lines: each one resolves on its own', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 1, productoId: 'torta'),
        linea('Montaje', 15000, 1),
      ]);
      final p = convertir(c);
      expect(p.items[0].receta, isNotEmpty);
      expect(p.items[1].receta, isEmpty);
    });
  });

  group('the rest of the order', () {
    test('it carries the quote customer and the captured phone', () {
      final p = convertir(cotizacion());
      expect(p.cliente.nombre, 'Ana');
      expect(p.cliente.telefono, '3110000000');
    });

    test('it is born neither delivered nor archived', () {
      final p = convertir(cotizacion());
      expect(p.entregado, isFalse);
      expect(p.archivado, isFalse);
    });

    test('the description summarises the lines', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 2, productoId: 'torta'),
        linea('Galletas', 2000, 12),
      ]);
      expect(convertir(c).descripcion, '2x Torta, 12x Galletas');
    });

    test('a quote with no lines falls back to the placeholder text', () {
      final c = cotizacion(lineas: []);
      expect(convertir(c).descripcion, 'Pedido');
    });

    test('it honours the given delivery date', () {
      expect(convertir(cotizacion()).fechaEntrega, DateTime(2026, 10, 1));
    });
  });

  group('supply consumption', () {
    test('it sums recipe by quantity, grouping per supply', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 3, productoId: 'torta'),
      ]);
      // 100 g per unit × 3 units.
      expect(consumoDeInsumos(convertir(c)), {'harina': 300.0});
    });

    test('items with no recipe contribute nothing', () {
      final c = cotizacion(lineas: [linea('Montaje', 15000, 5)]);
      expect(consumoDeInsumos(convertir(c)), isEmpty);
    });

    test('it accumulates the same supply used by several lines', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 2, productoId: 'torta'),
        linea('Torta grande', 80000, 1, productoId: 'torta'),
      ]);
      expect(consumoDeInsumos(convertir(c)), {'harina': 300.0});
    });
  });

  group('stock shortfalls', () {
    test('an empty list when there is enough', () {
      final p = convertir(cotizacion());
      expect(faltantesDeInventario(p, [insumo('harina', 10, stock: 500)]),
          isEmpty);
    });

    test('it names the supply that falls short', () {
      final c = cotizacion(lineas: [
        linea('Torta', 50000, 10, productoId: 'torta'), // consume 1000 g
      ]);
      final p = convertir(c);
      final faltan =
          faltantesDeInventario(p, [insumo('harina', 10, stock: 400)]);
      expect(faltan, ['harina']);
    });

    test('exactly enough does not count as a shortfall', () {
      final p = convertir(cotizacion()); // consume 100 g
      expect(faltantesDeInventario(p, [insumo('harina', 10, stock: 100)]),
          isEmpty);
    });

    test('a supply that no longer exists is not reported', () {
      // It is not deducted on delivery either, so warning about it would
      // only confuse.
      final p = convertir(cotizacion());
      expect(faltantesDeInventario(p, []), isEmpty);
    });

    test('negative stock also counts as a shortfall', () {
      final p = convertir(cotizacion());
      expect(faltantesDeInventario(p, [insumo('harina', 10, stock: -5)]),
          ['harina']);
    });
  });
}
