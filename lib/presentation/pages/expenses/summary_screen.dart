import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/payment_config.dart';
import '../../../domain/usecases/lunch_expense_service.dart';

enum _Period { week, month }

class SummaryScreen extends StatefulWidget {
  final String teamId;
  final bool isAdmin;
  final String? memberId; // null for admin

  const SummaryScreen({
    super.key,
    required this.teamId,
    required this.isAdmin,
    this.memberId,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late final LunchExpenseService _service =
  LunchExpenseService(FirebaseFirestore.instance);

  _Period _period = _Period.week;
  DateTime _anchor = DateTime.now();
  List<LunchEntry> _entries = [];
  PaymentInfo? _payment;
  double _pending = 0; // all-time unpaid (entries minus cash collected)
  bool _loading = true;
  String? _error;

  // Week = Monday to Sunday, Month = 1st to last day.
  DateTime get _start {
    final a = _anchor;
    if (_period == _Period.week) {
      return DateTime(a.year, a.month, a.day - (a.weekday - 1));
    }
    return DateTime(a.year, a.month, 1);
  }

  DateTime get _end {
    final s = _start;
    if (_period == _Period.week) {
      return DateTime(s.year, s.month, s.day + 6);
    }
    return DateTime(s.year, s.month + 1, 0);
  }

  String get _rangeLabel => _period == _Period.week
      ? '${formatShortDate(_start)} – ${formatShortDate(_end)} ${_end.year}'
      : formatMonthYear(_start);

  @override
  void initState() {
    super.initState();
    _load();
    _loadPayment();
  }

  // UPI ID from payment_config.dart wins; otherwise the one the admin saved.
  String get _upiId =>
      kUpiId.trim().isNotEmpty ? kUpiId.trim() : (_payment?.upiId ?? '');

  String get _payeeName => kPayeeName.trim().isNotEmpty
      ? kPayeeName.trim()
      : (_payment?.payeeName ?? 'Admin');

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
      _loading = true;
      _error = null;
    });

