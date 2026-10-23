import 'package:flutter/material.dart';

// --- Opciones de color de acento ---
class AcentoOpcion {
  final String id;
  final String nombre;
  final Color color;
  const AcentoOpcion(this.id, this.nombre, this.color);
}

const List<AcentoOpcion> acentos = [
  AcentoOpcion('verde', 'Verde', Color(0xFF0E9F6E)),
  AcentoOpcion('azul', 'Azul', Color(0xFF2563EB)),
  AcentoOpcion('turquesa', 'Turquesa', Color(0xFF0D9488)),
  AcentoOpcion('morado', 'Morado', Color(0xFF7C3AED)),
  AcentoOpcion('naranja', 'Naranja', Color(0xFFEA580C)),
  AcentoOpcion('rosa', 'Rosa', Color(0xFFDB2777)),
];

Color colorDeAcento(String id) =>
    acentos.firstWhere((a) => a.id == id, orElse: () => acentos.first).color;

// --- Brand colours, theme aware (light/dark) ---
@immutable
class MarcaColores extends ThemeExtension<MarcaColores> {
  final Color verde; // acento
  final Color verdeOscuro;
  final Color fondo;
  final Color superficie;
  final Color texto;
  final Color textoSuave;
  final Color rojo;
  final Color borde;

  const MarcaColores({
    required this.verde,
    required this.verdeOscuro,
    required this.fondo,
    required this.superficie,
    required this.texto,
    required this.textoSuave,
    required this.rojo,
    required this.borde,
  });

  @override
  MarcaColores copyWith({
    Color? verde,
    Color? verdeOscuro,
    Color? fondo,
    Color? superficie,
    Color? texto,
    Color? textoSuave,
    Color? rojo,
    Color? borde,
  }) {
    return MarcaColores(
      verde: verde ?? this.verde,
      verdeOscuro: verdeOscuro ?? this.verdeOscuro,
      fondo: fondo ?? this.fondo,
      superficie: superficie ?? this.superficie,
      texto: texto ?? this.texto,
      textoSuave: textoSuave ?? this.textoSuave,
      rojo: rojo ?? this.rojo,
      borde: borde ?? this.borde,
    );
  }

  @override
  MarcaColores lerp(MarcaColores? other, double t) {
    if (other == null) return this;
    return MarcaColores(
      verde: Color.lerp(verde, other.verde, t)!,
      verdeOscuro: Color.lerp(verdeOscuro, other.verdeOscuro, t)!,
      fondo: Color.lerp(fondo, other.fondo, t)!,
      superficie: Color.lerp(superficie, other.superficie, t)!,
      texto: Color.lerp(texto, other.texto, t)!,
      textoSuave: Color.lerp(textoSuave, other.textoSuave, t)!,
      rojo: Color.lerp(rojo, other.rojo, t)!,
      borde: Color.lerp(borde, other.borde, t)!,
    );
  }
}

// --- Fixed tokens (LIGHT) — kept so nothing breaks.
// In the batched refactor, screens move from AppColores.xxx (fixed) to
// AppColores.of(context).xxx (theme aware). They can go once that is done. ---
class AppColores {
  static const Color verde = Color(0xFF0E9F6E);
  static const Color verdeOscuro = Color(0xFF0A7D55);
  static const Color fondo = Color(0xFFF5F7F8);
  static const Color superficie = Colors.white;
  static const Color texto = Color(0xFF1B2733);
  static const Color textoSuave = Color(0xFF6B7785);
  static const Color rojo = Color(0xFFE2483D);
  static const Color borde = Color(0x14000000);

  static MarcaColores of(BuildContext context) =>
      Theme.of(context).extension<MarcaColores>()!;
}

Color _oscurecer(Color c, double f) => Color.lerp(c, Colors.black, f)!;
Color _aclarar(Color c, double f) => Color.lerp(c, Colors.white, f)!;

MarcaColores _marcaClara(Color acento) => MarcaColores(
      verde: acento,
      verdeOscuro: _oscurecer(acento, 0.18),
      fondo: const Color(0xFFF5F7F8),
      superficie: Colors.white,
      texto: const Color(0xFF1B2733),
      textoSuave: const Color(0xFF6B7785),
      rojo: const Color(0xFFE2483D),
      borde: const Color(0x14000000),
    );

MarcaColores _marcaOscura(Color acento) => MarcaColores(
      verde: acento,
      verdeOscuro: _aclarar(acento, 0.22),
      fondo: const Color(0xFF111417),
      superficie: const Color(0xFF1A1F24),
      texto: const Color(0xFFE7ECF0),
      textoSuave: const Color(0xFF97A3AE),
      rojo: const Color(0xFFF26257),
      borde: const Color(0x1FFFFFFF),
    );

ThemeData _tema(Color acento, Brightness brillo) {
  final m =
      brillo == Brightness.dark ? _marcaOscura(acento) : _marcaClara(acento);

  final esquema = ColorScheme.fromSeed(
    seedColor: acento,
    primary: acento,
    brightness: brillo,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: m.fondo,
    extensions: [m],
    appBarTheme: AppBarTheme(
      backgroundColor: m.superficie,
      foregroundColor: m.texto,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: m.texto,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: m.superficie,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: m.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: m.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: m.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: acento, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: acento,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: acento,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: acento),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: acento),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: acento,
      foregroundColor: Colors.white,
    ),
  );
}

ThemeData temaApp({Color acento = const Color(0xFF0E9F6E)}) =>
    _tema(acento, Brightness.light);

ThemeData temaOscuro({Color acento = const Color(0xFF0E9F6E)}) =>
    _tema(acento, Brightness.dark);