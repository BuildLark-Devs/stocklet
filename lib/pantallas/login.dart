import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../tema.dart';
import 'registro.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final correoCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool cargando = false;
  bool verPassword = false;
  bool recordar = true;

  @override
  void initState() {
    super.initState();
    _cargarCorreoRecordado();
  }

  // On opening the login screen, pull the last saved email (if any)
  Future<void> _cargarCorreoRecordado() async {
    final prefs = await SharedPreferences.getInstance();
    final recordarGuardado = prefs.getBool('recordarCorreo') ?? true;
    final correoGuardado = prefs.getString('correoRecordado');
    if (!mounted) return;
    setState(() {
      recordar = recordarGuardado;
      if (recordarGuardado && correoGuardado != null) {
        correoCtrl.text = correoGuardado;
      }
    });
  }

  @override
  void dispose() {
    correoCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void iniciarSesion() async {
    final t = AppLocalizations.of(context)!;
    final correo = correoCtrl.text.trim();
    final password = passwordCtrl.text;
    if (correo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.loginCompletaCampos)),
      );
      return;
    }
    setState(() => cargando = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );
      // Save (or clear) the remembered email according to the checkbox
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('recordarCorreo', recordar);
      if (recordar) {
        await prefs.setString('correoRecordado', correo);
      } else {
        await prefs.remove('correoRecordado');
      }
      // the gate takes care of getting into the app
    } on FirebaseAuthException catch (e) {
      String msg = t.loginErrorGeneral;
      if (e.code == 'invalid-email') msg = t.errorCorreoInvalido;
      if (e.code == 'user-not-found') msg = t.loginErrorNoExiste;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = t.loginErrorCredenciales;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _recuperar() async {
    final t = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: correoCtrl.text.trim());
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.recuperarContrasenaTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.recuperarContrasenaAyuda),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: t.campoCorreo,
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(t.cancelar)),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(t.enviar)),
        ],
      ),
    );
    final correo = ctrl.text.trim();
    ctrl.dispose();
    if (enviar != true || !mounted) return;
    if (correo.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.correoVacio)));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email' && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.errorCorreoInvalido)));
        return;
      }
      // Other cases (user-not-found, say): for safety we do not reveal whether
      // the email exists; the generic message below is shown instead.
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.correoRecuperacionEnviado)));
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/icon/stocklet_icon.png',
                      height: 88,
                      width: 88,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.loginBienvenido,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: m.texto),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.loginSubtitulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: m.textoSuave),
                  ),
                  const SizedBox(height: 32),
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Checkbox(
                                value: recordar,
                                onChanged: (v) =>
                                    setState(() => recordar = v ?? false),
                              ),
                              Expanded(child: Text(t.loginRecordarCorreo)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: cargando ? null : iniciarSesion,
                            child: cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(t.iniciarSesion),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _recuperar,
                              child: Text(t.olvidasteContrasena),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.loginEresNuevo,
                          style: TextStyle(color: m.textoSuave)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PantallaRegistro()),
                          );
                        },
                        child: Text(t.crearCuenta),
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
