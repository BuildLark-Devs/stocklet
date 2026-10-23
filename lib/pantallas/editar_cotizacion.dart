import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../datos_app.dart';
import '../models/cotizacion.dart';
import '../tema.dart';
import '../formato.dart';
import 'selector_producto.dart';
import 'cotizacion_util.dart';
import 'widgets/dialogo_convertir_pedido.dart';

class _LineaEdit {
  final LineaCotizacion linea;
  final TextEditingController cant;
  final TextEditingController precio;
  _LineaEdit(this.linea)
      : cant = TextEditingController(text: cantidadStr(linea.cantidad)),
        precio = TextEditingController(text: cantidadStr(linea.precioUnitario));
}

class _AdicEdit {
  final AdicionCotizacion adic;
  final TextEditingController nombre;
  final TextEditingController valor;
  _AdicEdit(this.adic)
      : nombre = TextEditingController(text: adic.nombre),
        valor = TextEditingController(
            text: adic.valor != 0 ? cantidadStr(adic.valor) : '');
}

class EditarCotizacion extends StatefulWidget {
  final Cotizacion cotizacion;
  const EditarCotizacion({super.key, required this.cotizacion});

  @override
  State<EditarCotizacion> createState() => _EditarCotizacionState();
}

class _EditarCotizacionState extends State<EditarCotizacion> {
  late final TextEditingController clienteCtrl;
  late final TextEditingController notaCtrl;
  late final TextEditingController domicilioCtrl;
  late final TextEditingController descuentoCtrl;
  late final TextEditingController ivaCtrl;
  late DateTime fecha;
  late String estado;
  late bool aplicaIva;
  final List<_LineaEdit> lineas = [];
  final List<_AdicEdit> adiciones = [];

  @override
  void initState() {
    super.initState();
    final c = widget.cotizacion;
    clienteCtrl = TextEditingController(text: c.cliente);
    notaCtrl = TextEditingController(text: c.notas);
    domicilioCtrl =
        TextEditingController(text: c.domicilio != 0 ? cantidadStr(c.domicilio) : '');
    descuentoCtrl =
        TextEditingController(text: c.descuento != 0 ? cantidadStr(c.descuento) : '');
    ivaCtrl = TextEditingController(text: cantidadStr(c.tasaIva));
    fecha = c.fecha;
    estado = c.estado;
    aplicaIva = c.aplicaIva;
    for (final l in c.lineas) {
      lineas.add(_LineaEdit(LineaCotizacion(
          nombre: l.nombre,
          precioUnitario: l.precioUnitario,
          cantidad: l.cantidad,
          productoId: l.productoId)));
    }
    for (final a in c.adiciones) {
      adiciones.add(_AdicEdit(AdicionCotizacion(nombre: a.nombre, valor: a.valor)));
    }
    for (final ctrl in [domicilioCtrl, descuentoCtrl, ivaCtrl]) {
      ctrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [clienteCtrl, notaCtrl, domicilioCtrl, descuentoCtrl, ivaCtrl]) {
      c.dispose();
    }
    for (final l in lineas) {
      l.cant.dispose();
      l.precio.dispose();
    }
    for (final a in adiciones) {
      a.nombre.dispose();
      a.valor.dispose();
    }
    super.dispose();
  }

  Cotizacion _construir() {
    return Cotizacion(
      id: widget.cotizacion.id,
      cliente: clienteCtrl.text.trim(),
      fecha: fecha,
      estado: estado,
      lineas: lineas
          .map((e) => LineaCotizacion(
                nombre: e.linea.nombre,
                precioUnitario: parseCantidad(e.precio.text),
                cantidad: parseCantidad(e.cant.text),
                productoId: e.linea.productoId,
              ))
          .toList(),
      adiciones: adiciones
          .map((e) => AdicionCotizacion(
                nombre: e.nombre.text.trim(),
                valor: parseCantidad(e.valor.text),
              ))
          .toList(),
      domicilio: parseCantidad(domicilioCtrl.text),
      descuento: parseCantidad(descuentoCtrl.text),
      aplicaIva: aplicaIva,
      tasaIva: parseCantidad(ivaCtrl.text),
      notas: notaCtrl.text.trim(),
      // Carried over as is: without this, editing an already-converted quote
      // would clear the link and allow a second order.
      pedidoId: widget.cotizacion.pedidoId,
    );
  }

  Future<void> _agregarProducto() async {
    final datos = context.read<DatosApp>();
    final productos = [...datos.productos]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final p = await elegirProducto(context, productos);
    if (p != null && mounted) {
      setState(() {
        lineas.add(_LineaEdit(LineaCotizacion(
            nombre: p.nombre,
            precioUnitario: p.precioVenta,
            cantidad: 1,
            productoId: p.id)));
      });
    }
  }

