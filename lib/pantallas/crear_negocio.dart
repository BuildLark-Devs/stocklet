import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../tema.dart';
import 'unirse_codigo.dart';

class PantallaCrearNegocio extends StatefulWidget {
  const PantallaCrearNegocio({super.key});

  @override
  State<PantallaCrearNegocio> createState() => _PantallaCrearNegocioState();
}

class _PantallaCrearNegocioState extends State<PantallaCrearNegocio> {
  final nombreCtrl = TextEditingController();

  String paisCodigo = 'CO';
  String paisNombre = 'Colombia';
  String moneda = 'COP';
  String monedaTexto = 'Peso colombiano (COP)';
  String idioma = 'es';
  bool creando = false;

  // Supported languages (autonyms, not translated). Matches the .arb files.
  static const idiomas = {
    'es': 'Español',
    'en': 'English',
    'pt': 'Português',
    'fr': 'Français',
  };

  // Currency suggested per country (others are picked in the currency selector)
  static const monedaPorPais = {
    'CO': 'COP', 'MX': 'MXN', 'AR': 'ARS', 'PE': 'PEN', 'CL': 'CLP',
    'EC': 'USD', 'VE': 'VES', 'BO': 'BOB', 'PY': 'PYG', 'UY': 'UYU',
    'BR': 'BRL', 'US': 'USD', 'CA': 'CAD', 'GB': 'GBP', 'PA': 'USD',
    'GT': 'GTQ', 'CR': 'CRC', 'HN': 'HNL', 'NI': 'NIO', 'SV': 'USD',
    'DO': 'DOP', 'ES': 'EUR', 'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'PT': 'EUR',
  };

  @override
  void initState() {
    super.initState();
    // Prefills with the language the app is already in (if the user chose one).
    final actual = context.read<DatosApp>().idiomaId;
    if (actual != null && idiomas.containsKey(actual)) idioma = actual;
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    super.dispose();
  }

  void _elegirPais() {
    final t = AppLocalizations.of(context)!;
    showCountryPicker(
      context: context,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: InputDecoration(
          labelText: t.onboardingBuscarPais,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          paisCodigo = country.countryCode;
          paisNombre = country.name;
          final sugerida = monedaPorPais[country.countryCode];
          if (sugerida != null) {
            moneda = sugerida;
            final c = CurrencyService().findByCode(sugerida);
            monedaTexto = c != null ? '${c.name} (${c.code})' : sugerida;
          }
        });
      },
    );
  }

  void _elegirMoneda() {
    showCurrencyPicker(
      context: context,
      onSelect: (Currency currency) {
        setState(() {
          moneda = currency.code;
          monedaTexto = '${currency.name} (${currency.code})';
        });
      },
    );
  }

  void crear() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.onboardingNombreVacio)),
      );
      return;
    }
    setState(() => creando = true);
    try {
      await datos.crearNegocio(
        nombre: nombre, pais: paisCodigo, moneda: moneda, idioma: idioma,
      );
      // The language chosen when creating the business also changes the UI.
      await datos.setIdioma(idioma);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.errorGenerico(e.toString()))));
        setState(() => creando = false);
      }
    }
  }

  // A field that looks like an input but opens a picker on tap
  Widget _campoTap({
    required IconData icono,
    required String etiqueta,
    required String valor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(valor, style: const TextStyle(fontSize: 16)),
      ),
    );
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 72, width: 72, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.verde.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.storefront, color: m.verde, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(t.onboardingBienvenido,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: m.texto)),
                  const SizedBox(height: 6),
                  Text(
                    t.onboardingSubtitulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: m.textoSuave),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: nombreCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: t.onboardingNombreNegocio,
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _campoTap(
                            icono: Icons.public,
                            etiqueta: t.campoPais,
                            valor: paisNombre,
                            onTap: _elegirPais,
                          ),
                          const SizedBox(height: 16),
                          _campoTap(
                            icono: Icons.payments_outlined,
                            etiqueta: t.campoMoneda,
                            valor: monedaTexto,
                            onTap: _elegirMoneda,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: idioma,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: t.idioma,
                              prefixIcon: const Icon(Icons.translate),
                            ),
                            items: idiomas.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (v) => setState(() => idioma = v!),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: creando ? null : crear,
                            child: creando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(t.onboardingCrearBoton),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PantallaUnirseCodigo())),
                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                    label: Text(t.unirseCodigo),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(t.cerrarSesion),
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
