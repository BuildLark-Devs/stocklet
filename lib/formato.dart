import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';

NumberFormat _formato =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

void configurarMoneda({
  required String moneda,
  required String idioma,
  required String pais,
}) {
  final c = CurrencyService().findByCode(moneda);
  final simbolo = c?.symbol ?? '\$';
  final decimales = c?.decimalDigits ?? 2;
  try {
    _formato = NumberFormat.currency(
      locale: '${idioma}_$pais', symbol: simbolo, decimalDigits: decimales);
  } catch (_) {
    // If that locale combination does not exist, fall back to a safe one
    _formato = NumberFormat.currency(
      locale: idioma, symbol: simbolo, decimalDigits: decimales);
  }
}

void reiniciarMoneda() {
  _formato =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
}

String pesos(num valor) => _formato.format(valor);

// ---------------------------------------------------------------------------
// Quantity and search helpers
// ---------------------------------------------------------------------------

/// Strips accents and lowercases, so searching ignores diacritics.
/// E.g. "Azúcar" and "azucar" both become "azucar".
String sinTildes(String s) {
  var r = s.toLowerCase();
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  for (var i = 0; i < con.length; i++) {
    r = r.replaceAll(con[i], sin[i]);
  }
  return r;
}

/// Shows a quantity with up to 2 decimals, without trailing zeros.
/// 2 -> "2", 2.5 -> "2.5", 2.25 -> "2.25".
String cantidadStr(num v) {
  final d = v.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  var s = d.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}

/// Converts text (comma or dot accepted) to a double. Empty/invalid -> 0.
double parseCantidad(String s) =>
    double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

/// Input formatter: allows a number with up to 2 decimals (comma or dot).
class Decimal2Formatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (RegExp(r'^\d*([.,]\d{0,2})?$').hasMatch(t)) return newValue;
    return oldValue;
  }
}

/// Like Decimal2Formatter but accepts a leading minus sign. Useful for fields
/// such as stock, which can go negative and has to be correctable.
class DecimalSignedFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty || t == '-') return newValue;
    if (RegExp(r'^-?\d*([.,]\d{0,2})?$').hasMatch(t)) return newValue;
    return oldValue;
  }
}
