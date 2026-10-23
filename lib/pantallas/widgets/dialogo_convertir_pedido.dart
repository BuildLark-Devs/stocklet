import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../datos_app.dart';
import '../../formato.dart';
import '../../models/cotizacion.dart';
import '../../models/pedido.dart';
import '../../tema.dart';

/// What the dialog returns when the person confirms.
class DatosConversion {
  final String telefono;
  final DateTime fechaEntrega;
  const DatosConversion(this.telefono, this.fechaEntrega);
}

/// Asks for the only things the quote lacks — phone and delivery date — and
/// shows what is about to happen before creating the order.
///
/// Returns `null` on cancel: cancelling writes nothing.
Future<DatosConversion?> mostrarDialogoConvertirPedido(
  BuildContext context,
  Cotizacion cotizacion,
) {
  return showDialog<DatosConversion>(
    context: context,
    builder: (_) => _DialogoConvertirPedido(cotizacion: cotizacion),
  );
}

class _DialogoConvertirPedido extends StatefulWidget {
  final Cotizacion cotizacion;
  const _DialogoConvertirPedido({required this.cotizacion});

  @override
  State<_DialogoConvertirPedido> createState() =>
      _DialogoConvertirPedidoState();
}

class _DialogoConvertirPedidoState extends State<_DialogoConvertirPedido> {
  final telefonoCtrl = TextEditingController();
  DateTime? fechaEntrega;
  bool faltaFecha = false;

  // A preview of the order, so we can inform before creating anything.
  // Computed once: neither the catalogue nor the stock change while the
  // dialog is open.
  late final Pedido _previo;
  late final List<String> _sinReceta;
  late final List<String> _faltantes;

  @override
  void initState() {
    super.initState();
    final datos = context.read<DatosApp>();
    _previo = Pedido.desdeCotizacion(
      widget.cotizacion,
      productos: datos.productos,
      telefono: '',
      fechaEntrega: DateTime.now(),
      descripcionFallback: '',
    );
    _sinReceta = [
      for (final i in _previo.items)
        if (i.receta.isEmpty) i.nombre,
    ];
    _faltantes = faltantesDeInventario(_previo, datos.insumos);
  }

  @override
  void dispose() {
    telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final sel = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
    );
    if (sel != null) {
      setState(() {
        fechaEntrega = sel;
        faltaFecha = false;
      });
    }
  }

  void _confirmar() {
    if (fechaEntrega == null) {
      setState(() => faltaFecha = true);
      return;
    }
    Navigator.pop(
      context,
      DatosConversion(telefonoCtrl.text.trim(), fechaEntrega!),
    );
  }

  Widget _aviso(MarcaColores m, Color color, IconData icono, String texto) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: m.texto)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final c = widget.cotizacion;

    return AlertDialog(
      title: Text(t.convertirTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.convertirResumen(
                  c.cliente, _previo.items.length, pesos(c.total)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.convertirTelefono,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: t.convertirFechaEntrega,
                prefixIcon: const Icon(Icons.event_outlined),
                errorText: faltaFecha ? t.convertirFaltaFecha : null,
              ),
              child: InkWell(
                onTap: _elegirFecha,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    fechaEntrega == null
                        ? t.convertirElegirFecha
                        : '${fechaEntrega!.day}/${fechaEntrega!.month}/${fechaEntrega!.year}',
                  ),
                ),
              ),
            ),

            // Which lines will NOT deduct stock.
            if (_sinReceta.isNotEmpty)
              _aviso(m, m.textoSuave, Icons.info_outline,
                  t.convertirSinInventario(_sinReceta.join(', '))),

            // Stock that would fall short. It informs, it does not block.
            if (_faltantes.isNotEmpty)
              _aviso(m, m.rojo, Icons.warning_amber_outlined,
                  t.convertirFaltantes(_faltantes.join(', '))),

            // The adjustment only shows when it subtracts, which is the
            // surprising case.
            if (_previo.otroValor < 0)
              _aviso(m, m.textoSuave, Icons.remove_circle_outline,
                  t.convertirAjuste(pesos(_previo.otroValor))),

            _aviso(m, m.textoSuave, Icons.inventory_2_outlined,
                t.convertirAvisoDescuento),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancelar),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          child: Text(t.convertirConfirmar),
        ),
      ],
    );
  }
}
