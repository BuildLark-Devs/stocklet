import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';
import '../servicios/gate_pro.dart';

class PantallaMiembros extends StatefulWidget {
  const PantallaMiembros({super.key});

  @override
  State<PantallaMiembros> createState() => _PantallaMiembrosState();
}

class _PantallaMiembrosState extends State<PantallaMiembros> {
  bool _cargando = true;
  List<Invitacion> _invitaciones = [];
  List<MiembroNegocio> _miembros = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final datos = context.read<DatosApp>();
    setState(() => _cargando = true);
    final inv = await datos.cargarInvitaciones();
    final mem = await datos.cargarMiembros();
    if (!mounted) return;
    setState(() {
      _invitaciones = inv;
      _miembros = mem;
      _cargando = false;
    });
  }

  String _rolNombre(AppLocalizations t, String rol) {
    switch (rol) {
      case 'dueno':
        return t.rolDueno;
      case 'socio':
        return t.rolSocio;
      default:
        return t.rolEmpleado;
    }
  }

  Future<void> _generar() async {
    // Pro feature: inviting a team. If not Pro, open the paywall.
    if (!await exigirPro(context) || !mounted) return;
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final rol = await showDialog<String>(
      context: context,
      builder: (dc) => SimpleDialog(
        title: Text(t.elegirRolInvitacion),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 'socio'),
            child: Text(t.rolSocio),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 'empleado'),
            child: Text(t.rolEmpleado),
          ),
        ],
      ),
    );
    if (rol == null || !mounted) return;
    final codigo = await datos.crearInvitacion(rol);
    if (!mounted) return;
    await _mostrarCodigo(codigo);
    await _cargar();
  }

  Future<void> _mostrarCodigo(String codigo) async {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.invitacionCreada),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: m.verde.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                codigo,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: m.verdeOscuro),
              ),
            ),
            const SizedBox(height: 12),
            Text(t.compartirCodigoAyuda,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: m.textoSuave)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.copiado)),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(t.copiar),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarRol(MiembroNegocio miembro) async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final rol = await showDialog<String>(
      context: context,
      builder: (dc) => SimpleDialog(
        title: Text(t.cambiarRolTitulo),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 'socio'),
            child: Text(t.rolSocio),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 'empleado'),
            child: Text(t.rolEmpleado),
          ),
        ],
      ),
    );
    if (rol == null || !mounted) return;
    await datos.cambiarRolMiembro(miembro.uid, rol);
    await _cargar();
  }

  Future<void> _quitar(MiembroNegocio miembro) async {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.read<DatosApp>();
    final nombre =
        miembro.nombre.isEmpty ? t.sinNombre : miembro.nombre;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(t.quitarDelNegocio),
        content: Text(t.quitarMiembroConfirmacion(nombre)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(t.cancelar)),
          TextButton(
            onPressed: () => Navigator.pop(dc, true),
            style: TextButton.styleFrom(foregroundColor: m.rojo),
            child: Text(t.quitarDelNegocio),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await datos.quitarMiembro(miembro.uid);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.miembrosInvitaciones)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Invitaciones ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.invitacionesTitulo,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: m.texto)),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _generar,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(t.generarInvitacion),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_invitaciones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t.sinInvitaciones,
                          style: TextStyle(color: m.textoSuave)),
                    )
                  else
                    ..._invitaciones.map((inv) {
                      final pendiente = inv.estado == 'pendiente';
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.vpn_key_outlined,
                              color: pendiente ? m.verde : m.textoSuave),
                          title: Text(inv.codigo,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                          subtitle: Text(
                              '${_rolNombre(t, inv.rol)}  ·  ${pendiente ? t.invitacionPendiente : t.invitacionUsada}'),
                          trailing: pendiente
                              ? IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: m.rojo),
                                  tooltip: t.revocar,
                                  onPressed: () async {
                                    await context
                                        .read<DatosApp>()
                                        .revocarInvitacion(inv.codigo);
                                    await _cargar();
                                  },
                                )
                              : null,
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // --- Miembros ---
                  Text(t.miembrosTitulo,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: m.texto)),
                  const SizedBox(height: 8),
                  if (_miembros.where((x) => x.rol != 'dueno').isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t.sinMiembros,
                          style: TextStyle(color: m.textoSuave)),
                    ),
                  ..._miembros.map((miembro) {
                    final esDueno = miembro.rol == 'dueno';
                    return Card(
                      child: ListTile(
                        leading: Container(
                          height: 40,
                          width: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: m.verde.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, color: m.verde, size: 20),
                        ),
                        title: Text(
                            miembro.nombre.isEmpty
                                ? t.sinNombre
                                : miembro.nombre,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: m.texto)),
                        subtitle: Text(_rolNombre(t, miembro.rol)),
                        trailing: esDueno
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (op) {
                                  if (op == 'rol') {
                                    _cambiarRol(miembro);
                                  } else if (op == 'quitar') {
                                    _quitar(miembro);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'rol',
                                      child: Text(t.cambiarRolTitulo)),
                                  PopupMenuItem(
                                      value: 'quitar',
                                      child: Text(t.quitarDelNegocio)),
                                ],
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
