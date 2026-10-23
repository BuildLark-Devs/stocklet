import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../datos_app.dart';
import '../../tema.dart';
import '../../formato.dart';

class GraficaTendencia extends StatelessWidget {
  final RangoTendencia rango;
  const GraficaTendencia({super.key, required this.rango});

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosApp>();
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    // Localised month abbreviation (e.g. "jul.") for the X axis on long ranges.
    String cap(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    final puntos = datos.tendenciaGanancia(
      rango,
      etiquetaMesCorto: (y, mo) =>
          cap(DateFormat.MMM(locale).format(DateTime(y, mo))),
    );
    return SizedBox(height: 200, child: _grafica(puntos, m, t));
  }

  Widget _grafica(
      List<PuntoTendencia> puntos, MarcaColores m, AppLocalizations t) {
    if (puntos.isEmpty || puntos.every((p) => p.valor == 0)) {
      return Center(
        child: Text(t.graficaSinDatos,
            style: TextStyle(color: m.textoSuave)),
      );
    }

    double minV = 0, maxV = 0;
    for (final p in puntos) {
      if (p.valor > maxV) maxV = p.valor;
      if (p.valor < minV) minV = p.valor;
    }
    final maxY = maxV <= 0 ? 100.0 : maxV * 1.15;
    final minY = minV < 0 ? minV * 1.15 : 0.0;
    final paso = (puntos.length / 6).ceil();

    final spots = <FlSpot>[
      for (int i = 0; i < puntos.length; i++)
        FlSpot(i.toDouble(), puntos[i].valor),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (puntos.length <= 1 ? 1 : puntos.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= puntos.length) {
                  return const SizedBox.shrink();
                }
                if (i % paso != 0 && i != puntos.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(puntos[i].etiqueta,
                      style: TextStyle(fontSize: 10, color: m.textoSuave)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              return LineTooltipItem(
                pesos(s.y),
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: m.verde,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: puntos.length <= 12),
            belowBarData: BarAreaData(
              show: true,
              color: m.verde.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
