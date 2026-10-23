import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../datos_app.dart';
import '../../models/insumo.dart';
import '../../models/producto.dart';
import '../../models/ingrediente_de_receta.dart';
import '../../costeo.dart';
import '../../tema.dart';
import '../../formato.dart';
import '../selector_insumo.dart';
import '../selector_tipo.dart';
import '../ajustes_costeo.dart';
import 'desglose_costeo.dart';

class FormularioProducto extends StatefulWidget {
  final Producto? producto;
  const FormularioProducto({super.key, this.producto});

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  final nombreCtrl = TextEditingController();
  final precioCtrl = TextEditingController();
  final rendimientoCtrl = TextEditingController(text: '1');
  final minPrepCtrl = TextEditingController();
  final minHornoCtrl = TextEditingController();
  final mermaCtrl = TextEditingController();
  final margenCtrl = TextEditingController();
  final unidadesMesCtrl = TextEditingController();
  String tipo = '';
  bool sinAzucar = false;
  String metodoMargen = ''; // '' = el del negocio

  final List<IngredienteDeReceta> receta = [];
  final List<IngredienteDeReceta> empaque = [];
  Insumo? recetaSel;
  Insumo? empaqueSel;
  final recetaCantCtrl = TextEditingController();
  final empaqueCantCtrl = TextEditingController();

