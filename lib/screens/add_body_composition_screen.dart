import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/body_composition_entry.dart';
import '../services/body_composition_service.dart';
import '../theme/app_theme.dart';

class AddBodyCompositionScreen extends StatefulWidget {
  final BodyCompositionEntry? existing;

  const AddBodyCompositionScreen({super.key, this.existing});

  @override
  State<AddBodyCompositionScreen> createState() => _AddBodyCompositionScreenState();
}

enum _PairLead { none, pct, kg }

class _AddBodyCompositionScreenState extends State<AddBodyCompositionScreen> {
  final _service = BodyCompositionService.instance;
  late DateTime _date;
  final _weight = TextEditingController();
  final _bodyFatPct = TextEditingController();
  final _bodyFatKg = TextEditingController();
  final _musclePct = TextEditingController();
  final _muscleKg = TextEditingController();
  final _ffm = TextEditingController();
  final _waterPct = TextEditingController();
  final _visceral = TextEditingController();
  final _bone = TextEditingController();
  final _proteinPct = TextEditingController();
  bool _saving = false;
  bool _suppressPairSync = false;
  _PairLead _bodyFatLead = _PairLead.none;
  _PairLead _muscleLead = _PairLead.none;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = e.dateOnly;
      _weight.text = e.weightKg.toString();
      _bodyFatPct.text = e.bodyFatPct?.toString() ?? '';
      _bodyFatKg.text = e.bodyFatKg?.toString() ?? '';
      _musclePct.text = e.skeletalMuscleMassPct?.toString() ?? '';
      _muscleKg.text = e.skeletalMuscleMassKg?.toString() ?? '';
      _ffm.text = e.fatFreeMassKg?.toString() ?? '';
      _waterPct.text = e.bodyWaterPct?.toString() ?? '';
      _visceral.text = e.visceralFat?.toString() ?? '';
      _bone.text = e.boneMineralKg?.toString() ?? '';
      _proteinPct.text = e.proteinPct?.toString() ?? '';
    } else {
      final n = DateTime.now();
      _date = DateTime(n.year, n.month, n.day);
    }
    _weight.addListener(_onWeightChanged);
    _bodyFatPct.addListener(_onBodyFatPctChanged);
    _bodyFatKg.addListener(_onBodyFatKgChanged);
    _musclePct.addListener(_onMusclePctChanged);
    _muscleKg.addListener(_onMuscleKgChanged);
  }

  static String _formatDerived(double v) {
    if (!v.isFinite) return '';
    return v.toStringAsFixed(2);
  }

  void _setText(TextEditingController c, String text) {
    if (c.text == text) return;
    _suppressPairSync = true;
    c.text = text;
    _suppressPairSync = false;
  }

  void _onBodyFatPctChanged() {
    if (_suppressPairSync) return;
    _bodyFatLead = _PairLead.pct;
    final w = _parse(_weight.text);
    final p = _parse(_bodyFatPct.text);
    if (w != null && w > 0 && p != null && p >= 0) {
      _setText(_bodyFatKg, _formatDerived(w * p / 100.0));
    }
  }

  void _onBodyFatKgChanged() {
    if (_suppressPairSync) return;
    _bodyFatLead = _PairLead.kg;
    final w = _parse(_weight.text);
    final k = _parse(_bodyFatKg.text);
    if (w != null && w > 0 && k != null && k >= 0) {
      _setText(_bodyFatPct, _formatDerived(k / w * 100.0));
    }
  }

  void _onMusclePctChanged() {
    if (_suppressPairSync) return;
    _muscleLead = _PairLead.pct;
    final w = _parse(_weight.text);
    final p = _parse(_musclePct.text);
    if (w != null && w > 0 && p != null && p >= 0) {
      _setText(_muscleKg, _formatDerived(w * p / 100.0));
    }
  }

  void _onMuscleKgChanged() {
    if (_suppressPairSync) return;
    _muscleLead = _PairLead.kg;
    final w = _parse(_weight.text);
    final k = _parse(_muscleKg.text);
    if (w != null && w > 0 && k != null && k >= 0) {
      _setText(_musclePct, _formatDerived(k / w * 100.0));
    }
  }

  void _onWeightChanged() {
    if (_suppressPairSync) return;
    final w = _parse(_weight.text);
    if (w == null || w <= 0) return;

    final fatP = _parse(_bodyFatPct.text);
    final fatK = _parse(_bodyFatKg.text);
    if (_bodyFatLead == _PairLead.pct && fatP != null && fatP >= 0) {
      _setText(_bodyFatKg, _formatDerived(w * fatP / 100.0));
    } else if (_bodyFatLead == _PairLead.kg && fatK != null && fatK >= 0) {
      _setText(_bodyFatPct, _formatDerived(fatK / w * 100.0));
    } else if (_bodyFatLead == _PairLead.none) {
      if (fatP != null && fatP >= 0) {
        _setText(_bodyFatKg, _formatDerived(w * fatP / 100.0));
      } else if (fatK != null && fatK >= 0) {
        _setText(_bodyFatPct, _formatDerived(fatK / w * 100.0));
      }
    }

    final musP = _parse(_musclePct.text);
    final musK = _parse(_muscleKg.text);
    if (_muscleLead == _PairLead.pct && musP != null && musP >= 0) {
      _setText(_muscleKg, _formatDerived(w * musP / 100.0));
    } else if (_muscleLead == _PairLead.kg && musK != null && musK >= 0) {
      _setText(_musclePct, _formatDerived(musK / w * 100.0));
    } else if (_muscleLead == _PairLead.none) {
      if (musP != null && musP >= 0) {
        _setText(_muscleKg, _formatDerived(w * musP / 100.0));
      } else if (musK != null && musK >= 0) {
        _setText(_musclePct, _formatDerived(musK / w * 100.0));
      }
    }
  }

  @override
  void dispose() {
    _weight.removeListener(_onWeightChanged);
    _bodyFatPct.removeListener(_onBodyFatPctChanged);
    _bodyFatKg.removeListener(_onBodyFatKgChanged);
    _musclePct.removeListener(_onMusclePctChanged);
    _muscleKg.removeListener(_onMuscleKgChanged);
    _weight.dispose();
    _bodyFatPct.dispose();
    _bodyFatKg.dispose();
    _musclePct.dispose();
    _muscleKg.dispose();
    _ffm.dispose();
    _waterPct.dispose();
    _visceral.dispose();
    _bone.dispose();
    _proteinPct.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final w = _parse(_weight.text);
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight (kg).')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.create(
        measuredAt: _date,
        weightKg: w,
        bodyFatPct: _parse(_bodyFatPct.text),
        bodyFatKg: _parse(_bodyFatKg.text),
        skeletalMuscleMassPct: _parse(_musclePct.text),
        skeletalMuscleMassKg: _parse(_muscleKg.text),
        fatFreeMassKg: _parse(_ffm.text),
        bodyWaterPct: _parse(_waterPct.text),
        visceralFat: _parse(_visceral.text),
        boneMineralKg: _parse(_bone.text),
        proteinPct: _parse(_proteinPct.text),
        id: widget.existing?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text(widget.existing == null ? 'Add measurement' : 'Edit measurement'),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date', style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              DateFormat.yMMMd().format(_date),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today_outlined, color: AppColors.accent),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          _field('Weight (kg) *', _weight, required: true),
          _field('Body fat %', _bodyFatPct),
          _field('Body fat kg', _bodyFatKg),
          _field('Skeletal muscle %', _musclePct),
          _field('Skeletal muscle kg', _muscleKg),
          _field('Fat-free mass kg', _ffm),
          _field('Body water %', _waterPct),
          _field('Visceral fat', _visceral, digits: true),
          _field('Bone mineral kg', _bone),
          _field('Protein %', _proteinPct),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool required = false, bool digits = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: digits
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
            : [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]'))],
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}
