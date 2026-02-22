import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

const String kRevenueCatApiKey = 'test_LDPhSNXbwKuEHFgFBNUtddJDkYT';
const String kPremiumEntitlementId = 'SkillMax Premium';

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );

@immutable
class SubscriptionState {
  const SubscriptionState({
    this.isConfigured = false,
    this.isLoading = false,
    this.isPremium = false,
    this.customerInfo,
    this.offerings,
    this.errorMessage,
  });

  final bool isConfigured;
  final bool isLoading;
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final String? errorMessage;

  SubscriptionState copyWith({
    bool? isConfigured,
    bool? isLoading,
    bool? isPremium,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    String? errorMessage,
  }) {
    return SubscriptionState(
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      isPremium: isPremium ?? this.isPremium,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
      errorMessage: errorMessage,
    );
  }
}

class SubscriptionController extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => const SubscriptionState();

  Future<void> init({String? appUserId}) async {
    if (state.isConfigured) {
      if (appUserId != null && appUserId.isNotEmpty) {
        state = state.copyWith(isLoading: true, errorMessage: null);
        try {
          final result = await Purchases.logIn(appUserId);
          _applyCustomerInfo(result.customerInfo);
        } catch (e) {
          state = state.copyWith(errorMessage: 'RevenueCat login failed: $e');
        } finally {
          state = state.copyWith(isLoading: false);
        }
      }
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (kDebugMode) {
        Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration = PurchasesConfiguration(kRevenueCatApiKey);
      await Purchases.configure(configuration);

      if (appUserId != null && appUserId.isNotEmpty) {
        await Purchases.logIn(appUserId);
      }

      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      state = state.copyWith(isConfigured: true);
      await refresh();
    } catch (e) {
      state = state.copyWith(errorMessage: 'RevenueCat init failed: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      _applyCustomerInfo(info);
      state = state.copyWith(offerings: offerings);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Refresh failed: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Restore failed: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<PaywallResult> showPaywall() async {
    state = state.copyWith(errorMessage: null);
    try {
      return await RevenueCatUI.presentPaywall();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Paywall failed: $e');
      return PaywallResult.error;
    }
  }

  Future<void> showPaywallIfNeeded() async {
    state = state.copyWith(errorMessage: null);
    try {
      await RevenueCatUI.presentPaywallIfNeeded(kPremiumEntitlementId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Paywall failed: $e');
    }
  }

  Future<void> showCustomerCenter() async {
    state = state.copyWith(errorMessage: null);
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Customer Center failed: $e');
    }
  }

  Future<void> logOut() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await Purchases.logOut();
      _applyCustomerInfo(info);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Log out failed: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final isPremium =
        info.entitlements.all[kPremiumEntitlementId]?.isActive == true;
    state = state.copyWith(customerInfo: info, isPremium: isPremium);
  }
}
