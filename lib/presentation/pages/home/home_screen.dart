// lib/presentation/pages/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_pending_card.dart';
import '../login/login_screen.dart';
import '../expenses/daily_entry_screen.dart';
import '../expenses/summary_screen.dart';
import '../members/members_screen.dart';
import '../food/food_menu_screen.dart';
import '../admin/collect_cash_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  String get _name => (user['name'] ?? '') as String;
  String get _role => (user['role'] ?? 'member') as String;
  String get _teamName => (user['teamName'] ?? '') as String;
  String get _teamCode => (user['teamCode'] ?? '') as String;
  String get _teamId => (user['teamId'] ?? '') as String;
  String? get _memberId => user['memberId'] as String?;
  bool get _isAdmin => _role == 'admin';

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _teamCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Team code copied')),
    );
  }

  void _openCollectCash(BuildContext context) {
    _open(
      context,
      CollectCashScreen(
        teamId: _teamId,
        adminId: _memberId ?? 'admin',
      ),
    );
  }

  Widget _actionTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius:
                BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // stop the back button from leaving the home page
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('LunchMate'),
          actions: [
            // LIGHT / DARK TOGGLE
            IconButton(
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: () => ThemeController.toggle(context),
            ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WELCOME CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLarge),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $_name 👋',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        '$_teamName  •  ${_isAdmin ? 'Admin' : 'Member'}',
                        style: AppTextStyles.body.copyWith(
                          color: colors.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.xl),

                // ADMIN ONLY: total amount still to receive (live)
                if (_isAdmin && _teamId.isNotEmpty) ...[
                  AdminPendingCard(
                    teamId: _teamId,
                    onTap: () => _openCollectCash(context),
                  ),
                  const SizedBox(height: AppDimensions.xl),
                ],

                // TEAM CODE (admins only)
                if (_isAdmin && _teamCode.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outline),
                      borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TEAM INVITATION CODE',
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.onSurfaceVariant,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.xs),
                              SelectableText(
                                _teamCode,
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: colors.onSurface,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy code',
                          icon: Icon(Icons.copy, color: colors.onSurface),
                          onPressed: () => _copyCode(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xl),
                ],

                Text(
                  'Quick Actions',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppDimensions.md,
                  crossAxisSpacing: AppDimensions.md,
                  childAspectRatio: 1.1,
                  children: [
                    // Admin only: enter each person's amount for a day
                    if (_isAdmin)
                      _actionTile(
                        context,
                        icon: Icons.edit_calendar_rounded,
                        title: 'Add Daily Lunch',
                        onTap: () => _open(
                          context,
                          DailyEntryScreen(teamId: _teamId),
                        ),
                      ),

                    // Admin: all people totals | Member: own totals
                    _actionTile(
                      context,
                      icon: Icons.receipt_long_rounded,
                      title: _isAdmin ? 'Weekly / Monthly' : 'My Expenses',
                      onTap: () => _open(
                        context,
                        SummaryScreen(
                          teamId: _teamId,
                          isAdmin: _isAdmin,
                          memberId: _memberId,
                        ),
                      ),
                    ),

                    // Admin only: list of all members
                    if (_isAdmin)
                      _actionTile(
                        context,
                        icon: Icons.groups_rounded,
                        title: 'Members',
                        onTap: () => _open(
                          context,
                          MembersScreen(teamId: _teamId),
                        ),
                      ),

                    // Admin only: manage the food menu
                    if (_isAdmin)
                      _actionTile(
                        context,
                        icon: Icons.restaurant_menu_rounded,
                        title: 'Food Menu',
                        onTap: () => _open(
                          context,
                          FoodMenuScreen(teamId: _teamId),
                        ),
                      ),

                    // Admin only: collect cash (pending balance updates itself)
                    if (_isAdmin)
                      _actionTile(
                        context,
                        icon: Icons.payments_rounded,
                        title: 'Collect Cash',
                        onTap: () => _openCollectCash(context),
                      ),

                    _actionTile(
                      context,
                      icon: Icons.history_rounded,
                      title: 'History',
                      onTap: () => _comingSoon(context, 'History'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}