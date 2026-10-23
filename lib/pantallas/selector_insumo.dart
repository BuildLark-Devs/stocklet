import 'package:flutter/material.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../models/insumo.dart';
import '../formato.dart';

// Opens a searchable dialog and returns the chosen supply (null if cancelled)
Future<Insumo?> elegirInsumo(BuildContext context, List<Insumo> insumos) {
  return showDialog<Insumo>(
    context: context,
    builder: (context) => _DialogoSelectorInsumo(insumos: insumos),
  );
}

class _DialogoSelectorInsumo extends StatefulWidget {
  final List<Insumo> insumos;
  const _DialogoSelectorInsumo({required this.insumos});

  @override
  State<_DialogoSelectorInsumo> createState() => _DialogoSelectorInsumoState();
}

class _DialogoSelectorInsumoState extends State<_DialogoSelectorInsumo> {
  final busquedaCtrl = TextEditingController();
  String consulta = '';

  @override
  void dispose() {
    busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final filtrados = widget.insumos
        .where((i) => sinTildes(i.nombre).contains(sinTildes(consulta)))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    return AlertDialog(
      title: Text(t.elegirInsumoTitulo),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: busquedaCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: t.buscarHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (valor) => setState(() => consulta = valor),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtrados.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.ningunInsumoCoincide),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: filtrados.map((insumo) {
                        return ListTile(
                          title: Text(insumo.nombre),
                          onTap: () => Navigator.pop(context, insumo),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancelar),
        ),
      ],
    );
  }
}
