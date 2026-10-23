import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';
import '../formato.dart';

class PantallaAnalisisVentas extends StatelessWidget {
  const PantallaAnalisisVentas({super.key});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // Localised weekday name (1=Mon..7=Sun).
  static String _diaNombre(int weekday, String locale) =>
      _cap(DateFormat.EEEE(locale).format(DateTime(2024, 1, weekday)));

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosApp>();
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    // Localised month labels (e.g. "jul. 2026") for "Demand by month".
    final a = datos.analisisVentas(
      etiquetaMes: (y, mo) =>
          _cap(DateFormat.yMMM(locale).format(DateTime(y, mo))),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.analisisVentasTitulo)),
      body: a.numVentas == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(t.sinVentasAnalizar,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: m.textoSuave)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ticket(m, a, t),
                const SizedBox(height: 16),
                _demanda(m, a, t),
                const SizedBox(height: 16),
                _diaSemana(m, a, t, locale),
                const SizedBox(height: 16),
                _fechasPico(m, a, t, locale),
              ],
            ),
    );
  }

  Widget _ticket(MarcaColores m, AnalisisVentas a, AppLocalizations t) {
    Widget bloque(String label, String v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: m.textoSuave)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(v,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: m.texto)),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.resumenGeneral,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
            const SizedBox(height: 12),
            Row(
              children: [
                bloque(t.ticketPromedio, pesos(a.ticketPromedio)),
                bloque(t.numVentasLabel, '${a.numVentas}'),
                bloque(t.totalVendido, pesos(a.totalVendido)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _demanda(MarcaColores m, AnalisisVentas a, AppLocalizations t) {
    final ordenados = [...a.porMes]..sort((x, y) => y.value.compareTo(x.value));
    final mejor = ordenados.first;
    final peor = ordenados.last;
    final maxV = mejor.value <= 0 ? 1 : mejor.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.demandaPorMes,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
            const SizedBox(height: 4),
            Text(t.demandaFuerteFlojo(mejor.key, peor.key),
                style: TextStyle(fontSize: 12, color: m.textoSuave)),
            const SizedBox(height: 12),
            ...a.porMes.map((e) {
              final frac = (e.value / maxV).clamp(0.0, 1.0);
              final esMejor = e.key == mejor.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 70,
                        child: Text(e.key,
                            style:
                                TextStyle(fontSize: 12, color: m.textoSuave))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 10,
                          backgroundColor: m.borde.withValues(alpha: 0.5),
                          color: esMejor
                              ? m.verde
                              : m.verde.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(pesos(e.value),
                        style: TextStyle(fontSize: 11, color: m.textoSuave)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _diaSemana(
      MarcaColores m, AnalisisVentas a, AppLocalizations t, String locale) {
    final maxV = a.porDiaSemana
        .map((e) => e.value)
        .fold<double>(0, (mx, v) => v > mx ? v : mx);
    final mejor = [...a.porDiaSemana]..sort((x, y) => y.value.compareTo(x.value));
    final base = maxV <= 0 ? 1 : maxV;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.ventasPorDia,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
            const SizedBox(height: 4),
            Text(
                mejor.first.value > 0
                    ? t.mejorDia(_diaNombre(mejor.first.key, locale)
                        .toLowerCase())
                    : t.sinDatosSuficientes,
                style: TextStyle(fontSize: 12, color: m.textoSuave)),
            const SizedBox(height: 12),
            ...a.porDiaSemana.map((e) {
              final frac = (e.value / base).clamp(0.0, 1.0);
              final esMejor = e.key == mejor.first.key && e.value > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text(_diaNombre(e.key, locale),
                            style:
                                TextStyle(fontSize: 12, color: m.textoSuave))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 10,
                          backgroundColor: m.borde.withValues(alpha: 0.5),
                          color: esMejor
                              ? m.verde
                              : m.verde.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(pesos(e.value),
                        style: TextStyle(fontSize: 11, color: m.textoSuave)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _fechasPico(
      MarcaColores m, AnalisisVentas a, AppLocalizations t, String locale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.fechasPico,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
            const SizedBox(height: 4),
            Text(t.fechasPicoAyuda,
                style: TextStyle(fontSize: 12, color: m.textoSuave)),
            const SizedBox(height: 12),
            ...a.fechasPico.asMap().entries.map((e) {
              final puesto = e.key + 1;
              final fecha = e.value.key;
              final valor = e.value.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      height: 28,
                      width: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m.verde.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text('$puesto',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: m.verdeOscuro)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          DateFormat.yMMMMd(locale).format(fecha),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: m.texto)),
                    ),
                    Text(pesos(valor),
                        style: TextStyle(fontSize: 13, color: m.textoSuave)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