  Future<void> _guardar() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final cotizacion = _construir();
    datos.guardarCotizacion(cotizacion);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.cotizaGuardada)));

    // If it has just been accepted and has no order yet, offer to create one
    // right here: this is the moment where the work used to be duplicated.
    if (cotizacion.estado == 'aceptada' && !cotizacion.convertida) {
      await _ofrecerConvertir(cotizacion);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _ofrecerConvertir(Cotizacion cotizacion) async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();

    // A quote with nothing to charge cannot become an order.
    if (cotizacion.lineas.isEmpty && cotizacion.total <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.convertirSinLineas)));
      return;
    }

    final r = await mostrarDialogoConvertirPedido(context, cotizacion);
    // Cancelling writes nothing: the quote stays accepted and without an order.
    if (r == null || !mounted) return;

    final pedido = datos.convertirCotizacionEnPedido(
      cotizacion,
      telefono: r.telefono,
      fechaEntrega: r.fechaEntrega,
      descripcionFallback: t.pedidoFallback,
    );
    if (pedido != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.convertirCreado)));
    }
  }

  Future<void> _copiar() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final txt = textoCotizacion(_construir(), datos.negocio, t);
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.cotizaCopiado)));
  }

  Future<void> _whatsapp() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    final txt = textoCotizacion(_construir(), datos.negocio, t);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(txt)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _imprimir() async {
    final t = AppLocalizations.of(context)!;
    final datos = context.read<DatosApp>();
    await imprimirCotizacion(_construir(), datos.negocio, t);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final m = AppColores.of(context);
    final c = _construir();

    return Scaffold(
      appBar: AppBar(title: Text(t.cotizacionTitulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Datos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: clienteCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        labelText: t.cotizaCliente,
                        prefixIcon: const Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: fecha,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => fecha = d);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                                labelText: t.cotizaFecha,
                                prefixIcon:
                                    const Icon(Icons.calendar_today_outlined)),
                            child: Text(
                                '${fecha.day}/${fecha.month}/${fecha.year}'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: estado,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: t.cotizaEstado),
                          items: [
                            for (final e in kEstadosCotizacion)
                              DropdownMenuItem(
                                  value: e,
                                  child: Text(estadoCotizacionTexto(t, e))),
                          ],
                          onChanged: (v) => setState(() => estado = v ?? 'borrador'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Productos
          const SizedBox(height: 16),
          _tituloSeccion(m, t.cotizaProductosTitulo),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (lineas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(t.cotizaSinLineas,
                          style: TextStyle(color: m.textoSuave)),
                    ),
                  ...lineas.asMap().entries.map((e) {
                    final le = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(le.linea.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: m.rojo),
                                onPressed: () => setState(() {
                                  le.cant.dispose();
                                  le.precio.dispose();
                                  lineas.removeAt(e.key);
                                }),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: le.cant,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [Decimal2Formatter()],
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      labelText: t.cotizaCantidad,
                                      isDense: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: le.precio,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [Decimal2Formatter()],
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      labelText: t.cotizaPrecioUnitario,
                                      isDense: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _agregarProducto,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t.cotizaAgregarProducto),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Adiciones
          const SizedBox(height: 16),
          _tituloSeccion(m, t.cotizaAdicionesTitulo),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (adiciones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(t.cotizaSinAdiciones,
                          style: TextStyle(color: m.textoSuave)),
                    ),
                  ...adiciones.asMap().entries.map((e) {
                    final ae = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ae.nombre,
                              decoration: InputDecoration(
                                  labelText: t.cotizaAdicion, isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ae.valor,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [Decimal2Formatter()],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  labelText: t.cotizaValor, isDense: true),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: m.rojo),
                            onPressed: () => setState(() {
                              ae.nombre.dispose();
                              ae.valor.dispose();
                              adiciones.removeAt(e.key);
                            }),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() =>
                          adiciones.add(_AdicEdit(AdicionCotizacion(nombre: '', valor: 0)))),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t.cotizaAgregarAdicion),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cierre
          const SizedBox(height: 16),
          _tituloSeccion(m, t.cotizaCierre),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: domicilioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [Decimal2Formatter()],
                          decoration:
                              InputDecoration(labelText: t.cotizaDomicilio),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: descuentoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [Decimal2Formatter()],
                          decoration:
                              InputDecoration(labelText: t.cotizaDescuento),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: aplicaIva,
                    onChanged: (v) => setState(() => aplicaIva = v),
                    title: Text(t.cotizaCobrarIva),
                  ),
                  if (aplicaIva)
                    TextField(
                      controller: ivaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [Decimal2Formatter()],
                      decoration: InputDecoration(labelText: t.costeoIvaTasa),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notaCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: t.cotizaNota),
                  ),
                ],
              ),
            ),
          ),

          // Totales
          const SizedBox(height: 16),
          Card(
            color: m.verde.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _filaTotal(m, t.cotizaSubtotal, pesos(c.subtotal)),
                  if (c.descuentoAplicado > 0)
                    _filaTotal(m, t.cotizaDescuento,
                        '-${pesos(c.descuentoAplicado)}'),
                  if (c.domicilio > 0)
                    _filaTotal(m, t.cotizaDomicilio, pesos(c.domicilio)),
                  if (c.aplicaIva)
                    _filaTotal(m, '${t.costeoIva} ${cantidadStr(c.tasaIva)}%',
                        pesos(c.iva)),
                  const Divider(),
                  _filaTotal(m, t.cotizaTotal, pesos(c.total), fuerte: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined),
              label: Text(t.guardar)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copiar,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(t.cotizaCopiar),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(t.cotizaWhatsapp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _imprimir,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: Text(t.cotizaImprimir),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(MarcaColores m, String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(titulo,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: m.texto)),
      );

  Widget _filaTotal(MarcaColores m, String etq, String val,
          {bool fuerte = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etq,
                style: TextStyle(
                    fontSize: fuerte ? 16 : 13,
                    fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
                    color: fuerte ? m.texto : m.textoSuave)),
            Text(val,
                style: TextStyle(
                    fontSize: fuerte ? 18 : 13,
                    fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
                    color: fuerte ? m.verde : m.texto)),
          ],
        ),
      );
}
