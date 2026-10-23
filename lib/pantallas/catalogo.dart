import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/catalogo.dart';
import '../tema.dart';
import '../servicios/gate_pro.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  bool subiendo = false;

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _pedirNombre(String sugerido) async {
    final t = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: sugerido);
    final r = await showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.nombreCatalogo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: t.campoNombre),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(t.cancelar)),
          ElevatedButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) Navigator.pop(dc, n);
            },
            child: Text(t.subir),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  Future<void> _subir() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    // Free = 1 catalogue. Uploading more requires Pro.
    if (!datos.esPro && datos.catalogos.isNotEmpty) {
      await exigirPro(context);
      return;
    }
    // Accept every file and validate .pdf by hand afterwards (on iOS,
    // filtering by 'pdf' sometimes blocks the picker entirely).
    final archivo = await openFile();
    if (archivo == null || !mounted) return;
    final bytes = await archivo.readAsBytes();
    if (bytes.isEmpty) {
      _aviso(t.errorLeerArchivo);
      return;
    }
    if (!archivo.name.toLowerCase().endsWith('.pdf')) {
      _aviso(t.soloPdf);
      return;
    }
    if (bytes.length > 15 * 1024 * 1024) {
      _aviso(t.archivoSupera15);
      return;
    }
    final sugerido =
        archivo.name.replaceAll('.pdf', '').replaceAll('.PDF', '');
    final nombre = await _pedirNombre(sugerido);
    if (nombre == null || !mounted) return;

    setState(() => subiendo = true);
    try {
      await context.read<DatosApp>().agregarCatalogo(
            nombre: nombre,
            bytes: bytes,
            nombreArchivo: archivo.name,
          );
    } catch (e) {
      _aviso(t.errorSubirCatalogo);
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  Future<void> _abrir(Catalogo c) async {
    final t = AppLocalizations.of(context)!;
    final uri = Uri.parse(c.url);
    // In an installed PWA: try a new tab ('_blank'); if the phone blocks it,
    // open in the same window ('_self').
    var ok = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!ok) {
      ok = await launchUrl(uri, webOnlyWindowName: '_self');
    }
    if (!ok) _aviso(t.errorAbrirCatalogo);
  }

  void _confirmarEliminar(Catalogo c) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.eliminarCatalogoTitulo),
        content: Text(t.eliminarCatalogoConfirmacion(c.nombre)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () async {
              Navigator.pop(dc);
              try {
                await context.read<DatosApp>().eliminarCatalogo(c);
              } catch (e) {
                _aviso(t.errorEliminar);
              }
            },
            child: Text(t.eliminar),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.catalogo)),
      // The employee reads catalogues, but does not upload them.
      floatingActionButton: context.watch<DatosApp>().puedeGestionarCatalogo
          ? FloatingActionButton.extended(
              onPressed: subiendo ? null : _subir,
              icon: subiendo
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(subiendo ? t.subiendo : t.subirPdf),
            )
          : null,
      body: Consumer<DatosApp>(
        builder: (context, datos, child) {
          final m = AppColores.of(context);
          final catalogos = [...datos.catalogos]
            ..sort((a, b) => b.fecha.compareTo(a.fecha));

          if (catalogos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(t.catalogosVacio,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: m.textoSuave)),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: catalogos.map((c) {
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _abrir(c),
                  leading: Container(
                    height: 44,
                    width: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.rojo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf, color: m.rojo),
                  ),
                  title: Text(c.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: m.texto)),
                  subtitle: Text('${c.fecha.day}/${c.fecha.month}/${c.fecha.year}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (op) {
                      if (op == 'abrir') {
                        _abrir(c);
                      } else if (op == 'eliminar') {
                        _confirmarEliminar(c);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'abrir', child: Text(t.abrir)),
                      if (datos.puedeEliminar)
                        PopupMenuItem(
                            value: 'eliminar', child: Text(t.eliminar)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
