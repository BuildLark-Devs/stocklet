import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../models/cotizacion.dart';
import '../models/negocio.dart';
import '../formato.dart';

String estadoCotizacionTexto(AppLocalizations t, String estado) {
  switch (estado) {
    case 'enviada':
      return t.estCotEnviada;
    case 'aceptada':
      return t.estCotAceptada;
    case 'entregada':
      return t.estCotEntregada;
    case 'rechazada':
      return t.estCotRechazada;
    default:
      return t.estCotBorrador;
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

// Texto plano para WhatsApp / copiar.
String textoCotizacion(Cotizacion c, Negocio? n, AppLocalizations t) {
  final L = <String>[];
  if (n != null && n.nombre.isNotEmpty) L.add(n.nombre);
  L.add('${t.cotizacionTitulo} ${_fecha(c.fecha)}');
  if (c.cliente.isNotEmpty) L.add('${t.cotizaPara} ${c.cliente}');
  L.add('');
  for (final l in c.lineas) {
    L.add('- ${l.nombre} x${cantidadStr(l.cantidad)}   ${pesos(l.subtotal)}');
  }
  for (final a in c.adiciones) {
    if (a.nombre.isNotEmpty || a.valor != 0) {
      L.add(
          '- ${a.nombre.isEmpty ? t.cotizaAdicion : a.nombre}   ${pesos(a.valor)}');
    }
  }
  L.add('');
  L.add('${t.cotizaSubtotal}: ${pesos(c.subtotal)}');
  if (c.descuentoAplicado > 0) {
    L.add('${t.cotizaDescuento}: -${pesos(c.descuentoAplicado)}');
  }
  if (c.domicilio > 0) L.add('${t.cotizaDomicilio}: ${pesos(c.domicilio)}');
  if (c.aplicaIva) {
    L.add('${t.costeoIva} ${cantidadStr(c.tasaIva)}%: ${pesos(c.iva)}');
  }
  L.add('${t.cotizaTotal.toUpperCase()}: ${pesos(c.total)}');
  if (c.notas.isNotEmpty) {
    L.add('');
    L.add(c.notas);
  }
  if (n != null && n.tel.isNotEmpty) {
    L.add('');
    L.add(n.tel);
  }
  return L.join('\n');
}

// Builds the PDF and opens the system print/share dialog.
Future<void> imprimirCotizacion(
    Cotizacion c, Negocio? n, AppLocalizations t) async {
  final doc = pw.Document();
  const verde = PdfColor.fromInt(0xFF0E9F6E);

  pw.Widget filaTotal(String etq, String val, {bool fuerte = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(etq,
                style: pw.TextStyle(
                    fontWeight:
                        fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: fuerte ? 13 : 11)),
            pw.Text(val,
                style: pw.TextStyle(
                    fontWeight:
                        fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: fuerte ? 13 : 11)),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        n?.nombre.isNotEmpty == true
                            ? n!.nombre
                            : t.cotizacionTitulo,
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: verde)),
                    if (n != null && n.tel.isNotEmpty)
                      pw.Text(n.tel, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(t.cotizacionTitulo,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_fecha(c.fecha),
                        style: const pw.TextStyle(fontSize: 10)),
                    if (c.cliente.isNotEmpty)
                      pw.Text(c.cliente,
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: verde),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: [
                t.cotizaProducto,
                t.cotizaCantidad,
                t.cotizaValorUnitario,
                t.cotizaSubtotal
              ],
              data: [
                for (final l in c.lineas)
                  [
                    l.nombre,
                    cantidadStr(l.cantidad),
                    pesos(l.precioUnitario),
                    pesos(l.subtotal)
                  ],
                for (final a in c.adiciones)
                  if (a.nombre.isNotEmpty || a.valor != 0)
                    [
                      a.nombre.isEmpty ? t.cotizaAdicion : a.nombre,
                      '1',
                      pesos(a.valor),
                      pesos(a.valor)
                    ],
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    filaTotal(t.cotizaSubtotal, pesos(c.subtotal)),
                    if (c.descuentoAplicado > 0)
                      filaTotal(
                          t.cotizaDescuento, '-${pesos(c.descuentoAplicado)}'),
                    if (c.domicilio > 0)
                      filaTotal(t.cotizaDomicilio, pesos(c.domicilio)),
                    if (c.aplicaIva)
                      filaTotal(
                          '${t.costeoIva} ${cantidadStr(c.tasaIva)}%',
                          pesos(c.iva)),
                    pw.Divider(),
                    filaTotal(t.cotizaTotal, pesos(c.total), fuerte: true),
                  ],
                ),
              ),
            ),
            if (c.notas.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(c.notas, style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 24),
            pw.Text(t.cotizaPieValidez,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}
