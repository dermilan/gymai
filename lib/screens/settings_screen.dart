import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/user_prefs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _injuriesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _selectedPersona = 'Gym Bro';
  bool _obscureKey = true;
  String _status = '';
  bool _includeWarmUp = true;
  bool _includeCoolDown = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await AppServices.store.fetchPrefs();
    _goalController.text = prefs.goal;
    _daysController.text = prefs.daysPerWeek.toString();
    _equipmentController.text = prefs.equipment;
    _injuriesController.text = prefs.injuries;
    _durationController.text = prefs.sessionDurationMinutes.toString();
    _apiKeyController.text = prefs.apiKey;
    _modelController.text = prefs.model;
    _nameController.text = prefs.preferredName;
    _selectedPersona = prefs.persona;
    _includeWarmUp = prefs.includeWarmUp;
    _includeCoolDown = prefs.includeCoolDown;
    setState(() {});
  }

  @override
  void dispose() {
    _goalController.dispose();
    _daysController.dispose();
    _equipmentController.dispose();
    _injuriesController.dispose();
    _durationController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
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
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? 'x-ai/grok-4.1-fast'
          : _modelController.text.trim(),
      persona: _selectedPersona,
      preferredName: _nameController.text.trim().isEmpty
          ? 'Champ'
          : _nameController.text.trim(),
    );

    await AppServices.store.savePrefs(prefs);
    AppServices.prefsRefresh.value++;
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
            icon: Icons.key_rounded,
            label: 'AI Configuration',
            accent: cs.secondary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'OpenRouter API Key',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.smart_toy_rounded, size: 20),
                  hintText: 'x-ai/grok-4.1-fast',
                ),
              ),
              const SizedBox(height: 12),
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
        ],
      ),
    );
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
