import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';

// Screen where a guest joins a business with a code.
class PantallaUnirseCodigo extends StatefulWidget {
  const PantallaUnirseCodigo({super.key});

  @override
  State<PantallaUnirseCodigo> createState() => _PantallaUnirseCodigoState();
}

class _PantallaUnirseCodigoState extends State<PantallaUnirseCodigo> {
  final _ctrl = TextEditingController();
  bool _uniendo = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _mensajeError(AppLocalizations t, String clave) {
    switch (clave) {
      case 'noExiste':
        return t.codigoNoExiste;
      case 'usada':
        return t.codigoUsado;
      case 'invalida':
        return t.codigoInvalido;
      case 'sesion':
        return t.sinSesionValida;
      default:
        return t.unirseError;
    }
  }

  Future<void> _unirse() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final codigo = _ctrl.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.codigoVacio)));
      return;
    }
    setState(() => _uniendo = true);
    final error = await datos.unirsePorCodigo(codigo);
    if (!mounted) return;
    if (error == null) {
      // Compuerta has already rebuilt the app; close this screen.
      Navigator.pop(context);
    } else {
      setState(() => _uniendo = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensajeError(t, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.unirseCodigoTitulo)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.verde.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.vpn_key_outlined,
                        color: m.verde, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(t.unirseCodigoAyuda,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: m.textoSuave)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4),
                    decoration: InputDecoration(
                      labelText: t.codigoInvitacion,
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    ),
                    onSubmitted: (_) => _uniendo ? null : _unirse(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _uniendo ? null : _unirse,
                    child: _uniendo
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(t.unirme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
