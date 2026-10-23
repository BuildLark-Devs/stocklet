import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';
import 'cambiar_contrasena.dart';

// Each language name in its own language (autonyms). Not translated.
const Map<String, String> kNombresIdioma = {
  'es': 'Español',
  'en': 'English',
  'pt': 'Português',
  'fr': 'Français',
};

class PantallaAjustesSeguridad extends StatelessWidget {
  const PantallaAjustesSeguridad({super.key});

  // App language picker (a GLOBAL device preference).
  void _elegirIdioma(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final actual = datos.idiomaId; // null = automático

    showDialog(
      context: context,
      builder: (dc) {
        return AlertDialog(
          title: Text(t.idiomaTituloDialogo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Automatic option: follows the device language.
              ListTile(
                leading: Icon(
                  actual == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(t.idiomaAutomatico),
                onTap: () {
                  datos.setIdioma(null);
                  Navigator.pop(dc);
                },
              ),
              // One item per available language.
              ...kNombresIdioma.entries.map(
                (e) => ListTile(
                  leading: Icon(
                    actual == e.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(e.value),
                  onTap: () {
                    datos.setIdioma(e.key);
                    Navigator.pop(dc);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(t.cancelar),
            ),
          ],
        );
      },
    );
  }

  Widget _fila(MarcaColores m, IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icono, size: 20, color: m.textoSuave),
          const SizedBox(width: 12),
          Text(etiqueta, style: TextStyle(color: m.textoSuave)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: m.texto, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.read<DatosApp>();

    // 1) Warning (stronger for the owner: it wipes the whole business).
    final seguir = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.eliminarCuenta),
        content: Text(datos.esDueno
            ? t.eliminarCuentaAdvertenciaDueno
            : t.eliminarCuentaAdvertencia),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () => Navigator.pop(dc, true),
            style: TextButton.styleFrom(foregroundColor: m.rojo),
            child: Text(t.continuar),
          ),
        ],
      ),
    );
    if (seguir != true || !context.mounted) return;

    // 2) Reauthentication: ask for the password.
    final passCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.eliminarCuenta),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.ingresaContrasenaEliminar),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.campoContrasena,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () => Navigator.pop(dc, true),
            style: TextButton.styleFrom(foregroundColor: m.rojo),
            child: Text(t.eliminarCuentaConfirmar),
          ),
        ],
      ),
    );
    final password = passCtrl.text;
    passCtrl.dispose();
    if (confirmar != true || !context.mounted) return;

    // 3) Run it with a loading indicator.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await datos.eliminarCuenta(password);
    if (!context.mounted) return;
    Navigator.pop(context); // cierra el indicador de carga
    if (error == null) {
      // Success: the session is already closed; back to the start (login).
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    final msg = error == 'password'
        ? t.passwordActualIncorrecta
        : t.errorEliminarCuenta;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final datos = context.watch<DatosApp>();
    final negocio = datos.negocio;
    final cur =
        negocio != null ? CurrencyService().findByCode(negocio.moneda) : null;
    final monedaTexto =
        cur != null ? '${cur.name} (${cur.code})' : (negocio?.moneda ?? '-');
    // App language: a global preference (not negocio.idioma).
    final idiomaApp = datos.idiomaId == null
        ? t.idiomaAutomatico
        : (kNombresIdioma[datos.idiomaId] ?? datos.idiomaId!);

    return Scaffold(
      appBar: AppBar(title: Text(t.ajustesSeguridad)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.preferenciasNegocio,
              style: TextStyle(fontWeight: FontWeight.bold, color: m.texto)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _fila(m, Icons.public, t.campoPais, negocio?.pais ?? '-'),
                  const Divider(height: 1),
                  _fila(m, Icons.payments_outlined, t.campoMoneda, monedaTexto),
                  const Divider(height: 1),
                  // Editable Language row: opens the app language picker.
                  InkWell(
                    onTap: () => _elegirIdioma(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.translate, size: 20, color: m.textoSuave),
                          const SizedBox(width: 12),
                          Text(t.idioma, style: TextStyle(color: m.textoSuave)),
                          const Spacer(),
                          Flexible(
                            child: Text(idiomaApp,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: m.texto,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right,
                              size: 20, color: m.textoSuave),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(t.ajustesSeguridadCaption,
                style: TextStyle(fontSize: 12, color: m.textoSuave)),
          ),
          const SizedBox(height: 24),
          Text(t.seguridad,
              style: TextStyle(fontWeight: FontWeight.bold, color: m.texto)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PantallaCambiarContrasena())),
                  leading: Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.verde.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_outline, color: m.verde, size: 20),
                  ),
                  title: Text(t.cambiarContrasena,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: m.texto)),
                  trailing: Icon(Icons.chevron_right, color: m.textoSuave),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _eliminarCuenta(context),
                  leading: Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.rojo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.delete_forever_outlined, color: m.rojo, size: 20),
                  ),
                  title: Text(t.eliminarCuenta,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: m.rojo)),
                  trailing: Icon(Icons.chevron_right, color: m.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}