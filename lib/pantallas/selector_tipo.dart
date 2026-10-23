import 'package:flutter/material.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../tema.dart';

// Returns the chosen type ('' = no type, or a new/existing name), or null if
// cancelled.
Future<String?> elegirTipo(BuildContext context, List<String> tipos) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DialogoTipo(tipos: tipos),
  );
}

class _DialogoTipo extends StatefulWidget {
  final List<String> tipos;
  const _DialogoTipo({required this.tipos});

  @override
  State<_DialogoTipo> createState() => _DialogoTipoState();
}

class _DialogoTipoState extends State<_DialogoTipo> {
  final nuevoCtrl = TextEditingController();

  @override
  void dispose() {
    nuevoCtrl.dispose();
    super.dispose();
  }

  void _crear() {
    final nombre = nuevoCtrl.text.trim();
    if (nombre.isEmpty) return;
    Navigator.pop(context, nombre);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(t.tipoProducto),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nuevoCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t.crearTipoHint,
                      prefixIcon: const Icon(Icons.add),
                    ),
                    onSubmitted: (_) => _crear(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                    icon: const Icon(Icons.check), onPressed: _crear),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              dense: true,
              leading: Icon(Icons.block, color: m.textoSuave),
              title: Text(t.sinTipo),
              onTap: () => Navigator.pop(context, ''),
            ),
            Flexible(
              child: widget.tipos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(t.sinTipos,
                          style: TextStyle(color: m.textoSuave)),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: widget.tipos.map((tp) {
                        return ListTile(
                          dense: true,
                          leading:
                              Icon(Icons.label_outline, color: m.verde),
                          title: Text(tp),
                          onTap: () => Navigator.pop(context, tp),
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
            child: Text(t.cancelar)),
      ],
    );
  }
}
