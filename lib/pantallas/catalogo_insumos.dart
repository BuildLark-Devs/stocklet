import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/insumo.dart';
import '../tema.dart';
import '../formato.dart';
import '../unidades.dart';
import '../datos_catalogo_insumos.dart';

// Reference catalogue: ~65 common baking supplies. The price starts at zero;
// each person sets their own when editing the supply.
class PantallaCatalogoInsumos extends StatefulWidget {
  const PantallaCatalogoInsumos({super.key});

  @override
  State<PantallaCatalogoInsumos> createState() =>
      _PantallaCatalogoInsumosState();
}

class _PantallaCatalogoInsumosState extends State<PantallaCatalogoInsumos> {
  final busquedaCtrl = TextEditingController();
  String consulta = '';
  final Set<String> seleccion = {}; // nombres seleccionados

  @override
  void dispose() {
    busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.watch<DatosApp>();

    final yaTengo =
        datos.insumos.map((i) => sinTildes(i.nombre)).toSet();
    final disponibles = kCatalogoInsumos
        .where((x) => !yaTengo.contains(sinTildes(x.nombre)))
        .toList();
    final q = sinTildes(consulta.trim());
    final visibles = q.isEmpty
        ? disponibles
        : disponibles
            .where((x) =>
                sinTildes(x.nombre).contains(q) ||
                sinTildes(x.categoria).contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.catalogoRefTitulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.catalogoRefAyuda,
                    style: TextStyle(fontSize: 12, color: m.textoSuave)),
                const SizedBox(height: 10),
                TextField(
                  controller: busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: t.buscarEnCatalogo,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => consulta = v),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: visibles.isEmpty
                          ? null
                          : () => setState(() =>
                              seleccion.addAll(visibles.map((x) => x.nombre))),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text(t.marcarTodoVisible),
                    ),
                    const Spacer(),
                    if (seleccion.isNotEmpty)
                      Text('${seleccion.length}',
                          style: TextStyle(
                              color: m.verde, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: disponibles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(t.catalogoTodoAgregado,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: m.textoSuave)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: visibles.length,
                    itemBuilder: (_, idx) {
                      final x = visibles[idx];
                      final sel = seleccion.contains(x.nombre);
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            seleccion.add(x.nombre);
                          } else {
                            seleccion.remove(x.nombre);
                          }
                        }),
                        title: Text(x.nombre),
                        subtitle: Text(
                          '${x.categoria} · ${cantidadStr(x.cantidad)} ${kUnidades[x.unidad]?.rot ?? x.unidad}'
                          '${x.especial ? ' · ${t.especialEtiqueta}' : ''}',
                          style: TextStyle(fontSize: 12, color: m.textoSuave),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: seleccion.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () {
                    final nuevos = kCatalogoInsumos
                        .where((x) => seleccion.contains(x.nombre))
                        .map((x) => Insumo.desdePresentacion(
                              nombre: x.nombre,
                              categoria: x.categoria,
                              cantidadCompra: x.cantidad,
                              unidadCompra: x.unidad,
                              precioPresentacion: 0,
                              stockActual: 0,
                              especial: x.especial,
                            ))
                        .toList();
                    context
                        .read<DatosApp>()
                        .agregarInsumosDesdeCatalogo(nuevos);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(t.insumosAgregadosN(nuevos.length))),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(t.agregarSeleccionadosN(seleccion.length)),
                ),
              ),
            ),
    );
  }
}
