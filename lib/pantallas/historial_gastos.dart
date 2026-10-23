import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/gasto.dart';
import '../tema.dart';
import '../formato.dart';
import 'editar_gasto.dart';
import 'gasto_categoria_l10n.dart';
import '../servicios/gate_pro.dart';

class PantallaHistorialGastos extends StatefulWidget {
  const PantallaHistorialGastos({super.key});

  @override
  State<PantallaHistorialGastos> createState() =>
      _PantallaHistorialGastosState();
}

class _PantallaHistorialGastosState extends State<PantallaHistorialGastos> {
  DateTime? _mes; // primer día del mes elegido (null = mes actual)

  // Mes localizado (ej. "Julio 2026").
  String _label(BuildContext context, DateTime f) {
    final locale = Localizations.localeOf(context).toString();
    final texto = DateFormat.yMMMM(locale).format(f);
    return texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
  }

  void _confirmarEliminar(BuildContext context, Gasto gasto) {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.eliminarGastoTitulo),
        content: Text(t.eliminarGastoConfirmacion(gasto.descripcion)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.cancelar),
          ),
          TextButton(
            onPressed: () {
              datos.eliminarGasto(gasto);
              Navigator.pop(dialogContext);
            },
            child: Text(t.eliminar),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.historialGastosTitulo)),
      body: Consumer<DatosApp>(
        builder: (context, datos, child) {
          if (datos.gastos.isEmpty) {
            return Center(
              child: Text(t.sinGastos,
                  style: TextStyle(color: m.textoSuave)),
            );
          }

          final ahora = DateTime.now();
          final actual = DateTime(ahora.year, ahora.month);
          final set = <DateTime>{actual};
          for (final g in datos.gastos) {
            set.add(DateTime(g.fecha.year, g.fecha.month));
          }
          final todosMeses = set.toList()..sort((a, b) => b.compareTo(a));
          // Free = the last 3 months of history; the rest requires Pro.
          final hayMasHistorial = !datos.esPro && todosMeses.length > 3;
          final meses =
              datos.esPro ? todosMeses : todosMeses.take(3).toList();

          final sel = _mes ?? actual;
          final selValido = meses.contains(sel) ? sel : meses.first;

          final lista = datos.gastos
              .where((g) =>
                  g.fecha.year == selValido.year &&
                  g.fecha.month == selValido.month)
              .toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text(t.mesLabel, style: TextStyle(color: m.textoSuave)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<DateTime>(
                        value: selValido,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        items: meses
                            .map((mes) => DropdownMenuItem(
                                value: mes,
                                child: Text(_label(context, mes))))
                            .toList(),
                        onChanged: (v) => setState(() => _mes = v),
                      ),
                    ),
                  ],
                ),
              ),
              if (hayMasHistorial)
                InkWell(
                  onTap: () => exigirPro(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 16, color: m.textoSuave),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(t.historialCompletoPro,
                              style: TextStyle(
                                  fontSize: 12, color: m.textoSuave)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: lista.isEmpty
                    ? Center(
                        child: Text(
                            t.sinGastosEnMes(_label(context, selValido)),
                            style: TextStyle(color: m.textoSuave)),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: lista.map((gasto) {
                          final fechaStr =
                              '${gasto.fecha.day}/${gasto.fecha.month}/${gasto.fecha.year}';
                          return Card(
                            child: ListTile(
                              title: Text(gasto.descripcion),
                              subtitle: Text(
                                t.gastoSubtitulo(fechaStr,
                                    nombreCategoria(t, gasto.categoria)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pesos(gasto.monto),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (datos.puedeEditarFinanzas ||
                                      datos.puedeEliminar)
                                    PopupMenuButton<String>(
                                      onSelected: (opcion) {
                                        if (opcion == 'editar') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PantallaEditarGasto(
                                                      gasto: gasto),
                                            ),
                                          );
                                        } else if (opcion == 'eliminar') {
                                          _confirmarEliminar(context, gasto);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (datos.puedeEditarFinanzas)
                                          PopupMenuItem(
                                              value: 'editar',
                                              child: Text(t.editar)),
                                        if (datos.puedeEliminar)
                                          PopupMenuItem(
                                              value: 'eliminar',
                                              child: Text(t.eliminar)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
