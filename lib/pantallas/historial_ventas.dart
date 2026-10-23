import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/venta.dart';
import '../tema.dart';
import '../formato.dart';
import 'editar_venta.dart';
import '../servicios/gate_pro.dart';

class PantallaHistorialVentas extends StatefulWidget {
  const PantallaHistorialVentas({super.key});

  @override
  State<PantallaHistorialVentas> createState() =>
      _PantallaHistorialVentasState();
}

class _PantallaHistorialVentasState extends State<PantallaHistorialVentas> {
  DateTime? _mes; // primer día del mes elegido (null = mes actual)

  // Month name localised to the active language (e.g. "Julio 2026").
  String _label(BuildContext context, DateTime f) {
    final locale = Localizations.localeOf(context).toString();
    final texto = DateFormat.yMMMM(locale).format(f);
    return texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
  }

  void _confirmarEliminar(BuildContext context, Venta venta) {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.eliminarVentaTitulo),
        content: Text(t.eliminarVentaConfirmacion),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () {
              datos.eliminarVenta(venta);
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
      appBar: AppBar(title: Text(t.historialVentasTitulo)),
      body: Consumer<DatosApp>(
        builder: (context, datos, child) {
          if (datos.ventas.isEmpty) {
            return Center(
              child: Text(t.sinVentas,
                  style: TextStyle(color: m.textoSuave)),
            );
          }

          final ahora = DateTime.now();
          final actual = DateTime(ahora.year, ahora.month);
          final set = <DateTime>{actual};
          for (final v in datos.ventas) {
            set.add(DateTime(v.fecha.year, v.fecha.month));
          }
          final todosMeses = set.toList()..sort((a, b) => b.compareTo(a));
          // Free = the last 3 months of history; the rest requires Pro.
          final hayMasHistorial = !datos.esPro && todosMeses.length > 3;
          final meses =
              datos.esPro ? todosMeses : todosMeses.take(3).toList();

          final sel = _mes ?? actual;
          final selValido = meses.contains(sel) ? sel : meses.first;

          final lista = datos.ventas
              .where((v) =>
                  v.fecha.year == selValido.year &&
                  v.fecha.month == selValido.month)
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
                            t.sinVentasEnMes(_label(context, selValido)),
                            style: TextStyle(color: m.textoSuave)),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: lista.map((venta) {
                          final fechaStr =
                              '${venta.fecha.day}/${venta.fecha.month}/${venta.fecha.year}';
                          return Card(
                            child: ListTile(
                              title: Text(venta.descripcion),
                              subtitle: Text(
                                t.ventaSubtitulo(fechaStr, cantidadStr(venta.cantidad)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(pesos(venta.total),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (datos.puedeEditarFinanzas ||
                                      datos.puedeEliminar)
                                    PopupMenuButton<String>(
                                      onSelected: (opcion) {
                                        if (opcion == 'editar') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PantallaEditarVenta(
                                                      venta: venta),
                                            ),
                                          );
                                        } else if (opcion == 'eliminar') {
                                          _confirmarEliminar(context, venta);
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
