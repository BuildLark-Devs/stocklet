import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import 'datos_app.dart';
import 'tema.dart';
import 'pantallas/login.dart';
import 'pantallas/crear_negocio.dart';
import 'pantallas/principal.dart';

class Compuerta extends StatelessWidget {
  const Compuerta({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<DatosApp>().estado;
    switch (estado) {
      case EstadoApp.cargando:
        return const _PantallaCargando();
      case EstadoApp.sinSesion:
        return const PantallaLogin();
      case EstadoApp.sinNegocio:
        return const PantallaCrearNegocio();
      case EstadoApp.listo:
        return const PantallaPrincipal();
    }
  }
}

// Loading screen: the Stocklet icon as a faint full-screen backdrop, with the
// sharp icon, the "Loading your business" message and a spinner.
class _PantallaCargando extends StatelessWidget {
  const _PantallaCargando();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen backdrop icon, very faint.
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/icon/stocklet_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Contenido central.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/icon/stocklet_icon.png',
                    height: 108,
                    width: 108,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  t.cargandoNegocio,
                  style: TextStyle(fontSize: 16, color: m.textoSuave),
                ),
                const SizedBox(height: 22),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}