import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Subscription layer on top of RevenueCat.
///
/// Master switch [activa]:
///  - `false` (for now): RevenueCat is NOT initialised and [esPro] stays
///    `true` → everything unlocked; the app behaves as it does today. Keep it
///    here until the Google Play account + the products + the RevenueCat key
///    are all in place.
///  - `true`: RevenueCat is configured and [esPro] reflects the real "pro"
///    entitlement.
class SuscripcionService {
  SuscripcionService._();
  static final SuscripcionService instance = SuscripcionService._();

  /// Flip it to `true` once RevenueCat and the Play products are ready.
  static const bool activa = false;

  /// PUBLIC RevenueCat keys (Project settings → API keys). Replace them.
  static const String _apiKeyAndroid = 'REEMPLAZAR_REVENUECAT_ANDROID_KEY';
  static const String _apiKeyIos = 'REEMPLAZAR_REVENUECAT_IOS_KEY';

  /// Identificador del "entitlement" (permiso Pro) configurado en RevenueCat.
  static const String entitlementPro = 'pro';

  /// `true` = the user has Pro (or monetisation is inactive).
  final ValueNotifier<bool> esPro = ValueNotifier<bool>(true);

  Future<void> init() async {
    if (!activa) {
      esPro.value = true; // sin monetización, todo desbloqueado
      return;
    }
    try {
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? _apiKeyIos
          : _apiKeyAndroid;
      await Purchases.configure(PurchasesConfiguration(apiKey));
      await _refrescar();
      Purchases.addCustomerInfoUpdateListener((info) {
        esPro.value = info.entitlements.active.containsKey(entitlementPro);
      });
    } catch (_) {
      esPro.value = false;
    }
  }

  /// Links the subscription to the Firebase user.
  ///
  /// Without this RevenueCat assigns an anonymous ID per installation, and
  /// anyone reinstalling or signing in from another device does not get their
  /// Pro back unless they hit "Restore purchases" by hand. On identify,
  /// RevenueCat keeps purchases made before signing in (it ties them to the
  /// uid).
  Future<void> identificar(String uid) async {
    if (!activa || uid.isEmpty) return;
    try {
      final res = await Purchases.logIn(uid);
      esPro.value =
          res.customerInfo.entitlements.active.containsKey(entitlementPro);
    } catch (_) {
      // On failure it keeps whatever it had; restaurar() is still available.
    }
  }

  /// Unlinks on sign-out, so whoever signs in next on this same device does
  /// not inherit the previous user Pro state.
  Future<void> cerrarSesion() async {
    if (!activa) return;
    try {
      final info = await Purchases.logOut();
      esPro.value = info.entitlements.active.containsKey(entitlementPro);
    } catch (_) {
      // logOut throws if the user was already anonymous. Either way — that or
      // a network failure — the prudent thing is not to leave Pro on for the
      // next user.
      esPro.value = false;
    }
  }

  Future<void> _refrescar() async {
    try {
      final info = await Purchases.getCustomerInfo();
      esPro.value = info.entitlements.active.containsKey(entitlementPro);
    } catch (_) {}
  }

  /// Available packages (monthly, yearly...) to show on the paywall.
  Future<List<Package>> paquetes() async {
    if (!activa) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Buys a package. Returns `null` on success, or 'cancelado' | 'error'.
  Future<String?> comprar(Package paquete) async {
    if (!activa) return 'inactiva';
    try {
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(paquete);
      esPro.value =
          result.customerInfo.entitlements.active.containsKey(entitlementPro);
      return null;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return 'cancelado';
      return 'error';
    } catch (_) {
      return 'error';
    }
  }

  /// Restaura compras previas (obligatorio ofrecerlo en las tiendas).
  Future<void> restaurar() async {
    if (!activa) return;
    try {
      final info = await Purchases.restorePurchases();
      esPro.value = info.entitlements.active.containsKey(entitlementPro);
    } catch (_) {}
  }
}
