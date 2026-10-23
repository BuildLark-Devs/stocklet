import 'insumo.dart';

class IngredienteDeReceta {
  Insumo insumo;
  double cantidad;

  IngredienteDeReceta({required this.insumo, required this.cantidad});

  double get costo => insumo.costoPorUnidad * cantidad;

  // stores only the supply id, not the whole supply
  Map<String, dynamic> toMap() {
    return {'insumoId': insumo.id, 'cantidad': cantidad};
  }
}