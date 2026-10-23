import 'package:flutter/material.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../../costeo.dart';
import '../../tema.dart';
import '../../formato.dart';

class DesgloseCosteo extends StatelessWidget {
  final ResultadoCosteo r;
  final VoidCallback? onUsarSugerido;
  final VoidCallback? onCompletarFijos;
  const DesgloseCosteo({
    super.key,
    required this.r,
    this.onUsarSugerido,
    this.onCompletarFijos,
  });

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;

    Widget fila(String etq, double v, {bool fuerte = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(etq,
                  style: TextStyle(
                      fontSize: 13,
                      color: fuerte ? m.texto : m.textoSuave,
                      fontWeight: fuerte ? FontWeight.bold : FontWeight.normal)),
              Text(pesos(v),
                  style: TextStyle(
                      fontSize: 13,
                      color: fuerte ? m.texto : m.textoSuave,
                      fontWeight: fuerte ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );

    return Card(
      color: m.verde.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fila(t.costeoMateriaPrima, r.materiaUnidad),
            if (r.empaqueUnidad > 0) fila(t.costeoEmpaque, r.empaqueUnidad),
            if (r.manoObraUnidad > 0) fila(t.costeoManoObra, r.manoObraUnidad),
            if (r.energiaUnidad > 0) fila(t.costeoEnergia, r.energiaUnidad),
            if (r.fijosUnidad > 0) fila(t.costeoGastosFijos, r.fijosUnidad),
            const Divider(height: 18),
            fila(t.costeoCostoUnidad, r.costoUnidad, fuerte: true),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.costeoPrecioSugerido,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: m.verde)),
                Text(pesos(r.precioSugerido),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: m.verde)),
              ],
            ),
            if (onUsarSugerido != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onUsarSugerido,
                  child: Text(t.costeoUsarSugerido),
                ),
              ),
            ],
            if (r.fijosIncompletos) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: m.rojo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.costeoFijosIncompletos,
                          style: TextStyle(fontSize: 12, color: m.textoSuave)),
                    ),
                    if (onCompletarFijos != null)
                      TextButton(
                        onPressed: onCompletarFijos,
                        child: Text(t.costeoCompletar),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Price status chip (loss / below / fine).
class ChipEstadoPrecio extends StatelessWidget {
  final EstadoPrecio estado;
  const ChipEstadoPrecio({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final m = AppColores.of(context);
    final t = AppLocalizations.of(context)!;
    String texto;
    Color color;
    switch (estado) {
      case EstadoPrecio.perdida:
        texto = t.estadoPerdida;
        color = m.rojo;
        break;
      case EstadoPrecio.bajo:
        texto = t.estadoBajo;
        color = const Color(0xFFEA580C);
        break;
      case EstadoPrecio.bien:
        texto = t.estadoBien;
        color = m.verde;
        break;
      case EstadoPrecio.sinPrecio:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
