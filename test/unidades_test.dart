// Converting purchase units to a base unit (g / ml / each).
//
// This underpins everything else: if a kilo is not 1000 grams, the cost per
// unit comes out wrong, and with it every product suggested price.

import 'package:flutter_test/flutter_test.dart';
import 'package:reposteria_app/unidades.dart';

void main() {
  group('baseDeUnidad', () {
    test('it groups each unit into its magnitude', () {
      expect(baseDeUnidad('kg'), 'g');
      expect(baseDeUnidad('lb'), 'g');
      expect(baseDeUnidad('arroba'), 'g');
      expect(baseDeUnidad('oz'), 'g');
      expect(baseDeUnidad('l'), 'ml');
      expect(baseDeUnidad('doc'), 'unidad');
    });

    test('an unknown unit falls back to grams', () {
      expect(baseDeUnidad('cucharadita'), 'g');
      expect(baseDeUnidad(''), 'g');
    });
  });

  group('factorDeUnidad', () {
    test('the weight factors are the expected ones', () {
      expect(factorDeUnidad('g'), 1);
      expect(factorDeUnidad('kg'), 1000);
      expect(factorDeUnidad('lb'), 500);
      expect(factorDeUnidad('arroba'), 12500);
      expect(factorDeUnidad('oz'), closeTo(28.3495, 0.0001));
    });

    test('volume and count', () {
      expect(factorDeUnidad('ml'), 1);
      expect(factorDeUnidad('l'), 1000);
      expect(factorDeUnidad('unidad'), 1);
      expect(factorDeUnidad('doc'), 12);
    });

    test('an unknown unit does not multiply', () {
      expect(factorDeUnidad('pizca'), 1);
    });
  });

  group('costoBaseDesde', () {
    test('it splits the presentation price across its base units', () {
      // $4,000 per kilo -> $4 per gram.
      expect(costoBaseDesde(4000, 1, 'kg'), 4);
      // $3,000 per pound -> $6 per gram.
      expect(costoBaseDesde(3000, 1, 'lb'), 6);
      // $12,000 per dozen -> $1,000 each.
      expect(costoBaseDesde(12000, 1, 'doc'), 1000);
    });

    test('it takes the purchased quantity into account', () {
      // 2 kg for $8,000 -> $4 per gram.
      expect(costoBaseDesde(8000, 2, 'kg'), 4);
    });

    test('a zero quantity returns zero, not infinity', () {
      // Without this guard the cost would propagate as Infinity app-wide.
      expect(costoBaseDesde(4000, 0, 'kg'), 0);
      expect(costoBaseDesde(4000, -1, 'kg'), 0);
    });

    test('a zero price is valid and yields zero cost', () {
      expect(costoBaseDesde(0, 1, 'kg'), 0);
    });
  });

  group('cantidadBaseDesde', () {
    test('it converts the purchased quantity to the base unit', () {
      expect(cantidadBaseDesde(1, 'kg'), 1000);
      expect(cantidadBaseDesde(2.5, 'l'), 2500);
      expect(cantidadBaseDesde(1, 'arroba'), 12500);
      expect(cantidadBaseDesde(3, 'doc'), 36);
    });

    test('it accepts decimals', () {
      expect(cantidadBaseDesde(0.5, 'kg'), 500);
    });
  });

  group('rotBase', () {
    test('the count unit is abbreviated', () {
      expect(rotBase('unidad'), 'u');
      expect(rotBase('g'), 'g');
      expect(rotBase('ml'), 'ml');
    });

    test('an unknown base is shown as is', () {
      expect(rotBase('kg'), 'kg');
    });
  });

  group('round trip', () {
    test('cost x base quantity rebuilds the presentation price', () {
      for (final u in ['g', 'kg', 'lb', 'arroba', 'oz', 'ml', 'l', 'doc']) {
        final costo = costoBaseDesde(7500, 2, u);
        final cantidad = cantidadBaseDesde(2, u);
        expect(costo * cantidad, closeTo(7500, 0.0001), reason: 'unidad $u');
      }
    });
  });
}
