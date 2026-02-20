import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_card_config.dart';
import '../providers.dart';

/// Shows a modal bottom sheet where the user can toggle cards on/off
/// and drag to reorder them.
Future<void> showDashboardCustomizeSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return const _CustomizeSheetBody();
    },
  );
}

class _CustomizeSheetBody extends ConsumerStatefulWidget {
  const _CustomizeSheetBody();

  @override
  ConsumerState<_CustomizeSheetBody> createState() => _CustomizeSheetBodyState();
}

class _CustomizeSheetBodyState extends ConsumerState<_CustomizeSheetBody> {
  List<DashboardCardConfig>? _layout;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final store = ref.read(storeProvider);
    final layout = await store.fetchDashboardLayout();
    if (mounted) {
      setState(() => _layout = List.from(layout));
    }
  }

  Future<void> _save() async {
    if (_layout == null) return;
    final store = ref.read(storeProvider);
    await store.saveDashboardLayout(_layout!);
    ref.invalidate(dashboardLayoutProvider);
    _dirty = false;
  }

  void _resetToDefault() {
    setState(() {
      _layout = DashboardCardConfig.defaultLayout();
      _dirty = true;
    });
  }

  @override
  void dispose() {
    // Auto-save on dismiss if dirty.
    if (_dirty && _layout != null) {
      final store = ref.read(storeProvider);
      store.saveDashboardLayout(_layout!).then((_) {
        ref.invalidate(dashboardLayoutProvider);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_layout == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.dashboard_customize_rounded,
                    color: Color(0xFF00BFA6), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Customize Dashboard',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetToDefault,
                  child: const Text('Reset',
                      style: TextStyle(color: Color(0xFFFF5252))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Drag to reorder \u2022 Toggle to show/hide',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),

          // reorderable list
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (ctx, _) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      shadowColor: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                );
              },
              itemCount: _layout!.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _layout!.removeAt(oldIndex);
                  _layout!.insert(newIndex, item);
                  _dirty = true;
                });
              },
              itemBuilder: (context, index) {
                final card = _layout![index];
                return _CardRow(
                  key: ValueKey(card.id),
                  config: card,
                  onToggle: (visible) {
                    setState(() {
                      _layout![index] = card.copyWith(visible: visible);
                      _dirty = true;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // save button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _save();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final DashboardCardConfig config;
  final ValueChanged<bool> onToggle;

  const _CardRow({
    super.key,
    required this.config,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // drag handle
          const Icon(Icons.drag_handle_rounded,
              color: Colors.white24, size: 20),
          const SizedBox(width: 12),
          // icon
          Icon(config.icon,
              color: config.visible
                  ? const Color(0xFF00BFA6)
                  : Colors.white24,
              size: 20),
          const SizedBox(width: 10),
          // label
          Expanded(
            child: Text(
              config.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: config.visible ? Colors.white : Colors.white38,
              ),
            ),
          ),
          // toggle
          Switch.adaptive(
            value: config.visible,
            onChanged: onToggle,
            activeTrackColor: const Color(0xFF00BFA6),
          ),
        ],
      ),
    );
  }
}
