import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/usecases/lunch_expense_service.dart';

class FoodMenuScreen extends StatefulWidget {
  final String teamId;

  const FoodMenuScreen({super.key, required this.teamId});

  @override
  State<FoodMenuScreen> createState() => _FoodMenuScreenState();
}

class _FoodMenuScreenState extends State<FoodMenuScreen> {
  late final LunchExpenseService _service =
  LunchExpenseService(FirebaseFirestore.instance);

  List<FoodItem> _foods = [];
  bool _loading = true;
  String? _error;

  static const _sampleFoods = [
    'Biryani Half',
    'Sam Chacha Mixing',
    'Sam Chacha White Rice',
    'Mr Chef',
    'Brinji Rice',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = _foods.isEmpty;
      _error = null;
    });

    try {
      final foods = await _service.getFoods(widget.teamId);
      if (!mounted) return;
      setState(() => _foods = foods);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<(String, double)?> _foodDialog({FoodItem? food}) {
    final nameC = TextEditingController(text: food?.name ?? '');
    final priceC = TextEditingController(
      text: (food == null || food.price <= 0) ? '' : formatNumber(food.price),
    );

    return showDialog<(String, double)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(food == null ? 'Add food' : 'Edit food'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Food name (e.g. Biryani Half)',
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: priceC,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Price (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (
            nameC.text.trim(),
            double.tryParse(priceC.text.trim()) ?? 0.0,
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEdit({FoodItem? food}) async {
    final result = await _foodDialog(food: food);
    if (!mounted || result == null) return;

    final (name, price) = result;

    if (name.isEmpty) {
      _snack('Enter a food name', error: true);
      return;
    }

    final duplicate = _foods.any(
          (f) => f.id != food?.id && f.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      _snack('"$name" is already in the menu', error: true);
      return;
    }

    try {
      if (food == null) {
        await _service.addFood(widget.teamId, name, price);
      } else {
        await _service.updateFood(widget.teamId, food.id, name, price);
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  Future<void> _delete(FoodItem food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${food.name}?'),
        content: const Text('Past lunch entries will keep this food name.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) return;

    try {
      await _service.deleteFood(widget.teamId, food.id);
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  Future<void> _addSamples() async {
    try {
      await _service.addFoods(widget.teamId, _sampleFoods);
      await _load();
      if (mounted) _snack('Added. Tap a food to set its price.');
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Food Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add food'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        )
            : _foods.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No food added yet.',
                  style: AppTextStyles.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                OutlinedButton.icon(
                  onPressed: _addSamples,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Add sample items'),
                ),
              ],
            ),
          ),
        )
            : ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            96, // space for the floating button
          ),
          itemCount: _foods.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.sm),
          itemBuilder: (context, i) {
            final f = _foods[i];

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusMedium,
                ),
              ),
              child: ListTile(
                onTap: () => _addOrEdit(food: f),
                leading: Icon(
                  Icons.restaurant_rounded,
                  color: colors.primary,
                ),
                title: Text(
                  f.name,
                  style: AppTextStyles.label
                      .copyWith(color: colors.onSurface),
                ),
                subtitle: Text(
                  f.price > 0
                      ? formatMoney(f.price)
                      : 'No price set',
                ),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(f),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}