  bool get esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p != null) {
      nombreCtrl.text = p.nombre;
      precioCtrl.text = cantidadStr(p.precioVenta);
      rendimientoCtrl.text = cantidadStr(p.rendimiento);
      minPrepCtrl.text = p.minutosPrep > 0 ? cantidadStr(p.minutosPrep) : '';
      minHornoCtrl.text = p.minutosHorno > 0 ? cantidadStr(p.minutosHorno) : '';
      mermaCtrl.text = p.mermaPct > 0 ? cantidadStr(p.mermaPct) : '';
      margenCtrl.text = p.margenPct != null ? cantidadStr(p.margenPct!) : '';
      unidadesMesCtrl.text =
          p.unidadesMesEstimadas > 0 ? cantidadStr(p.unidadesMesEstimadas) : '';
      tipo = p.tipo;
      sinAzucar = p.sinAzucar;
      metodoMargen = p.metodoMargen;
      receta.addAll(p.receta.map((i) =>
          IngredienteDeReceta(insumo: i.insumo, cantidad: i.cantidad)));
      empaque.addAll(p.empaque.map((i) =>
          IngredienteDeReceta(insumo: i.insumo, cantidad: i.cantidad)));
    }
    for (final c in [precioCtrl, rendimientoCtrl, minPrepCtrl, minHornoCtrl,
      mermaCtrl, margenCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [nombreCtrl, precioCtrl, rendimientoCtrl, minPrepCtrl,
      minHornoCtrl, mermaCtrl, margenCtrl, unidadesMesCtrl, recetaCantCtrl,
      empaqueCantCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregarLinea({required bool esEmpaque}) {
    final t = AppLocalizations.of(context)!;
    final sel = esEmpaque ? empaqueSel : recetaSel;
    final cant = parseCantidad(
        (esEmpaque ? empaqueCantCtrl : recetaCantCtrl).text);
    final lista = esEmpaque ? empaque : receta;
    if (sel == null || cant <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.eligeInsumoCantidad)));
      return;
    }
    if (lista.any((x) => x.insumo == sel)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.insumoYaEnReceta)));
      return;
    }
    setState(() {
      lista.add(IngredienteDeReceta(insumo: sel, cantidad: cant));
      if (esEmpaque) {
        empaqueSel = null;
        empaqueCantCtrl.clear();
      } else {
        recetaSel = null;
        recetaCantCtrl.clear();
      }
    });
  }

  Producto _tempProducto() {
    final rend = parseCantidad(rendimientoCtrl.text);
    return Producto(
      nombre: nombreCtrl.text.trim(),
      tipo: tipo,
      receta: receta,
      empaque: empaque,
      precioVenta: parseCantidad(precioCtrl.text),
      rendimiento: rend <= 0 ? 1 : rend,
      mermaPct: parseCantidad(mermaCtrl.text),
      minutosPrep: parseCantidad(minPrepCtrl.text),
      minutosHorno: parseCantidad(minHornoCtrl.text),
      metodoMargen: metodoMargen,
      margenPct:
          margenCtrl.text.trim().isEmpty ? null : parseCantidad(margenCtrl.text),
      sinAzucar: sinAzucar,
    );
  }

  void _guardar() {
    final t = AppLocalizations.of(context)!;
    final nombre = nombreCtrl.text.trim();
    final precio = parseCantidad(precioCtrl.text);
    if (nombre.isEmpty || precio <= 0 || receta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.faltaNombrePrecioIngrediente)));
      return;
    }
    final datos = context.read<DatosApp>();
    final rend = parseCantidad(rendimientoCtrl.text);
    final margen =
        margenCtrl.text.trim().isEmpty ? null : parseCantidad(margenCtrl.text);
    if (esEdicion) {
      datos.editarProducto(
        widget.producto!,
        nombre: nombre,
        tipo: tipo,
        precioVenta: precio,
        receta: receta,
        empaque: empaque,
        rendimiento: rend <= 0 ? 1 : rend,
        mermaPct: parseCantidad(mermaCtrl.text),
        minutosPrep: parseCantidad(minPrepCtrl.text),
        minutosHorno: parseCantidad(minHornoCtrl.text),
        metodoMargen: metodoMargen,
        margenPct: margen,
        sinAzucar: sinAzucar,
        unidadesMesEstimadas: parseCantidad(unidadesMesCtrl.text),
      );
    } else {
      datos.agregarProducto(Producto(
        nombre: nombre,
        tipo: tipo,
        receta: receta,
        empaque: empaque,
        precioVenta: precio,
        rendimiento: rend <= 0 ? 1 : rend,
        mermaPct: parseCantidad(mermaCtrl.text),
        minutosPrep: parseCantidad(minPrepCtrl.text),
        minutosHorno: parseCantidad(minHornoCtrl.text),
        metodoMargen: metodoMargen,
        margenPct: margen,
        sinAzucar: sinAzucar,
        unidadesMesEstimadas: parseCantidad(unidadesMesCtrl.text),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.watch<DatosApp>();
    final soloLectura = !datos.puedeGestionarCatalogo;
    final insumos = [...datos.insumos]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final tipos = (<String>{
      for (final p in datos.productos)
        if (p.tipo.trim().isNotEmpty) p.tipo
    }.toList()
      ..sort());
    final r = costear(_tempProducto(), datos.configCosteo);

    return Scaffold(
      appBar: AppBar(
          title: Text(esEdicion ? t.editarProductoTitulo : t.crearProductoTitulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- The basics ---
          _seccion(m, t.prodBasico),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: t.nombreProducto,
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final elegido = await elegirTipo(context, tipos);
                      if (elegido != null && mounted) {
                        setState(() => tipo = elegido);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t.tipoProducto,
                        prefixIcon: const Icon(Icons.category_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(tipo.isEmpty ? t.sinTipo : tipo),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: rendimientoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.prodRendimiento,
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sinAzucar,
                    onChanged: (v) => setState(() => sinAzucar = v),
                    title: Text(t.prodSinAzucar),
                  ),
                ],
              ),
            ),
          ),

          // --- Ingredientes (por lote) ---
          const SizedBox(height: 16),
          _seccion(m, t.prodIngredientesLote),
          _bloqueLineas(context, t, m, insumos, esEmpaque: false),

          // --- Empaque (por unidad) ---
          const SizedBox(height: 16),
          _seccion(m, t.prodEmpaque),
          _bloqueLineas(context, t, m, insumos, esEmpaque: true),

          // --- Tiempos y merma ---
          const SizedBox(height: 16),
          _seccion(m, t.prodTiemposMerma),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPrepCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [Decimal2Formatter()],
                          decoration:
                              InputDecoration(labelText: t.prodMinutosPrep),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minHornoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [Decimal2Formatter()],
                          decoration:
                              InputDecoration(labelText: t.prodMinutosHorno),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mermaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.prodMerma,
                      helperText: t.prodMermaAyuda,
                      helperMaxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Precio ---
          const SizedBox(height: 16),
          _seccion(m, t.prodPrecioSeccion),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: metodoMargen,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: t.prodMetodoMargen),
                    items: [
                      DropdownMenuItem(value: '', child: Text(t.prodMetodoDefault)),
                      DropdownMenuItem(
                          value: 'venta', child: Text(t.prodMetodoVenta)),
                      DropdownMenuItem(
                          value: 'markup', child: Text(t.prodMetodoMarkup)),
                    ],
                    onChanged: (v) => setState(() => metodoMargen = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: margenCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.prodMargenReceta,
                      hintText: t.prodMargenHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precioCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.prodPrecioCobras,
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unidadesMesCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [Decimal2Formatter()],
                    decoration: InputDecoration(
                      labelText: t.prodUnidadesMes,
                      helperText: t.prodUnidadesMesAyuda,
                      helperMaxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Desglose de costeo ---
          const SizedBox(height: 16),
          DesgloseCosteo(
            r: r,
            onUsarSugerido: r.precioSugerido > 0
                ? () => setState(() =>
                    precioCtrl.text = cantidadStr(r.precioSugerido.roundToDouble()))
                : null,
            onCompletarFijos: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PantallaAjustesCosteo())),
          ),

          const SizedBox(height: 20),
          if (!soloLectura)
            ElevatedButton(
                onPressed: _guardar,
                child: Text(esEdicion ? t.guardarCambios : t.guardarProducto))
          else
            Center(
                child: Text(t.soloLectura,
                    style: TextStyle(color: m.textoSuave))),
        ],
      ),
    );
  }

  Widget _seccion(MarcaColores m, String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(titulo,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
      );

  Widget _bloqueLineas(BuildContext context, AppLocalizations t,
      MarcaColores m, List<Insumo> insumos,
      {required bool esEmpaque}) {
    final lista = esEmpaque ? empaque : receta;
    final sel = esEmpaque ? empaqueSel : recetaSel;
    final cantCtrl = esEmpaque ? empaqueCantCtrl : recetaCantCtrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (insumos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t.recetaSinInsumos,
                    style: TextStyle(color: m.textoSuave)),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final elegido = await elegirInsumo(context, insumos);
                    if (elegido != null && mounted) {
                      setState(() {
                        if (esEmpaque) {
                          empaqueSel = elegido;
                        } else {
                          recetaSel = elegido;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: Text(sel?.nombre ?? t.elegirInsumoTitulo,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [Decimal2Formatter()],
                      decoration: InputDecoration(
                        labelText: sel == null
                            ? t.cantidad
                            : '${t.cantidad} (${sel.rotUnidadBase})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () => _agregarLinea(esEmpaque: esEmpaque),
                  ),
                ],
              ),
            ],
            if (lista.isNotEmpty) const SizedBox(height: 8),
            ...lista.map((ing) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(ing.insumo.nombre),
                  subtitle: Text(t.ingredienteSubtitulo(
                      cantidadStr(ing.cantidad),
                      ing.insumo.rotUnidadBase,
                      pesos(ing.costo))),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: m.rojo),
                    onPressed: () => setState(() => lista.remove(ing)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
