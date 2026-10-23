import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/gasto.dart';
import '../tema.dart';
import '../formato.dart';
import 'selector_insumo.dart';
import 'gasto_categoria_l10n.dart';

enum _ModoGasto { normal, insumos }

class PantallaRegistrarGasto extends StatefulWidget {
  const PantallaRegistrarGasto({super.key});

  @override
  State<PantallaRegistrarGasto> createState() => _PantallaRegistrarGastoState();
}

class _PantallaRegistrarGastoState extends State<PantallaRegistrarGasto> {
  _ModoGasto modo = _ModoGasto.normal;

  // Gasto normal
  final descripcionCtrl = TextEditingController();
  final montoCtrl = TextEditingController();
  CategoriaGasto categoria = CategoriaGasto.insumos;

  // Buying supplies
  final compraDescCtrl = TextEditingController();
  final List<LineaCompraInsumo> lineas = [];

  @override
  void dispose() {
    descripcionCtrl.dispose();
    montoCtrl.dispose();
    compraDescCtrl.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _guardarNormal() {
    final t = AppLocalizations.of(context)!;
    final descripcion = descripcionCtrl.text.trim();
    final monto = parseCantidad(montoCtrl.text);
    if (descripcion.isEmpty || monto <= 0) {
      _aviso(t.gastoDescripcionMonto);
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.confirmarGasto),
        content: Text(t.confirmarGastoTexto(descripcion, pesos(monto))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () {
              context.read<DatosApp>().registrarGasto(Gasto(
                    fecha: DateTime.now(),
                    descripcion: descripcion,
                    categoria: categoria,
                    monto: monto,
                  ));
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(t.guardar),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarLinea() async {
    final t = AppLocalizations.of(context)!;
    final insumos = [...context.read<DatosApp>().insumos]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    if (insumos.isEmpty) {
      _aviso(t.primeroCreaInsumos);
      return;
    }
    final insumo = await elegirInsumo(context, insumos);
    if (insumo == null || !mounted) return;
    if (lineas.any((l) => l.insumo.id == insumo.id)) {
      _aviso(t.insumoYaEnLista);
      return;
    }
    final cantidadCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(insumo.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantidadCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [Decimal2Formatter()],
              autofocus: true,
              decoration: InputDecoration(
                  labelText: t.cantidadCompradaUnidad(insumo.unidad)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [Decimal2Formatter()],
              decoration: InputDecoration(
                  labelText: t.totalPagado, prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(t.cancelar)),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(t.agregar)),
        ],
      ),
    );
    final cantidad = parseCantidad(cantidadCtrl.text);
    final total = parseCantidad(totalCtrl.text);
    cantidadCtrl.dispose();
    totalCtrl.dispose();
    if (ok != true || !mounted) return;
    if (cantidad <= 0 || total <= 0) {
      _aviso(t.cantidadTotalMayorCero);
      return;
    }
    setState(() => lineas.add(LineaCompraInsumo(insumo, cantidad, total)));
  }

  void _guardarCompra() {
    final t = AppLocalizations.of(context)!;
    if (lineas.isEmpty) {
      _aviso(t.agregaAlMenosInsumo);
      return;
    }
    final total = lineas.fold<double>(0, (s, l) => s + l.total);
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.confirmarCompra),
        content: Text(t.confirmarCompraTexto(lineas.length, pesos(total))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(t.cancelar)),
          ElevatedButton(
            onPressed: () {
              context.read<DatosApp>().comprarInsumos(
                    lineas: lineas,
                    descripcion: compraDescCtrl.text,
                  );
              Navigator.pop(dc);
              Navigator.pop(context);
            },
            child: Text(t.guardar),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final totalCompra = lineas.fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      appBar: AppBar(title: Text(t.registrarGastoTitulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_ModoGasto>(
            segments: [
              ButtonSegment(
                  value: _ModoGasto.normal,
                  label: Text(t.gastoNormal),
                  icon: const Icon(Icons.receipt_long_outlined)),
              ButtonSegment(
                  value: _ModoGasto.insumos,
                  label: Text(t.compraInsumos),
                  icon: const Icon(Icons.inventory_2_outlined)),
            ],
            selected: {modo},
            onSelectionChanged: (s) => setState(() => modo = s.first),
          ),
          const SizedBox(height: 20),
          if (modo == _ModoGasto.normal)
            ..._camposNormal(t)
          else
            ..._camposCompra(m, t, totalCompra),
        ],
      ),
    );
  }

  List<Widget> _camposNormal(AppLocalizations t) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: descripcionCtrl,
                decoration: InputDecoration(
                  labelText: t.descripcion,
                  hintText: t.gastoDescripcionHint,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [Decimal2Formatter()],
                decoration: InputDecoration(
                    labelText: t.monto, prefixText: '\$ '),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CategoriaGasto>(
                initialValue: categoria,
                decoration: InputDecoration(labelText: t.categoria),
                items: CategoriaGasto.values.map((c) {
                  return DropdownMenuItem(
                      value: c, child: Text(nombreCategoria(t, c)));
                }).toList(),
                onChanged: (nueva) => setState(() => categoria = nueva!),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: _guardarNormal, child: Text(t.guardarGasto)),
    ];
  }

  List<Widget> _camposCompra(MarcaColores m, AppLocalizations t, double total) {
    return [
      Text(t.compraInsumosAyuda,
          style: TextStyle(fontSize: 12, color: m.textoSuave)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _agregarLinea,
        icon: const Icon(Icons.add),
        label: Text(t.agregarInsumoBtn),
      ),
      const SizedBox(height: 12),
      if (lineas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.sinInsumosAgregados,
              style: TextStyle(color: m.textoSuave)),
        )
      else
        ...lineas.asMap().entries.map((e) {
          final l = e.value;
          return Card(
            child: ListTile(
              dense: true,
              title: Text(l.insumo.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t.ingredienteSubtitulo(
                  cantidadStr(l.cantidad),
                  l.insumo.unidad,
                  pesos(l.total))),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: m.rojo),
                onPressed: () => setState(() => lineas.removeAt(e.key)),
              ),
            ),
          );
        }),
      const SizedBox(height: 12),
      TextField(
        controller: compraDescCtrl,
        decoration: InputDecoration(
          labelText: t.descripcionOpcional,
          hintText: t.compraDescHint,
        ),
      ),
      const SizedBox(height: 16),
      Card(
        color: m.verde.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.totalGasto, style: TextStyle(color: m.textoSuave)),
              Text(pesos(total),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: m.texto)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
          onPressed: _guardarCompra,
          child: Text(t.guardarCompraReponer)),
    ];
  }
}
