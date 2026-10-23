// Purchase units and conversion to a base unit (g / ml / each).
// Every purchased quantity is converted to a base unit for costing and for
// inventory. E.g. 1 kg -> 1000 g.

class UnidadDef {
  final String rot; // etiqueta visible
  final String base; // 'g' | 'ml' | 'unidad'
  final double factor; // cuántas unidades base hay en 1 de esta unidad
  const UnidadDef(this.rot, this.base, this.factor);
}

const Map<String, UnidadDef> kUnidades = {
  'g': UnidadDef('gramo (g)', 'g', 1),
  'kg': UnidadDef('kilogramo (kg)', 'g', 1000),
  'lb': UnidadDef('libra (500 g)', 'g', 500),
  'arroba': UnidadDef('arroba (12,5 kg)', 'g', 12500),
  'oz': UnidadDef('onza (28,35 g)', 'g', 28.3495),
  'ml': UnidadDef('mililitro (ml)', 'ml', 1),
  'l': UnidadDef('litro (l)', 'ml', 1000),
  'unidad': UnidadDef('unidad', 'unidad', 1),
  'doc': UnidadDef('docena', 'unidad', 12),
};

// Base unit abbreviation (for showing costs and stock).
const Map<String, String> kRotBase = {'g': 'g', 'ml': 'ml', 'unidad': 'u'};

String baseDeUnidad(String u) => kUnidades[u]?.base ?? 'g';
double factorDeUnidad(String u) => kUnidades[u]?.factor ?? 1;
String rotBase(String base) => kRotBase[base] ?? base;

/// Cost per base unit from a purchase presentation.
/// E.g. $4,000 for 1 kg -> 4 per g.
double costoBaseDesde(double precio, double cantidadCompra, String unidadCompra) {
  final unidadesBase = cantidadCompra * factorDeUnidad(unidadCompra);
  return unidadesBase > 0 ? precio / unidadesBase : 0;
}

/// Quantity in the base unit from a presentation. E.g. 1 kg -> 1000 g.
double cantidadBaseDesde(double cantidadCompra, String unidadCompra) =>
    cantidadCompra * factorDeUnidad(unidadCompra);

// Supply categories (stored as text, like the product types).
const List<String> kCategoriasInsumo = [
  'Harinas y almidones',
  'Azúcares y sustitutos',
  'Lácteos y huevos',
  'Grasas',
  'Chocolates y cacao',
  'Frutos secos y semillas',
  'Frutas y vegetales',
  'Saborizantes y aditivos',
  'Leudantes',
  'Empaques',
  'Otros',
];
