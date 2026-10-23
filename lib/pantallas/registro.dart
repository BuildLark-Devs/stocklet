import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../tema.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final correoCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool cargando = false;
  bool verPassword = false;

  @override
  void dispose() {
    correoCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void registrar() async {
    final t = AppLocalizations.of(context)!;
    final correo = correoCtrl.text.trim();
    final password = passwordCtrl.text;
    if (correo.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.registroCompletaCampos)),
      );
      return;
    }
    setState(() => cargando = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );
      if (mounted) Navigator.pop(context); // la compuerta lleva al onboarding
    } on FirebaseAuthException catch (e) {
      String msg = t.registroErrorGeneral;
      if (e.code == 'email-already-in-use') msg = t.registroErrorEnUso;
      if (e.code == 'invalid-email') msg = t.errorCorreoInvalido;
      if (e.code == 'weak-password') msg = t.registroErrorDebil;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Encabezado ---
                  Container(
                    height: 72,
                    width: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.verde.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.person_add_alt_1,
                        color: m.verde, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.crearCuenta,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: m.texto),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.registroSubtitulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: m.textoSuave),
                  ),
                  const SizedBox(height: 32),

                  // --- Card holding the fields ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: correoCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: t.campoCorreo,
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: !verPassword,
                            decoration: InputDecoration(
                              labelText: t.campoContrasena,
                              helperText: t.registroMinimo,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(verPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => verPassword = !verPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: cargando ? null : registrar,
                            child: cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(t.registroBoton),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Volver al login ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.registroYaTienes,
                          style: TextStyle(color: m.textoSuave)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t.iniciaSesion),
                      ),
                    ],
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
