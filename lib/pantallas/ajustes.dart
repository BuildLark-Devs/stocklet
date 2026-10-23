import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reposteria_app/l10n/app_localizations.dart'; // NUEVO // Generated localizations. Adjusted path to package l10n output.
import '../datos_app.dart';
import '../tema.dart';
import 'panel_usuario.dart';
import 'ajustes_seguridad.dart';
import 'notificaciones_config.dart';
import 'apariencia.dart';
import 'miembros_invitaciones.dart';
import 'ajustes_costeo.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  void _confirmarCerrarSesion(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.cerrarSesion),
        content: Text(t.cerrarSesionConfirmacion),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () {
              Navigator.pop(dc);
              FirebaseAuth.instance.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: m.rojo),
            child: Text(t.cerrarSesion),
          ),
        ],
      ),
    );
  }

  Future<void> _acercaDe(BuildContext context) async {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    // Reads the version automatically from pubspec (package_info_plus).
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Stocklet',
      applicationVersion: '${info.version} (${info.buildNumber})',
      applicationIcon: Container(
        height: 48,
        width: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: m.verde.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.storefront, color: m.verde),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(t.acercaDeDescripcion),
        ),
      ],
    );
  }

  void _ir(BuildContext context, Widget destino) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    final m = AppColores.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        height: 40,
        width: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: m.verde.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: m.verde, size: 20),
      ),
      title: Text(titulo,
          style: TextStyle(fontWeight: FontWeight.w600, color: m.texto)),
      subtitle:
          Text(subtitulo, style: TextStyle(fontSize: 12, color: m.textoSuave)),
      trailing: Icon(Icons.chevron_right, color: m.textoSuave),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final datos = context.watch<DatosApp>();
    final negocio = datos.negocio;

    return Scaffold(
      appBar: AppBar(title: Text(t.ajustesTitulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  height: 72,
                  width: 72,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m.verde.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: (negocio?.logoUrl ?? '').isEmpty
                      ? Icon(Icons.storefront, color: m.verde, size: 36)
                      : Image.network(
                          negocio!.logoUrl,
                          height: 72,
                          width: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(Icons.storefront,
                              color: m.verde, size: 36),
                        ),
                ),
                const SizedBox(height: 12),
                Text(negocio?.nombre ?? t.miNegocio,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: m.texto)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _opcion(
                  context,
                  icono: Icons.person_outline,
                  titulo: t.perfil,
                  subtitulo: t.perfilSubtitulo,
                  onTap: () => _ir(context, const PantallaPanelUsuario()),
                ),
                const Divider(height: 1),
                _opcion(
                  context,
                  icono: Icons.business_outlined,
                  titulo: t.datosEmpresa,
                  subtitulo: t.datosEmpresaSubtitulo,
                  onTap: () => _ir(context, const PantallaPanelUsuario()),
                ),
                const Divider(height: 1),
                _opcion(
                  context,
                  icono: Icons.notifications_outlined,
                  titulo: t.notificaciones,
                  subtitulo: t.notificacionesSubtitulo,
                  onTap: () =>
                      _ir(context, const PantallaNotificacionesConfig()),
                ),
                if (datos.puedeGestionarCatalogo) ...[
                  const Divider(height: 1),
                  _opcion(
                    context,
                    icono: Icons.calculate_outlined,
                    titulo: t.ajustesCosteoTitulo,
                    subtitulo: t.ajustesCosteoSub,
                    onTap: () => _ir(context, const PantallaAjustesCosteo()),
                  ),
                ],
                const Divider(height: 1),
                _opcion(
                  context,
                  icono: Icons.shield_outlined,
                  titulo: t.ajustesSeguridad,
                  subtitulo: t.ajustesSeguridadSubtitulo,
                  onTap: () => _ir(context, const PantallaAjustesSeguridad()),
                ),
                if (datos.esDueno) ...[
                  const Divider(height: 1),
                  _opcion(
                    context,
                    icono: Icons.group_outlined,
                    titulo: t.miembrosInvitaciones,
                    subtitulo: t.miembrosInvitacionesSub,
                    onTap: () => _ir(context, const PantallaMiembros()),
                  ),
                ],
                const Divider(height: 1),
                _opcion(
                  context,
                  icono: Icons.palette_outlined,
                  titulo: t.apariencia,
                  subtitulo: t.aparienciaSubtitulo,
                  onTap: () => _ir(context, const PantallaApariencia()),
                ),
                const Divider(height: 1),
                _opcion(
                  context,
                  icono: Icons.info_outline,
                  titulo: t.acercaDe,
                  subtitulo: t.acercaDeSubtitulo,
                  onTap: () => _acercaDe(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmarCerrarSesion(context),
            icon: const Icon(Icons.logout),
            label: Text(t.cerrarSesion),
            style: OutlinedButton.styleFrom(
              foregroundColor: m.rojo,
              side: BorderSide(color: m.rojo),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
