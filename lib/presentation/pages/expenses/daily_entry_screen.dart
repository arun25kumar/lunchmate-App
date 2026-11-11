import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/usecases/lunch_expense_service.dart';

class DailyEntryScreen extends StatefulWidget {
  final String teamId;

  const DailyEntryScreen({super.key, required this.teamId});

  @override
  State<DailyEntryScreen> createState() => _DailyEntryScreenState();
}

class _DailyEntryScreenState extends State<DailyEntryScreen> {
  late final LunchExpenseService _service =
  LunchExpenseService(FirebaseFirestore.instance);

  DateTime _date = DateTime.now();
  List<MemberInfo> _people = [];
  List<FoodItem> _foods = [];

  final Map<String, TextEditingController> _controllers = {}; // amount
  final Map<String, TextEditingController> _noteControllers = {}; // extra food
  final Map<String, String?> _foodIds = {}; // selected food per person

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isToday =>
      LunchExpenseService.dateKey(_date) ==
          LunchExpenseService.dateKey(DateTime.now());

  double get _total => _people.fold(
    0.0,
        (sum, p) =>
    sum +
        (double.tryParse(_controllers[p.id]?.text.trim() ?? '') ?? 0),
  );

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      if (_people.isEmpty) {
        _people = await _service.getPeople(widget.teamId);
      }
      final foods = await _service.getFoods(widget.teamId);
      final entries =
      await _service.getEntriesForDate(widget.teamId, _date);

      // Keep a food that was used earlier even if it was deleted from the menu.
      for (final e in entries.values) {
        if (e.foodId.isNotEmpty && !foods.any((f) => f.id == e.foodId)) {
          foods.add(FoodItem(id: e.foodId, name: e.foodName, price: 0));
        }
      }
      _foods = foods;

      for (final p in _people) {
        final entry = entries[p.id];

        _controllers.putIfAbsent(p.id, () => TextEditingController()).text =
        entry == null ? '' : formatNumber(entry.amount);
        _noteControllers
            .putIfAbsent(p.id, () => TextEditingController())
            .text = entry?.note ?? '';
        _foodIds[p.id] =
        (entry == null || entry.foodId.isEmpty) ? null : entry.foodId;
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeDay(int delta) {
    _date = DateTime(_date.year, _date.month, _date.day + delta);
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    _date = picked;
    _load();
  }

  // Choosing a food fills the amount with its price (if the food has one).
  void _selectFood(String personId, String? foodId) {
    setState(() {
      if (foodId == null || foodId.isEmpty) {
        _foodIds[personId] = null;
        return;
      }

      _foodIds[personId] = foodId;

      final food = _foods.where((f) => f.id == foodId).firstOrNull;
      if (food != null && food.price > 0) {
        _controllers[personId]!.text = formatNumber(food.price);
      }
    });
  }

  Future<void> _fillAll() async {
    final c = TextEditingController();

    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Same amount for everyone'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: 'Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(c.text.trim())),
            child: const Text('Fill'),
          ),
        ],
      ),
    );

    if (value == null || value <= 0) return;

    setState(() {
      for (final ctrl in _controllers.values) {
        ctrl.text = formatNumber(value);
      }
    });
  }

  Future<void> _save() async {
    final inputs = <String, EntryInput>{};
    final missingAmount = <String>[];

    for (final p in _people) {
      final amount = double.tryParse(_controllers[p.id]!.text.trim()) ?? 0.0;
      final foodId = _foodIds[p.id];
      final food = foodId == null
          ? null
          : _foods.where((f) => f.id == foodId).firstOrNull;
      final note = _noteControllers[p.id]!.text.trim();

      // food or note typed, but no amount -> ask the admin to fill the amount
      if (amount <= 0 && (foodId != null || note.isNotEmpty)) {
        missingAmount.add(p.name);
      }

      inputs[p.id] = EntryInput(
        amount: amount,
        foodId: foodId,
        foodName: food?.name ?? '',
        note: note,
      );
    }

    if (missingAmount.isNotEmpty) {
      _showMessage(
        'Enter an amount for: ${missingAmount.join(', ')}',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.saveDay(
        teamId: widget.teamId,
        date: _date,
        people: _people,
        inputs: inputs,
      );

      if (!mounted) return;
      _showMessage('Saved for ${formatFullDate(_date)}');
    } catch (e) {
      if (mounted) _showMessage(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _foodDropdown(String personId) {
    return InputDecorator(
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: 2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _foodIds[personId],
          isExpanded: true,
          hint: const Text('Select food'),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('— No food —'),
            ),
            for (final f in _foods)
              DropdownMenuItem<String>(
                value: f.id,
                child: Text(
                  f.price > 0 ? '${f.name}  •  ${formatMoney(f.price)}' : f.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => _selectFood(personId, v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Lunch Entry'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _fillAll,
            child: const Text('Fill all'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // DATE SELECTOR
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _changeDay(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.md,
                          ),
                          child: Text(
                            formatFullDate(_date),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.label
                                .copyWith(color: colors.onSurface),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _isToday ? null : () => _changeDay(1),
                    ),
                  ],
                ),
              ),
            ),

            // PEOPLE LIST
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                ),
                itemCount: _people.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.sm),
                itemBuilder: (context, i) {
                  final p = _people[i];

                  return Container(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outline),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    child: Column(
                      children: [
                        // name + amount
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.id == 'admin'
                                    ? '${p.name} (Admin)'
                                    : p.name,
                                style: AppTextStyles.label
                                    .copyWith(color: colors.onSurface),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _controllers[p.id],
                                keyboardType: const TextInputType
                                    .numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                textAlign: TextAlign.end,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  hintText: '0',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.sm),

                        // food dropdown
                        _foodDropdown(p.id),
                        const SizedBox(height: AppDimensions.sm),

                        // extra food note
                        TextField(
                          controller: _noteControllers[p.id],
                          textCapitalization:
                          TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Extra items (e.g. sambar)',
                            prefixIcon:
                            Icon(Icons.edit_note_rounded),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // TOTAL + SAVE
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outline)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Day total',
                        style: AppTextStyles.body
                            .copyWith(color: colors.onSurfaceVariant),
                      ),
                      Text(
                        formatMoney(_total),
                        style: AppTextStyles.headingSmall
                            .copyWith(color: colors.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed: (_loading || _saving) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                        height: 23,
                        width: 23,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}