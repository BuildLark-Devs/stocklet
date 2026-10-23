import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../datos_app.dart';
import '../../tema.dart';
import '../../formato.dart';
import '../historial_ventas.dart';
import '../historial_gastos.dart';
import 'grafica_tendencia.dart';

class PanelResumen extends StatefulWidget {
  const PanelResumen({super.key});

  @override
  State<PanelResumen> createState() => _PanelResumenState();
}

class _PanelResumenState extends State<PanelResumen> {
  RangoTendencia _rango = RangoTendencia.mes;

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosApp>();
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final ingresos = datos.ingresosEnRango(_rango);
    final gastos = datos.gastosEnRango(_rango);
    final ganancia = ingresos - gastos;

    // Labels for the range selector (translated).
    final opciones = {
      RangoTendencia.mes: t.rangoEsteMes,
      RangoTendencia.tres: t.rango3Meses,
      RangoTendencia.seis: t.rango6Meses,
      RangoTendencia.anio: t.rangoAnio,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.resumen,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: m.texto)),
                ),
                DropdownButton<RangoTendencia>(
                  value: _rango,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: opciones.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _rango = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _tile(
                    t.ingresos,
                    pesos(ingresos),
                    Icons.trending_up,
                    m.verde,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PantallaHistorialVentas())),
                    m,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tile(
                    t.gastos,
                    pesos(gastos),
                    Icons.trending_down,
                    m.rojo,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PantallaHistorialGastos())),
                    m,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _tile(t.ganancia, pesos(ganancia), Icons.account_balance_wallet,
                const Color(0xFF2563EB), null, m),
            const SizedBox(height: 18),
            Text(t.tendenciaGanancia,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: m.textoSuave)),
            const SizedBox(height: 8),
            GraficaTendencia(rango: _rango),
          ],
        ),
      ),
    );
  }

  Widget _tile(String titulo, String valor, IconData icono, Color color,
      VoidCallback? onTap, MarcaColores m) {
    final contenido = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(fontSize: 12, color: m.textoSuave)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: m.textoSuave, size: 18),
        ],
      ),
    );
    if (onTap == null) return contenido;
    return InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12), child: contenido);
  }
}
