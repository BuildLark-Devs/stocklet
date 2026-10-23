import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';

class PantallaApariencia extends StatelessWidget {
  const PantallaApariencia({super.key});

  // Localised accent colour name, by its id.
  static String _nombreAcento(AppLocalizations t, String id) {
    switch (id) {
      case 'verde':
        return t.acentoVerde;
      case 'azul':
        return t.acentoAzul;
      case 'turquesa':
        return t.acentoTurquesa;
      case 'morado':
        return t.acentoMorado;
      case 'naranja':
        return t.acentoNaranja;
      case 'rosa':
        return t.acentoRosa;
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final datos = context.watch<DatosApp>();
    final m = AppColores.of(context);
    final acento = colorDeAcento(datos.acentoId);

    return Scaffold(
      appBar: AppBar(title: Text(t.apariencia)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.modo,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: m.texto)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  _modo(datos, m, acento, 'claro',
                      Icons.light_mode_outlined, t.modoClaro),
                  Divider(height: 1, color: m.borde),
                  _modo(datos, m, acento, 'oscuro',
                      Icons.dark_mode_outlined, t.modoOscuro),
                  Divider(height: 1, color: m.borde),
                  _modo(datos, m, acento, 'auto',
                      Icons.brightness_auto_outlined, t.modoAuto),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(t.colorAcento,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: m.texto)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: acentos.map((a) {
                  final sel = datos.acentoId == a.id;
                  return GestureDetector(
                    onTap: () => datos.setAcento(a.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: a.color,
                            shape: BoxShape.circle,
                            border: sel
                                ? Border.all(color: m.texto, width: 3)
                                : Border.all(color: m.borde),
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(_nombreAcento(t, a.id),
                            style: TextStyle(
                                fontSize: 12,
                                color: sel ? m.texto : m.textoSuave,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t.aparienciaNota,
              style: TextStyle(fontSize: 12, color: m.textoSuave)),
        ],
      ),
    );
  }

  Widget _modo(DatosApp datos, MarcaColores m, Color acento, String id,
      IconData icono, String label) {
    final sel = datos.modoTemaId == id;
    return InkWell(
      onTap: () => datos.setModoTema(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icono, size: 22, color: sel ? acento : m.textoSuave),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: m.texto,
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal)),
            ),
            if (sel) Icon(Icons.check_circle, color: acento, size: 22),
          ],
        ),
      ),
    );
  }
}
