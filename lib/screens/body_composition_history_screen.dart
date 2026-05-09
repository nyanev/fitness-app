import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/body_composition_entry.dart';
import '../services/body_composition_service.dart';
import '../theme/app_theme.dart';
import 'add_body_composition_screen.dart';

class BodyCompositionHistoryScreen extends StatefulWidget {
  const BodyCompositionHistoryScreen({super.key});

  @override
  State<BodyCompositionHistoryScreen> createState() =>
      _BodyCompositionHistoryScreenState();
}

class _BodyCompositionHistoryScreenState
    extends State<BodyCompositionHistoryScreen> {
  final _service = BodyCompositionService.instance;
  List<BodyCompositionEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.listEntries();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openEdit(BodyCompositionEntry e) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddBodyCompositionScreen(existing: e)),
    );
    if (changed == true) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversed = [..._entries.reversed];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('All Measurements'),
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : reversed.isEmpty
              ? const Center(
                  child: Text(
                    'No measurements yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: reversed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 1),
                  itemBuilder: (context, index) {
                    final e = reversed[index];
                    final isFirst = index == 0;
                    return ListTile(
                      tileColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: index == 0
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottom: index == reversed.length - 1
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                      ),
                      title: Text(
                        '${e.weightKg.toStringAsFixed(2)} kg'
                        '${e.bodyFatPct != null ? ' · ${e.bodyFatPct!.toStringAsFixed(1)}% fat' : ''}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: isFirst
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy').format(e.dateOnly),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => _openEdit(e),
                    );
                  },
                ),
    );
  }
}
