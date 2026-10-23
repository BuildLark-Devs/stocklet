import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/insumo.dart';
import '../tema.dart';
import '../formato.dart';
import '../unidades.dart';

class PantallaEditarInsumo extends StatefulWidget {
  final Insumo insumo;
  const PantallaEditarInsumo({super.key, required this.insumo});

  @override
  State<PantallaEditarInsumo> createState() => _PantallaEditarInsumoState();
}

class _PantallaEditarInsumoState extends State<PantallaEditarInsumo> {
  late final TextEditingController nombreCtrl;
  late final TextEditingController cantidadCtrl;
  late final TextEditingController precioCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController minimoCtrl;
  late final TextEditingController proveedorCtrl;
  late String categoria;
  late String unidadCompra;
  late bool especial;

  @override
  void initState() {
    super.initState();
    final i = widget.insumo;
    nombreCtrl = TextEditingController(text: i.nombre);
    cantidadCtrl = TextEditingController(text: cantidadStr(i.cantidadCompra));
    precioCtrl = TextEditingController(text: cantidadStr(i.precioPresentacion));
    stockCtrl = TextEditingController(text: cantidadStr(i.stockActual));
    minimoCtrl = TextEditingController(text: cantidadStr(i.stockMinimo));
    proveedorCtrl = TextEditingController(text: i.proveedor);
    categoria = kCategoriasInsumo.contains(i.categoria) ? i.categoria : 'Otros';
    unidadCompra = kUnidades.containsKey(i.unidadCompra) ? i.unidadCompra : 'g';
    especial = i.especial;
    cantidadCtrl.addListener(() => setState(() {}));
    precioCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    cantidadCtrl.dispose();
    precioCtrl.dispose();
    stockCtrl.dispose();
    minimoCtrl.dispose();
    proveedorCtrl.dispose();
    super.dispose();
  }

  void guardar() {
    final t = AppLocalizations.of(context)!;
    final nombre = nombreCtrl.text.trim();
    final cantidad = parseCantidad(cantidadCtrl.text);
    final precio = parseCantidad(precioCtrl.text);
    // Stock can be negative (from deductions) and has to be correctable, but
    // empty is not zero: if it cannot be parsed, that is a typing mistake and
    // deserves a warning rather than silently saving a 0.
    final stock = double.tryParse(stockCtrl.text.trim().replaceAll(',', '.'));

    if (nombre.isEmpty || cantidad <= 0 || precio < 0 || stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.revisaCamposNegativos)),
      );
      return;
    }

    final base = baseDeUnidad(unidadCompra);
    final costo = costoBaseDesde(precio, cantidad, unidadCompra);

    context.read<DatosApp>().editarInsumo(
          widget.insumo,
          nombre: nombre,
          unidad: base,
          costoPorUnidad: costo,
          stockActual: stock,
          stockMinimo: parseCantidad(minimoCtrl.text),
          categoria: categoria,
          unidadCompra: unidadCompra,
          cantidadCompra: cantidad,
          precioPresentacion: precio,
          proveedor: proveedorCtrl.text.trim(),
          especial: especial,
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.watch<DatosApp>();
    final soloLectura = !datos.puedeGestionarCatalogo;
    final base = baseDeUnidad(unidadCompra);
    final costo =
        costoBaseDesde(parseCantidad(precioCtrl.text), parseCantidad(cantidadCtrl.text), unidadCompra);

    return Scaffold(
      appBar: AppBar(title: Text(t.editarInsumoTitulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: t.campoNombre,
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: categoria,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.categoriaLabel,
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    items: [
                      for (final c in kCategoriasInsumo)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => categoria = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cantidadCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [Decimal2Formatter()],
                          decoration:
                              InputDecoration(labelText: t.cantidadQueCompras),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unidadCompra,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: t.unidadDeCompra),
                          items: [
                            for (final e in kUnidades.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(e.value.rot)),
                          ],
                          onChanged: (v) => setState(() => unidadCompra = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: precioCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.precioPresentacionLabel,
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  if (costo > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      t.costoPorUnidadCalculado(pesos(costo), rotBase(base)),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: m.verde),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [DecimalSignedFormatter()],
                    decoration: InputDecoration(
                      labelText: '${t.stockActualLabel} (${rotBase(base)})',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: minimoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.stockMinimoOpcional,
                      hintText: t.stockMinimoHint,
                      prefixIcon:
                          const Icon(Icons.notifications_active_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: proveedorCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: t.proveedorOpcional,
                      prefixIcon: const Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: especial,
                    onChanged: (v) => setState(() => especial = v),
                    title: Text(t.insumoEspecialLabel),
                    subtitle: Text(t.insumoEspecialAyuda,
                        style: TextStyle(fontSize: 12, color: m.textoSuave)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!soloLectura)
            ElevatedButton(onPressed: guardar, child: Text(t.guardarCambios))
          else
            Center(child: Text(t.soloLectura)),
        ],
      ),
    );
  }
}
