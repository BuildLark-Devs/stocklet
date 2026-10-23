import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../servicios/gate_pro.dart';
import '../../datos_app.dart';
import '../../tema.dart';
import '../../formato.dart';
import '../analisis_ventas.dart';

class WidgetAnalisisVentas extends StatelessWidget {
  const WidgetAnalisisVentas({super.key});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // Localised short weekday (1=Mon..7=Sun).
  static String _diaCorto(int weekday, String locale) =>
      _cap(DateFormat.E(locale).format(DateTime(2024, 1, weekday)));

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosApp>();
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final a = datos.analisisVentas();

    String resumen;
    if (a.numVentas == 0) {
      resumen = t.sinVentasAnalizar;
    } else {
      final mejorDia = [...a.porDiaSemana]
        ..sort((x, y) => y.value.compareTo(x.value));
      final nombreDia = mejorDia.first.value > 0
          ? _diaCorto(mejorDia.first.key, locale)
          : '—';
      resumen = t.resumenAnalisisCorto(pesos(a.ticketPromedio), nombreDia);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.analisisVentasTitulo,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: m.texto)),
                ),
                TextButton(
                  onPressed: () async {
                    if (await exigirPro(context) && context.mounted) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PantallaAnalisisVentas()));
                    }
                  },
                  child: Text(t.verMas),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.insights, size: 18, color: m.textoSuave),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(resumen, style: TextStyle(color: m.textoSuave)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
