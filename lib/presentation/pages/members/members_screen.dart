import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/usecases/lunch_expense_service.dart';

class _Person {
  final String name;
  final String email;
  final String mobile;
  final bool isAdmin;
  final bool isActive;
  final DateTime? joinedAt;

  const _Person({
    required this.name,
    required this.email,
    required this.mobile,
    required this.isAdmin,
    required this.isActive,
    this.joinedAt,
  });
}

class MembersScreen extends StatefulWidget {
  final String teamId;

  const MembersScreen({super.key, required this.teamId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<_Person> _people = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _people.isEmpty;
      _error = null;
    });

    try {
      final teamRef =
      FirebaseFirestore.instance.collection('teams').doc(widget.teamId);

      final teamDoc = await teamRef.get();
      final admin = (teamDoc.data()?['admin'] as Map<String, dynamic>?) ?? {};
      final membersSnap = await teamRef.collection('members').get();

      final members = membersSnap.docs.map((d) {
        final data = d.data();
        return _Person(
          name: (data['name'] ?? '') as String,
          email: (data['email'] ?? '') as String,
          mobile: (data['mobile'] ?? '') as String,
          isAdmin: false,
          isActive: data['isActive'] != false,
          joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final people = <_Person>[
        _Person(
          name: (admin['name'] ?? 'Admin') as String,
          email: (admin['email'] ?? '') as String,
          mobile: (admin['mobile'] ?? '') as String,
          isAdmin: true,
          isActive: true,
          joinedAt: (teamDoc.data()?['createdAt'] as Timestamp?)?.toDate(),
        ),
        ...members,
      ];

      if (!mounted) return;
      setState(() => _people = people);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _personCard(_Person p) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final joined = p.joinedAt;

    return Opacity(
      opacity: p.isActive ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: Text(
                p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label
                              .copyWith(color: colors.onSurface),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.isAdmin
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.isAdmin ? 'Admin' : 'Member',
                          style: AppTextStyles.caption.copyWith(
                            color: p.isAdmin ? colors.primary : muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (!p.isActive) ...[
                        const SizedBox(width: AppDimensions.sm),
                        Text(
                          'Inactive',
                          style: AppTextStyles.caption.copyWith(color: muted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  if (p.mobile.isNotEmpty)
                    Text(
                      p.mobile,
                      style: AppTextStyles.caption.copyWith(color: muted),
                    ),
                  if (p.email.isNotEmpty)
                    Text(
                      p.email,
                      style: AppTextStyles.caption.copyWith(color: muted),
                    ),
                  if (joined != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.xs),
                      child: Text(
                        '${p.isAdmin ? 'Created team' : 'Joined'} '
                            '${formatShortDate(joined)} ${joined.year}',
                        style: AppTextStyles.caption.copyWith(color: muted),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.lg),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Text(_error!, textAlign: TextAlign.center),
                )
              else ...[
                Container(
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
                        'People in your team',
                        style: AppTextStyles.body
                            .copyWith(color: colors.onPrimaryContainer),
                      ),
                      Text(
                        '${_people.length}',
                        style: AppTextStyles.headingMedium
                            .copyWith(color: colors.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                for (final p in _people) ...[
                  _personCard(p),
                  const SizedBox(height: AppDimensions.sm),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}