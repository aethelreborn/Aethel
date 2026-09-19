import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';

class FocusPanelScreen extends StatefulWidget {
  const FocusPanelScreen({super.key});
  @override
  State<FocusPanelScreen> createState() => _FocusPanelScreenState();
}

class _FocusPanelScreenState extends State<FocusPanelScreen> {
  bool _active = false;
  int _secondsLeft = 0;

  void _startBlock(int minutes) {
    setState(() { _active = true; _secondsLeft = minutes * 60; });
  }

  void _endBlock() {
    setState(() { _active = false; _secondsLeft = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Blocker'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_active) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.urgentDark.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('Blocking...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${(_secondsLeft ~/ 60)}min ${(_secondsLeft % 60).toString().padLeft(2, '0')}s left', style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _endBlock, child: const Text('End Session')),
            ]),
          ),
          const SizedBox(height: 24),
        ],
        const Text('Quick Start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [15, 30, 45, 60, 90].map((m) => ElevatedButton(onPressed: () => _startBlock(m), child: Text('$m min'))).toList()),
        const SizedBox(height: 32),
        const Text('Blocked Apps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...['Instagram', 'TikTok', 'YouTube', 'Twitter/X'].map((app) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [Icon(Icons.block, color: AppColors.urgentLight), const SizedBox(width: 12), Text(app, style: const TextStyle(fontWeight: FontWeight.w500)), const Spacer(), Switch(value: true, onChanged: (_) {})]),
        )),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: () {}, child: const Text('Manage Schedules')),
      ]))),
    );
  }
}
