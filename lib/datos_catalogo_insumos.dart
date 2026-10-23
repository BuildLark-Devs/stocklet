// Reference catalogue: common purchase presentations in Colombia.
// The price starts at zero; each person sets their own.
// [nombre, categoría, cantidad, purchase unit, especial]

class ItemCatalogoInsumo {
  final String nombre;
  final String categoria;
  final double cantidad;
  final String unidad;
  final bool especial;
  const ItemCatalogoInsumo(
      this.nombre, this.categoria, this.cantidad, this.unidad, this.especial);
}

const List<ItemCatalogoInsumo> kCatalogoInsumos = [
  ItemCatalogoInsumo('Harina de trigo', 'Harinas y almidones', 1, 'kg', false),
  ItemCatalogoInsumo('Harina de trigo integral', 'Harinas y almidones', 1, 'kg', false),
  ItemCatalogoInsumo('Harina de almendras', 'Harinas y almidones', 500, 'g', true),
  ItemCatalogoInsumo('Harina de avena', 'Harinas y almidones', 500, 'g', false),
  ItemCatalogoInsumo('Almidón de maíz (maicena)', 'Harinas y almidones', 500, 'g', false),
  ItemCatalogoInsumo('Almidón agrio de yuca', 'Harinas y almidones', 500, 'g', false),
  ItemCatalogoInsumo('Harina de arroz', 'Harinas y almidones', 500, 'g', false),
  ItemCatalogoInsumo('Coco deshidratado', 'Harinas y almidones', 250, 'g', false),
  ItemCatalogoInsumo('Azúcar blanca', 'Azúcares y sustitutos', 1, 'kg', false),
  ItemCatalogoInsumo('Azúcar morena', 'Azúcares y sustitutos', 1, 'kg', false),
  ItemCatalogoInsumo('Azúcar pulverizada', 'Azúcares y sustitutos', 500, 'g', false),
  ItemCatalogoInsumo('Panela pulverizada', 'Azúcares y sustitutos', 500, 'g', false),
  ItemCatalogoInsumo('Miel de abejas', 'Azúcares y sustitutos', 500, 'g', false),
  ItemCatalogoInsumo('Jarabe de agave', 'Azúcares y sustitutos', 500, 'ml', false),
  ItemCatalogoInsumo('Eritritol', 'Azúcares y sustitutos', 500, 'g', true),
  ItemCatalogoInsumo('Estevia en polvo', 'Azúcares y sustitutos', 200, 'g', true),
  ItemCatalogoInsumo('Fruto del monje (monk fruit)', 'Azúcares y sustitutos', 250, 'g', true),
  ItemCatalogoInsumo('Xilitol', 'Azúcares y sustitutos', 500, 'g', true),
  ItemCatalogoInsumo('Leche entera', 'Lácteos y huevos', 1, 'l', false),
  ItemCatalogoInsumo('Leche deslactosada', 'Lácteos y huevos', 1, 'l', false),
  ItemCatalogoInsumo('Leche de almendras', 'Lácteos y huevos', 1, 'l', true),
  ItemCatalogoInsumo('Leche condensada', 'Lácteos y huevos', 395, 'g', false),
  ItemCatalogoInsumo('Crema de leche', 'Lácteos y huevos', 200, 'g', false),
  ItemCatalogoInsumo('Queso crema', 'Lácteos y huevos', 250, 'g', false),
  ItemCatalogoInsumo('Mantequilla sin sal', 'Lácteos y huevos', 250, 'g', false),
  ItemCatalogoInsumo('Margarina para hojaldre', 'Grasas', 1, 'kg', false),
  ItemCatalogoInsumo('Yogur natural', 'Lácteos y huevos', 1, 'kg', false),
  ItemCatalogoInsumo('Leche en polvo', 'Lácteos y huevos', 380, 'g', false),
  ItemCatalogoInsumo('Huevos AA', 'Lácteos y huevos', 1, 'doc', false),
  ItemCatalogoInsumo('Arequipe', 'Lácteos y huevos', 250, 'g', false),
  ItemCatalogoInsumo('Aceite vegetal', 'Grasas', 1, 'l', false),
  ItemCatalogoInsumo('Aceite de coco', 'Grasas', 500, 'ml', false),
  ItemCatalogoInsumo('Manteca vegetal', 'Grasas', 500, 'g', false),
  ItemCatalogoInsumo('Cacao en polvo', 'Chocolates y cacao', 500, 'g', false),
  ItemCatalogoInsumo('Cobertura de chocolate semiamargo', 'Chocolates y cacao', 500, 'g', false),
  ItemCatalogoInsumo('Chispas de chocolate', 'Chocolates y cacao', 500, 'g', false),
  ItemCatalogoInsumo('Chocolate blanco', 'Chocolates y cacao', 500, 'g', false),
  ItemCatalogoInsumo('Chocolate sin azúcar añadida', 'Chocolates y cacao', 200, 'g', true),
  ItemCatalogoInsumo('Nueces', 'Frutos secos y semillas', 250, 'g', false),
  ItemCatalogoInsumo('Almendras', 'Frutos secos y semillas', 250, 'g', false),
  ItemCatalogoInsumo('Marañón', 'Frutos secos y semillas', 250, 'g', false),
  ItemCatalogoInsumo('Maní', 'Frutos secos y semillas', 500, 'g', false),
  ItemCatalogoInsumo('Uvas pasas', 'Frutos secos y semillas', 250, 'g', false),
  ItemCatalogoInsumo('Ajonjolí', 'Frutos secos y semillas', 250, 'g', false),
  ItemCatalogoInsumo('Zanahoria', 'Frutas y vegetales', 1, 'kg', false),
  ItemCatalogoInsumo('Banano', 'Frutas y vegetales', 1, 'kg', false),
  ItemCatalogoInsumo('Limón', 'Frutas y vegetales', 1, 'kg', false),
  ItemCatalogoInsumo('Fresa', 'Frutas y vegetales', 500, 'g', false),
  ItemCatalogoInsumo('Mora', 'Frutas y vegetales', 500, 'g', false),
  ItemCatalogoInsumo('Pulpa de maracuyá', 'Frutas y vegetales', 500, 'g', false),
  ItemCatalogoInsumo('Esencia de vainilla', 'Saborizantes y aditivos', 120, 'ml', false),
  ItemCatalogoInsumo('Canela en polvo', 'Saborizantes y aditivos', 100, 'g', false),
  ItemCatalogoInsumo('Sal', 'Saborizantes y aditivos', 500, 'g', false),
  ItemCatalogoInsumo('Colorante en gel', 'Saborizantes y aditivos', 25, 'g', false),
  ItemCatalogoInsumo('Gelatina sin sabor', 'Saborizantes y aditivos', 250, 'g', false),
  ItemCatalogoInsumo('Polvo de hornear', 'Leudantes', 200, 'g', false),
  ItemCatalogoInsumo('Bicarbonato de sodio', 'Leudantes', 250, 'g', false),
  ItemCatalogoInsumo('Levadura seca', 'Leudantes', 500, 'g', false),
  ItemCatalogoInsumo('Cremor tártaro', 'Leudantes', 100, 'g', false),
  ItemCatalogoInsumo('Base de cartón redonda 20 cm', 'Empaques', 10, 'unidad', false),
  ItemCatalogoInsumo('Caja para torta 20 cm', 'Empaques', 10, 'unidad', false),
  ItemCatalogoInsumo('Domo plástico individual', 'Empaques', 50, 'unidad', false),
  ItemCatalogoInsumo('Bolsa de celofán', 'Empaques', 100, 'unidad', false),
  ItemCatalogoInsumo('Capacillos para cupcake', 'Empaques', 100, 'unidad', false),
  ItemCatalogoInsumo('Bandeja de icopor', 'Empaques', 25, 'unidad', false),
  ItemCatalogoInsumo('Etiqueta adhesiva', 'Empaques', 100, 'unidad', false),
];
