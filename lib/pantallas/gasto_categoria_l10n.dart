import 'package:reposteria_app/l10n/app_localizations.dart';
import '../models/gasto.dart';

// Localised name of an expense category.
String nombreCategoria(AppLocalizations t, CategoriaGasto c) {
  switch (c) {
    case CategoriaGasto.insumos:
      return t.categoriaInsumos;
    case CategoriaGasto.servicios:
      return t.categoriaServicios;
    case CategoriaGasto.empaques:
      return t.categoriaEmpaques;
    case CategoriaGasto.otros:
      return t.categoriaOtros;
  }
}
