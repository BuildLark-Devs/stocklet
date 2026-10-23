import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/catalogo.dart';
import '../tema.dart';
import '../formato.dart';
import 'editar_producto.dart';
import 'editar_insumo.dart';
import 'editar_pedido.dart';
import 'ver_receta.dart';

// Global search from the home screen: searches products, supplies, orders,
// recipes and catalogues, and jumps to the screen of each result.
class PantallaBuscador extends StatefulWidget {
  const PantallaBuscador({super.key});

  @override
  State<PantallaBuscador> createState() => _PantallaBuscadorState();
}

class _PantallaBuscadorState extends State<PantallaBuscador> {
  final _ctrl = TextEditingController();
  String _consulta = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _abrirCatalogo(Catalogo c) async {
    final t = AppLocalizations.of(context)!;
    final uri = Uri.parse(c.url);
    var ok = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!ok) ok = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.errorAbrirCatalogo)),
      );
    }
  }

  void _ir(Widget destino) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final datos = context.watch<DatosApp>();
    final q = sinTildes(_consulta.trim());
    bool coincide(String s) => sinTildes(s).contains(q);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.buscadorHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _consulta = v),
        ),
        actions: [
          if (_consulta.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctrl.clear();
                setState(() => _consulta = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 48, color: m.textoSuave),
                    const SizedBox(height: 12),
                    Text(t.buscadorInicio,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: m.textoSuave)),
                  ],
                ),
              ),
            )
          : _resultados(context, t, m, datos, q, coincide),
    );
  }

  Widget _resultados(BuildContext context, AppLocalizations t, MarcaColores m,
      DatosApp datos, String q, bool Function(String) coincide) {
    // Filtrado por tipo
    final productos = datos.productos
        .where((p) => coincide(p.nombre) || coincide(p.tipo))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final insumos = datos.insumos.where((i) => coincide(i.nombre)).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final pedidos = datos.pedidos
        .where((p) => coincide(p.cliente.nombre) || coincide(p.descripcion))
        .toList()
      ..sort((a, b) => b.fechaEntrega.compareTo(a.fechaEntrega));
    final recetas = datos.recetas.where((r) => coincide(r.titulo)).toList()
      ..sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    final catalogos = datos.catalogos.where((c) => coincide(c.nombre)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final vacio = productos.isEmpty &&
        insumos.isEmpty &&
        pedidos.isEmpty &&
        recetas.isEmpty &&
        catalogos.isEmpty;

    if (vacio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t.buscadorSinResultados(_consulta.trim()),
              textAlign: TextAlign.center,
              style: TextStyle(color: m.textoSuave)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _seccion(m, t.productos, [
          for (final p in productos)
            _item(
              m,
              Icons.shopping_bag_outlined,
              p.nombre,
              p.tipo.trim().isEmpty
                  ? pesos(p.precioVenta)
                  : '${p.tipo}  ·  ${pesos(p.precioVenta)}',
              () => _ir(PantallaEditarProducto(producto: p)),
            ),
        ]),
        _seccion(m, t.inventario, [
          for (final i in insumos)
            _item(
              m,
              Icons.category_outlined,
              i.nombre,
              t.stockTexto(cantidadStr(i.stockActual), i.unidad),
              () => _ir(PantallaEditarInsumo(insumo: i)),
            ),
        ]),
        _seccion(m, t.pedidos, [
          for (final p in pedidos)
            _item(
              m,
              Icons.receipt_long_outlined,
              p.cliente.nombre,
              p.descripcion,
              () => _ir(PantallaEditarPedido(pedido: p)),
            ),
        ]),
        _seccion(m, t.recetas, [
          for (final r in recetas)
            _item(
              m,
              Icons.menu_book_outlined,
              r.titulo,
              t.recetaSubtitulo(r.ingredientes.length, r.pasos.length),
              () => _ir(PantallaVerReceta(receta: r)),
            ),
        ]),
        _seccion(m, t.catalogo, [
          for (final c in catalogos)
            _item(
              m,
              Icons.picture_as_pdf_outlined,
              c.nombre,
              '${c.fecha.day}/${c.fecha.month}/${c.fecha.year}',
              () => _abrirCatalogo(c),
            ),
        ]),
      ],
    );
  }

  Widget _seccion(MarcaColores m, String titulo, List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: Text(titulo,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: m.textoSuave)),
        ),
        ...items,
      ],
    );
  }

  Widget _item(MarcaColores m, IconData icono, String titulo, String subtitulo,
      VoidCallback onTap) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: m.texto)),
        subtitle: subtitulo.trim().isEmpty
            ? null
            : Text(subtitulo,
                maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: m.textoSuave),
      ),
    );
  }
}
