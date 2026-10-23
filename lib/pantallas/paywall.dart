import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../servicios/suscripcion_service.dart';
import '../tema.dart';

// This screen is only used when SuscripcionService.activa = true.
class PantallaPaywall extends StatefulWidget {
  const PantallaPaywall({super.key});

  @override
  State<PantallaPaywall> createState() => _PantallaPaywallState();
}

class _PantallaPaywallState extends State<PantallaPaywall> {
  List<Package> _paquetes = [];
  bool _cargando = true;
  bool _comprando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await SuscripcionService.instance.paquetes();
    if (!mounted) return;
    setState(() {
      _paquetes = p;
      _cargando = false;
    });
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _comprar(Package paquete) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _comprando = true);
    final err = await SuscripcionService.instance.comprar(paquete);
    if (!mounted) return;
    setState(() => _comprando = false);
    if (err == null) {
      _aviso(t.yaEresPro);
      Navigator.pop(context);
    } else if (err != 'cancelado') {
      _aviso(t.errorCompra);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    final beneficios = <(IconData, String, String)>[
      (Icons.groups_outlined, t.proEquipo, t.proEquipoDesc),
      (Icons.history, t.proHistorial, t.proHistorialDesc),
      (Icons.insights_outlined, t.proReportes, t.proReportesDesc),
      (Icons.picture_as_pdf_outlined, t.proCatalogos, ''),
      (Icons.store_outlined, t.proNegocios, ''),
      (Icons.download_outlined, t.proExportar, ''),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Stocklet Pro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/icon/stocklet_icon.png',
                      height: 84, width: 84),
                ),
                const SizedBox(height: 14),
                Text(t.paywallTitulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: m.texto)),
                const SizedBox(height: 4),
                Text(t.paywallSubtitulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: m.textoSuave)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...beneficios.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(b.$1, color: m.verde, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.$2,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: m.texto)),
                          if (b.$3.isNotEmpty)
                            Text(b.$3,
                                style: TextStyle(
                                    fontSize: 12, color: m.textoSuave)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 20),
          if (_cargando)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
          else if (_paquetes.isNotEmpty)
            ..._paquetes.map((p) => _tarjetaPaquete(m, t, p))
          else
            _planesEstaticos(m, t),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => SuscripcionService.instance.restaurar(),
              child: Text(t.restaurarCompras),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPaquete(MarcaColores m, AppLocalizations t, Package p) {
    final anual = p.packageType == PackageType.annual;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(anual ? t.planAnual : t.planMensual,
            style: TextStyle(fontWeight: FontWeight.w600, color: m.texto)),
        subtitle: anual
            ? Text(t.dosMesesGratis, style: TextStyle(color: m.textoSuave))
            : null,
        trailing: ElevatedButton(
          onPressed: _comprando ? null : () => _comprar(p),
          child: Text(p.storeProduct.priceString),
        ),
      ),
    );
  }

  Widget _planesEstaticos(MarcaColores m, AppLocalizations t) {
    Widget fila(String titulo, String precio, String extra) => Card(
          child: ListTile(
            title: Text(titulo,
                style: TextStyle(fontWeight: FontWeight.w600, color: m.texto)),
            subtitle: Text(extra, style: TextStyle(color: m.textoSuave)),
            trailing: Text(precio,
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: m.verde)),
          ),
        );
    return Column(
      children: [
        fila(t.planMensual, 'COP \$29.900', t.porMes),
        fila(t.planAnual, 'COP \$299.000', t.porAnioDescuento),
        const SizedBox(height: 8),
        Text(t.pagosPronto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: m.textoSuave)),
      ],
    );
  }
}
