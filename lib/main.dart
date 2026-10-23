import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'datos_app.dart';
import 'compuerta.dart';
import 'tema.dart';
import 'servicios/push_service.dart';
import 'servicios/suscripcion_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_picker/country_picker.dart';
import 'package:reposteria_app/l10n/app_localizations.dart'; // NUEVO

// Background push handler (mandatory, and it has to be top-level).
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {}

// Global Analytics instance (used by the navigation observer).
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

/// Points the app at the local emulators instead of the real Firebase.
///
/// Only turned on by building with `--dart-define=STOCKLET_EMULATOR=true`,
/// which is what the demo business uses to take store screenshots without
/// exposing real data. Being `const`, a release build strips it out of the
/// binary: there is no way for it to slip into production.
const bool kUsarEmulador =
    bool.fromEnvironment('STOCKLET_EMULADOR', defaultValue: false);

void _conectarEmuladores() {
  // Inside the Android emulator, `localhost` is the device itself: the machine
  // running the Firebase emulators appears as 10.0.2.2. On web and desktop it
  // really is localhost. From a physical phone you have to pass the machine
  // address on the local network with --dart-define=STOCKLET_EMULATOR_HOST=...
  const definido = String.fromEnvironment('STOCKLET_EMULADOR_HOST');
  final host = definido.isNotEmpty
      ? definido
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost');
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
  debugPrint('Stocklet apuntando a los emuladores en $host');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kUsarEmulador) _conectarEmuladores();

  // Crashlytics: catches Flutter errors and uncaught async errors.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  await PushService.instance.init();
  await SuscripcionService.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => DatosApp(),
      child: const MiApp(),
    ),
  );
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final acentoId = context.select<DatosApp, String>((d) => d.acentoId);
    final modoTemaId = context.select<DatosApp, String>((d) => d.modoTemaId);
    // Language chosen by the user (null = follow the device one)
    final idiomaId = context.select<DatosApp, String?>((d) => d.idiomaId);
    final acento = colorDeAcento(acentoId);
    final modo = switch (modoTemaId) {
      'oscuro' => ThemeMode.dark,
      'auto' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    return MaterialApp(
      title: 'Stocklet',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      // Analytics: records visited screens automatically.
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
      theme: temaApp(acento: acento),
      darkTheme: temaOscuro(acento: acento),
      themeMode: modo,
      // If idiomaId is null, Flutter uses the device language.
      locale: idiomaId == null ? null : Locale(idiomaId),
      localizationsDelegates: const [
        AppLocalizations.delegate, // NUEVO
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Supported languages. To add another one later, create its .arb (say
      // app_de.arb) and add its Locale here.
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('pt'),
        Locale('fr'),
      ],
      home: const Compuerta(),
    );
  }
}
