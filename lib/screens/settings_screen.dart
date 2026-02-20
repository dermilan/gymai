import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/user_prefs.dart';
import '../providers.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final AuthService? authService;
  final SubscriptionService? subscriptionService;

  const SettingsScreen({
    super.key,
    this.authService,
    this.subscriptionService,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _injuriesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _selectedPersona = 'Gym Bro';
  String _status = '';
  bool _includeWarmUp = true;
  bool _includeCoolDown = true;
  WeightUnit _weightUnit = WeightUnit.kg;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final store = ref.read(storeProvider);
    final prefs = await store.fetchPrefs();
    _goalController.text = prefs.goal;
    _daysController.text = prefs.daysPerWeek.toString();
    _equipmentController.text = prefs.equipment;
    _injuriesController.text = prefs.injuries;
    _durationController.text = prefs.sessionDurationMinutes.toString();
    _nameController.text = prefs.preferredName;
    _selectedPersona = prefs.persona;
    _includeWarmUp = prefs.includeWarmUp;
    _includeCoolDown = prefs.includeCoolDown;
    _weightUnit = prefs.weightUnit;
    setState(() {});
  }

  @override
  void dispose() {
    _goalController.dispose();
    _daysController.dispose();
    _equipmentController.dispose();
    _injuriesController.dispose();
    _durationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _savePrefs() async {
    final prefs = UserPrefs(
      goal: _goalController.text.trim().isEmpty
          ? 'Hypertrophy'
          : _goalController.text.trim(),
      daysPerWeek: int.tryParse(_daysController.text.trim()) ?? 3,
      equipment: _equipmentController.text.trim().isEmpty
          ? 'Full gym'
          : _equipmentController.text.trim(),
      injuries: _injuriesController.text.trim().isEmpty
          ? 'None'
          : _injuriesController.text.trim(),
      sessionDurationMinutes:
          int.tryParse(_durationController.text.trim()) ?? 60,
      includeWarmUp: _includeWarmUp,
      includeCoolDown: _includeCoolDown,
      persona: _selectedPersona,
      preferredName: _nameController.text.trim().isEmpty
          ? 'Champ'
          : _nameController.text.trim(),
      weightUnit: _weightUnit,
    );

    await ref.read(storeProvider).savePrefs(prefs);
    ref.invalidate(prefsProvider);
    setState(() => _status = 'Saved ✓');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _status = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_status.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // --- AI Configuration section ---
          _SectionHeader(
            icon: Icons.psychology_rounded,
            label: 'AI Preferences',
            accent: cs.secondary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPersona,
                decoration: const InputDecoration(
                  labelText: 'AI Persona',
                  prefixIcon: Icon(Icons.psychology_rounded, size: 20),
                ),
                items: [
                  'Gym Bro',
                  'Evidence-Based Scientist',
                  'Old-School Drill Sergeant',
                  'Supportive Zen Coach',
                  'Data-Driven Strategist'
                ].map((p) {
                  return DropdownMenuItem(value: p, child: Text(p));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPersona = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'How should AI address you?',
                  prefixIcon: Icon(Icons.badge_rounded, size: 20),
                  hintText: 'Champ',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- Training Profile section ---
          _SectionHeader(
            icon: Icons.person_rounded,
            label: 'Training Profile',
            accent: cs.primary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              TextField(
                controller: _goalController,
                decoration: const InputDecoration(
                  labelText: 'Goal',
                  prefixIcon: Icon(Icons.flag_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days per week',
                  prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _equipmentController,
                decoration: const InputDecoration(
                  labelText: 'Equipment',
                  prefixIcon: Icon(Icons.fitness_center_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _injuriesController,
                decoration: const InputDecoration(
                  labelText: 'Injuries / Limitations',
                  prefixIcon: Icon(Icons.healing_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Session duration (min)',
                  prefixIcon: Icon(Icons.timer_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _includeWarmUp,
                onChanged: (value) => setState(() => _includeWarmUp = value),
                title: const Text('Include warm-up'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _includeCoolDown,
                onChanged: (value) => setState(() => _includeCoolDown = value),
                title: const Text('Include cool down'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Weight unit',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SegmentedButton<WeightUnit>(
                    segments: const [
                      ButtonSegment(
                        value: WeightUnit.kg,
                        label: Text('kg'),
                      ),
                      ButtonSegment(
                        value: WeightUnit.lbs,
                        label: Text('lbs'),
                      ),
                    ],
                    selected: {_weightUnit},
                    onSelectionChanged: (selected) {
                      setState(() => _weightUnit = selected.first);
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // --- save button ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savePrefs,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Settings'),
            ),
          ),

          // --- account section (only if auth is available) ---
          if (widget.authService != null) ...[
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.account_circle_rounded,
              label: 'Account',
              accent: cs.tertiary,
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                // Subscription tier display
                if (widget.subscriptionService != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.workspace_premium_rounded,
                      color: _tierColor(
                          widget.subscriptionService!.currentTier),
                    ),
                    title: const Text('Subscription'),
                    subtitle: Text(
                      _tierLabel(widget.subscriptionService!.currentTier),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubscriptionScreen(
                            subscriptionService: widget.subscriptionService!,
                          ),
                        ),
                      );
                    },
                  ),
                if (widget.subscriptionService != null)
                  const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign Out'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out?'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await widget.authService!.signOut();
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _tierColor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Colors.grey;
      case SubscriptionTier.plus:
        return Colors.blue;
      case SubscriptionTier.pro:
        return Colors.amber;
    }
  }

  String _tierLabel(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }
}

// -- helper widgets ----------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
