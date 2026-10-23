import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reposteria_app/l10n/app_localizations.dart';
import '../pantallas/notificaciones.dart';

// Global keys for navigating and showing notices from outside the widget
// tree (for example, when a push notification arrives).
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Push notification service (FCM). The bell on the home screen is unchanged;
// this only receives pushes and, on tap, opens the notifications screen.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fm = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      await _fm.requestPermission();
      await _fm.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      // App opened by tapping a push while it was in the background.
      FirebaseMessaging.onMessageOpenedApp
          .listen((_) => _abrirNotificaciones());

      // App opened from closed by tapping a push.
      final inicial = await _fm.getInitialMessage();
      if (inicial != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _abrirNotificaciones());
      }

      // Push in the foreground: show a notice with a "View" action.
      FirebaseMessaging.onMessage.listen(_enPrimerPlano);

      // If the token changes, store it again.
      _fm.onTokenRefresh.listen((token) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) _guardar(uid, token);
      });
    } catch (_) {
      // On web without push configured, or if the user denies permission,
      // the app must not fail to start.
    }
  }

  void _enPrimerPlano(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    final ctx = navigatorKey.currentContext;
    final etiquetaVer =
        ctx != null ? (AppLocalizations.of(ctx)?.ver ?? 'Ver') : 'Ver';
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(n.title ?? n.body ?? ''),
        action: SnackBarAction(
          label: etiquetaVer,
          onPressed: _abrirNotificaciones,
        ),
      ),
    );
  }

  void _abrirNotificaciones() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const PantallaNotificaciones()),
    );
  }

  // Stores the device token in usuarios/{uid}.fcmTokens (arrayUnion).
  // Called once the user has a business (their usuarios doc exists).
  Future<void> guardarToken(String uid) async {
    try {
      final token = await _fm.getToken();
      if (token != null) await _guardar(uid, token);
    } catch (_) {}
  }

  Future<void> _guardar(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (_) {
      // The doc may not exist yet; it is written on joining a business.
    }
  }
}
