import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum SubscriptionTier {
  free,
  plus,
  pro,
}

extension SubscriptionTierX on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }

  int get monthlyAiLimit {
    switch (this) {
      case SubscriptionTier.free:
        return 15;
      case SubscriptionTier.plus:
        return 150;
      case SubscriptionTier.pro:
        return -1; // Unlimited
    }
  }

  bool get hasSessionComments {
    switch (this) {
      case SubscriptionTier.free:
        return false;
      case SubscriptionTier.plus:
      case SubscriptionTier.pro:
        return true;
    }
  }

  double get pricePerMonth {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.plus:
        return 5;
      case SubscriptionTier.pro:
        return 35;
    }
  }
}

@freezed
class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String uid,
    String? email,
    String? displayName,
    @Default(SubscriptionTier.free) SubscriptionTier tier,
    @Default(0) int aiRequestsThisMonth,
    DateTime? subscriptionExpiresAt,
    String? revenueCatUserId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AppUser;

  bool get isSubscriptionActive {
    if (tier == SubscriptionTier.free) return true;
    if (subscriptionExpiresAt == null) return false;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  SubscriptionTier get effectiveTier {
    if (tier == SubscriptionTier.free) return tier;
    return isSubscriptionActive ? tier : SubscriptionTier.free;
  }

  bool get canMakeAiRequest {
    final limit = effectiveTier.monthlyAiLimit;
    if (limit == -1) return true; // Unlimited
    return aiRequestsThisMonth < limit;
  }

  int get remainingAiRequests {
    final limit = effectiveTier.monthlyAiLimit;
    if (limit == -1) return -1; // Unlimited
    return (limit - aiRequestsThisMonth).clamp(0, limit);
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == data['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      aiRequestsThisMonth: (data['aiRequestsThisMonth'] as int?) ?? 0,
      subscriptionExpiresAt: data['subscriptionExpiresAt'] != null
          ? (data['subscriptionExpiresAt'] as Timestamp).toDate()
          : null,
      revenueCatUserId: data['revenueCatUserId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'tier': tier.name,
      'aiRequestsThisMonth': aiRequestsThisMonth,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'revenueCatUserId': revenueCatUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  @override
  Map<String, dynamic> toJson();
}
