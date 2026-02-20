import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class SubscriptionService extends ChangeNotifier {
  static const _revenueCatApiKeyIos = 'YOUR_REVENUECAT_IOS_KEY';
  static const _revenueCatApiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';

  // RevenueCat product identifiers
  static const productIdPlus = 'gym_ai_plus_monthly';
  static const productIdPro = 'gym_ai_pro_monthly';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;

  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isInitialized => _isInitialized;
  SubscriptionTier get currentTier => getTierFromCustomerInfo(_customerInfo);

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip RevenueCat on web - use Stripe instead
    if (kIsWeb) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    final apiKey = Platform.isIOS ? _revenueCatApiKeyIos : _revenueCatApiKeyAndroid;

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _isInitialized = true;

    // Listen to customer info changes
    Purchases.addCustomerInfoUpdateListener((info) {
      _customerInfo = info;
      _syncSubscriptionToFirestore(info);
      notifyListeners();
    });

    await refreshCustomerInfo();
    await fetchOfferings();
  }

  Future<void> loginUser(String uid) async {
    if (kIsWeb) return;
    
    try {
      await Purchases.logIn(uid);
      await refreshCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat login error: $e');
    }
  }

  Future<void> logoutUser() async {
    if (kIsWeb) return;
    
    try {
      await Purchases.logOut();
      _customerInfo = null;
      notifyListeners();
    } catch (e) {
      debugPrint('RevenueCat logout error: $e');
    }
  }

  Future<void> fetchOfferings() async {
    if (kIsWeb) return;
    
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch offerings: $e');
    }
  }

  Future<void> refreshCustomerInfo() async {
    if (kIsWeb) return;
    
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to get customer info: $e');
    }
  }

  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) {
      // Redirect to Stripe Checkout for web
      throw UnsupportedError('Use Stripe for web purchases');
    }

    try {
      _customerInfo = await Purchases.purchasePackage(package);
      await _syncSubscriptionToFirestore(_customerInfo!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Purchase failed: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    
    try {
      _customerInfo = await Purchases.restorePurchases();
      await _syncSubscriptionToFirestore(_customerInfo!);
      notifyListeners();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  SubscriptionTier getTierFromCustomerInfo(CustomerInfo? info) {
    if (info == null) return SubscriptionTier.free;

    final entitlements = info.entitlements.active;
    if (entitlements.containsKey('pro')) {
      return SubscriptionTier.pro;
    }
    if (entitlements.containsKey('plus')) {
      return SubscriptionTier.plus;
    }
    return SubscriptionTier.free;
  }

  DateTime? getExpirationDate(CustomerInfo? info) {
    if (info == null) return null;

    final entitlements = info.entitlements.active;
    EntitlementInfo? activeEntitlement;

    if (entitlements.containsKey('pro')) {
      activeEntitlement = entitlements['pro'];
    } else if (entitlements.containsKey('plus')) {
      activeEntitlement = entitlements['plus'];
    }

    if (activeEntitlement?.expirationDate != null) {
      return DateTime.parse(activeEntitlement!.expirationDate!);
    }
    return null;
  }

  Future<void> _syncSubscriptionToFirestore(CustomerInfo info) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = getTierFromCustomerInfo(info);
    final expiresAt = getExpirationDate(info);

    await _firestore.collection('users').doc(user.uid).update({
      'tier': tier.name,
      'subscriptionExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'revenueCatUserId': info.originalAppUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // For web: generate Stripe Checkout URL (calls Cloud Function)
  Future<String> createStripeCheckoutSession(SubscriptionTier tier) async {
    // This would call a Cloud Function to create a Stripe Checkout session
    // For now, throw an error indicating it needs backend setup
    throw UnimplementedError(
      'Stripe Checkout requires Cloud Function setup. '
      'See functions/src/stripe.ts for implementation.',
    );
  }
}