    try {
      final memberId = widget.isAdmin ? null : widget.memberId;

      final entries = await _service.getEntries(
        teamId: widget.teamId,
        start: _start,
        end: _end,
        memberId: memberId,
      );
      final pendingMap = await _service.getPendingByMember(
        widget.teamId,
        memberId: memberId,
      );

      // Admin view: skip the admin's own lunch (nobody can pay it), so this
      // matches the "Total to receive" card on the home screen.
      // Advance payments (negative) are ignored so they don't cancel dues.
      final pending = pendingMap.entries
          .where((e) => !(widget.isAdmin && e.key == 'admin'))
          .fold<double>(
        0.0,
            (s, e) => s + (e.value > 0 ? (e.value * 100).round() / 100 : 0),
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _pending = pending;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPayment() async {
    try {
      final info = await _service.getPaymentInfo(widget.teamId);
      if (!mounted) return;
      setState(() => _payment = info);
    } catch (_) {
      // Payment info is optional; the list still works without it.
    }
  }

  void _shift(int dir) {
    final a = _anchor;
    _anchor = _period == _Period.week
        ? DateTime(a.year, a.month, a.day + 7 * dir)
        : DateTime(a.year, a.month + dir, 1);
    _load();
  }

  double _sum(List<LunchEntry> list) =>
      list.fold(0.0, (s, e) => s + e.amount);

  // ---------------- ADMIN: set UPI ID ----------------
  Future<void> _editUpiId() async {
    final c = TextEditingController(text: _payment?.upiId ?? '');

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your UPI ID'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'example@okaxis'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || value == null) return;

    if (!RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(value)) {
      _snack('Enter a valid UPI ID like name@bank', error: true);
      return;
    }

    try {
      await _service.saveUpiId(widget.teamId, value);
      await _loadPayment();
      if (mounted) _snack('UPI ID saved');
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  // ---------------- MEMBER: Pay Now ----------------
  Future<void> _payNow(double amount) async {
    final upiId = _upiId;

    if (upiId.isEmpty) {
      _snack(
        'Your admin has not added a UPI ID yet. Please ask the admin.',
        error: true,
      );
      return;
    }

    // Keep '@' in the UPI ID as-is: encoding it as %40 makes some UPI apps
    // fail to read the receiver, so the bank name never loads.
    final query = [
      'pa=$upiId',
      'pn=${Uri.encodeComponent(_payeeName)}',
      'am=${amount.toStringAsFixed(2)}',
      'cu=INR',
      'tn=${Uri.encodeComponent('LunchMate lunch bill')}',
    ].join('&');
    final uri = Uri.parse('upi://pay?$query');

    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched && mounted) _showNoUpiApp(upiId);
  }

  void _showNoUpiApp(String upiId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No UPI app found'),
        content: Text(
          'Install a UPI app (Google Pay, PhonePe, Paytm) or pay manually to:\n\n$upiId',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: upiId));
              Navigator.pop(ctx);
              _snack('UPI ID copied');
            },
            child: const Text('Copy UPI ID'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // group entries by person
    final byPerson = <String, List<LunchEntry>>{};
    final names = <String, String>{};
    for (final e in _entries) {
      byPerson.putIfAbsent(e.memberId, () => []).add(e);
      names[e.memberId] = e.memberName;
    }
    final ids = byPerson.keys.toList()
      ..sort((a, b) =>
          names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase()));

    final upiSet = (_payment?.upiId ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Expenses' : 'My Expenses'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: SegmentedButton<_Period>(
                segments: const [
                  ButtonSegment(value: _Period.week, label: Text('Weekly')),
                  ButtonSegment(value: _Period.month, label: Text('Monthly')),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  _load();
                },
              ),
            ),

            // RANGE NAVIGATOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label
                          .copyWith(color: colors.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
            ),

            // TOTAL CARD (all-time pending = entries - cash collected)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.lg),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isAdmin ? 'Total to collect' : 'You owe',
                      style: AppTextStyles.body
                          .copyWith(color: colors.onPrimaryContainer),
                    ),
                    Text(
                      formatMoney(_pending),
                      style: AppTextStyles.headingMedium
                          .copyWith(color: colors.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),

            // ADMIN: UPI ID card (hidden when kUpiId is set in payment_config.dart)
            if (widget.isAdmin && kUpiId.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg,
                  0,
                  AppDimensions.lg,
                  AppDimensions.md,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                    vertical: AppDimensions.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outline),
                    borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: colors.primary),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Text(
                          upiSet
                              ? 'Collect on UPI: ${_payment!.upiId}'
                              : 'Add your UPI ID so members can pay you',
                          style: AppTextStyles.caption
                              .copyWith(color: colors.onSurface),
                        ),
                      ),
                      TextButton(
                        onPressed: _editUpiId,
                        child: Text(upiSet ? 'Edit' : 'Add'),
                      ),
                    ],
                  ),
                ),
              ),

            // PER-PERSON LIST
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
                  : ids.isEmpty
                  ? Center(
                child: Text(
                  'No lunch entries for this period.',
                  style: AppTextStyles.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                ),
                itemCount: ids.length,
                itemBuilder: (context, i) {
                  final id = ids[i];
                  final list = byPerson[id]!;

                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: AppDimensions.sm,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        id == 'admin'
                            ? '${names[id]} (Admin)'
                            : names[id]!,
                        style: AppTextStyles.label.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${list.length} day${list.length == 1 ? '' : 's'}',
                      ),
                      trailing: Text(
                        formatMoney(_sum(list)),
                        style: AppTextStyles.label.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      children: [
                        for (final e in list)
                          ListTile(
                            dense: true,
                            title: Text(
                              formatFullDate(
                                DateTime.parse(e.date),
                              ),
                            ),
                            subtitle: (e.foodName.isEmpty && e.note.isEmpty)
                                ? null
                                : Text([
                              if (e.foodName.isNotEmpty)
                                e.foodName,
                              if (e.note.isNotEmpty)
                                e.note,
                            ].join(' + ')),
                            trailing: Text(formatMoney(e.amount)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // MEMBER: PAY NOW (hidden once nothing is pending)
            if (!widget.isAdmin && !_loading && _pending > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outline)),
                ),
                child: SizedBox(
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: () => _payNow(_pending),
                    icon: const Icon(Icons.payments_rounded),
                    label: Text('Pay Now  ${formatMoney(_pending)}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}