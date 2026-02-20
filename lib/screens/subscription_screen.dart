import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/app_user.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final AppUser? user;
  final SubscriptionService subscriptionService;

  const SubscriptionScreen({
    super.key,
    this.user,
    required this.subscriptionService,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.subscriptionService.fetchOfferings();
  }

  Future<void> _purchase(Package package) async {
    setState(() => _loading = true);
    
    try {
      final success = await widget.subscriptionService.purchasePackage(package);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription activated!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    
    try {
      await widget.subscriptionService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentTier = widget.user?.effectiveTier ?? SubscriptionTier.free;
    final remaining = widget.user?.remainingAiRequests ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current status card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _tierIcon(currentTier),
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentTier.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    remaining == -1
                        ? 'Unlimited AI requests'
                        : '$remaining AI requests remaining this month',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Plan comparison
            _PlanCard(
              tier: SubscriptionTier.free,
              isCurrentTier: currentTier == SubscriptionTier.free,
              features: const [
                '15 AI requests/month',
                'Workout planning',
                'Progress tracking',
              ],
              onSelect: null, // Free is always available
            ),

            const SizedBox(height: 12),

            ListenableBuilder(
              listenable: widget.subscriptionService,
              builder: (context, _) {
                final offerings = widget.subscriptionService.offerings;
                Package? plusPackage;
                Package? proPackage;

                if (offerings?.current != null) {
                  for (final pkg in offerings!.current!.availablePackages) {
                    if (pkg.storeProduct.identifier.contains('plus')) {
                      plusPackage = pkg;
                    } else if (pkg.storeProduct.identifier.contains('pro')) {
                      proPackage = pkg;
                    }
                  }
                }

                return Column(
                  children: [
                    _PlanCard(
                      tier: SubscriptionTier.plus,
                      isCurrentTier: currentTier == SubscriptionTier.plus,
                      features: const [
                        '150 AI requests/month',
                        'Session comments',
                        'Priority support',
                      ],
                      package: plusPackage,
                      loading: _loading,
                      onSelect: currentTier == SubscriptionTier.plus || kIsWeb
                          ? null
                          : () => plusPackage != null ? _purchase(plusPackage) : null,
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      tier: SubscriptionTier.pro,
                      isCurrentTier: currentTier == SubscriptionTier.pro,
                      highlighted: true,
                      features: const [
                        'Unlimited AI requests',
                        'Session comments',
                        'Advanced AI model',
                        'Priority support',
                      ],
                      package: proPackage,
                      loading: _loading,
                      onSelect: currentTier == SubscriptionTier.pro || kIsWeb
                          ? null
                          : () => proPackage != null ? _purchase(proPackage) : null,
                    ),
                  ],
                );
              },
            ),

            if (kIsWeb) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.computer_rounded,
                      color: cs.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Web Subscriptions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To subscribe, please use the iOS or Android app. Your subscription will sync across all platforms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: _loading ? null : _restore,
                child: const Text('Restore Purchases'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _tierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Icons.person_outline;
      case SubscriptionTier.plus:
        return Icons.star_outline;
      case SubscriptionTier.pro:
        return Icons.workspace_premium;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isCurrentTier;
  final bool highlighted;
  final List<String> features;
  final Package? package;
  final bool loading;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.tier,
    required this.isCurrentTier,
    this.highlighted = false,
    required this.features,
    this.package,
    this.loading = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? cs.primaryContainer : const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTier
              ? cs.primary
              : highlighted
                  ? cs.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
          width: isCurrentTier ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier.displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highlighted ? cs.onPrimaryContainer : null,
                ),
              ),
              if (isCurrentTier) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                tier == SubscriptionTier.free
                    ? 'Free'
                    : package != null
                        ? package!.storeProduct.priceString
                        : '\$${tier.pricePerMonth.toStringAsFixed(0)}/mo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highlighted ? cs.onPrimaryContainer : cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: highlighted ? cs.onPrimaryContainer : cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        color: highlighted
                            ? cs.onPrimaryContainer.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )),
          if (onSelect != null && !isCurrentTier) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onSelect,
                style: highlighted
                    ? ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      )
                    : null,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tier == SubscriptionTier.free ? 'Downgrade' : 'Subscribe'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
