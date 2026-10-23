// Quantity formatting, accent-insensitive search and input formatters.
//
// These helpers decide how every number in the app looks. A change here
// shows up on every screen at once.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reposteria_app/formato.dart';

// Simulates typing `nuevo` into a field that held `viejo`, and returns what
// the formatter lets through.
String escribir(TextInputFormatter f, String viejo, String nuevo) {
  return f
      .formatEditUpdate(
        TextEditingValue(text: viejo),
        TextEditingValue(text: nuevo),
      )
      .text;
}

void main() {
  group('sinTildes', () {
    test('it strips accents and lowercases', () {
      expect(sinTildes('Azúcar'), 'azucar');
      expect(sinTildes('AZÚCAR'), 'azucar');
      expect(sinTildes('azucar'), 'azucar');
    });

    test('it covers accented vowels, n-tilde and c-cedilla', () {
      expect(sinTildes('áàäâã'), 'aaaaa');
      expect(sinTildes('éèëê'), 'eeee');
      expect(sinTildes('íìïî'), 'iiii');
      expect(sinTildes('óòöôõ'), 'ooooo');
      expect(sinTildes('úùüû'), 'uuuu');
      expect(sinTildes('ñ'), 'n');
      expect(sinTildes('ç'), 'c');
    });

    test('it allows searching however the word is spelled', () {
      // The case that prompted the helper: searching "limon" finds "Limón".
      expect(sinTildes('Limón').contains(sinTildes('limon')), isTrue);
      expect(sinTildes('Piña').contains(sinTildes('pina')), isTrue);
    });

    test('it leaves unaccented text alone', () {
      expect(sinTildes('Harina 000'), 'harina 000');
      expect(sinTildes(''), '');
    });
  });

  group('cantidadStr', () {
    test('an integer shows with no decimals', () {
      expect(cantidadStr(2), '2');
      expect(cantidadStr(2.0), '2');
      expect(cantidadStr(1000), '1000');
      expect(cantidadStr(0), '0');
    });

    test('decimals show without trailing zeros', () {
      expect(cantidadStr(2.5), '2.5');
      expect(cantidadStr(2.25), '2.25');
      expect(cantidadStr(2.50), '2.5');
      expect(cantidadStr(0.1), '0.1');
    });

    test('it rounds to two decimals', () {
      expect(cantidadStr(2.256), '2.26');
      expect(cantidadStr(2.254), '2.25');
    });

    test('negatives keep their sign', () {
      // Stock can go negative and has to be visible.
      expect(cantidadStr(-3), '-3');
      expect(cantidadStr(-2.5), '-2.5');
    });
  });

  group('parseCantidad', () {
    test('it accepts comma and dot as the decimal separator', () {
      expect(parseCantidad('2.5'), 2.5);
      expect(parseCantidad('2,5'), 2.5);
    });

    test('it ignores surrounding whitespace', () {
      expect(parseCantidad('  7  '), 7);
    });

    test('it accepts negatives', () {
      expect(parseCantidad('-4.5'), -4.5);
    });

    test('empty or unreadable is zero', () {
      expect(parseCantidad(''), 0);
      expect(parseCantidad('   '), 0);
      expect(parseCantidad('abc'), 0);
    });

    test('a thousands separator is NOT understood: it returns zero', () {
      // Documents the real limit: "1.234,56" is not read as 1234.56. The
      // input formatters stop it being typed, but if text from another
      // source is ever parsed, it has to be normalised first.
      expect(parseCantidad('1.234,56'), 0);
    });
  });

  group('Decimal2Formatter', () {
    final f = Decimal2Formatter();

    test('it allows integers and up to two decimals', () {
      expect(escribir(f, '', '5'), '5');
      expect(escribir(f, '5', '5.2'), '5.2');
      expect(escribir(f, '5.2', '5.25'), '5.25');
      expect(escribir(f, '5', '5,25'), '5,25');
    });

    test('permite vaciar el campo', () {
      expect(escribir(f, '5', ''), '');
    });

    test('it blocks the third decimal', () {
      expect(escribir(f, '5.25', '5.256'), '5.25');
    });

    test('it blocks letters and symbols', () {
      expect(escribir(f, '5', '5a'), '5');
      expect(escribir(f, '5', '5+'), '5');
    });

    test('it blocks the minus sign', () {
      // This is the difference from DecimalSignedFormatter.
      expect(escribir(f, '', '-'), '');
      expect(escribir(f, '', '-5'), '');
    });
  });

  group('DecimalSignedFormatter', () {
    final f = DecimalSignedFormatter();

    test('it allows a leading minus sign', () {
      expect(escribir(f, '', '-'), '-');
      expect(escribir(f, '-', '-5'), '-5');
      expect(escribir(f, '-5', '-5.25'), '-5.25');
    });

    test('it still accepts positives', () {
      expect(escribir(f, '', '5'), '5');
      expect(escribir(f, '5', '5,5'), '5,5');
    });

    test('permite vaciar el campo', () {
      expect(escribir(f, '-5', ''), '');
    });

    test('it blocks the third decimal and letters', () {
      expect(escribir(f, '-5.25', '-5.256'), '-5.25');
      expect(escribir(f, '-5', '-5x'), '-5');
    });

    test('the sign only goes at the start', () {
      expect(escribir(f, '5', '5-'), '5');
    });
  });

  group('currency', () {
    setUp(reiniciarMoneda);
    tearDown(reiniciarMoneda);

    test('by default it formats Colombian pesos with no decimals', () {
      expect(pesos(1500), contains('1.500'));
      expect(pesos(1500), isNot(contains(',00')));
    });

    test('configurarMoneda changes the symbol and the decimals', () {
      configurarMoneda(moneda: 'USD', idioma: 'en', pais: 'US');
      final s = pesos(1500.5);
      expect(s, contains('1,500.5'));
      expect(s, contains(r'$'));
    });

    test('a nonexistent locale does not break: it falls back to a safe one', () {
      // The language_country combination may not exist in intl; the helper
      // retries with the language alone instead of throwing.
      expect(() => configurarMoneda(moneda: 'COP', idioma: 'es', pais: 'ZZ'),
          returnsNormally);
      expect(() => pesos(1000), returnsNormally);
    });

    test('reiniciarMoneda returns to the default', () {
      configurarMoneda(moneda: 'USD', idioma: 'en', pais: 'US');
      reiniciarMoneda();
      expect(pesos(1500), contains('1.500'));
    });
  });
}
