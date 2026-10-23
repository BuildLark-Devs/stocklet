import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../datos_app.dart';
import '../pantallas/paywall.dart';

/// Gate for access to Pro features.
///
/// If the user is already Pro (or monetisation is inactive → `esPro` = true),
/// returns `true` right away. Otherwise it opens the paywall and returns
/// `true` only if the user is Pro on the way back (that is, if they bought).
///
/// Typical use:
///   if (!await exigirPro(context) || !mounted) return;
Future<bool> exigirPro(BuildContext context) async {
  if (context.read<DatosApp>().esPro) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PantallaPaywall()),
  );
  return context.mounted && context.read<DatosApp>().esPro;
}
