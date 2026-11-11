import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/service/biometric_service.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../home/home_screen.dart';
import '../team/create_team_screen.dart';
import '../team/join_team_screen.dart';
import '../../../domain/usecases/login_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _employeeController = TextEditingController();
  final _pinController = TextEditingController();
  late final LoginUser _loginUser = LoginUser(FirebaseFirestore.instance);
  final BiometricService _biometric = BiometricService();

  bool _obscurePin = true;
  bool _isLoading = false;
  bool _biometricReady = false; // phone supports it AND user enabled it

  @override
  void initState() {
    super.initState();
    // Show the fingerprint prompt automatically when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBiometric(autoPrompt: true);
    });
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ---------------- FINGERPRINT ----------------

  Future<void> _initBiometric({bool autoPrompt = false}) async {
    final available = await _biometric.isAvailable();
    final enabled = available && await _biometric.isEnabled();

    if (!mounted) return;
    setState(() => _biometricReady = enabled);

    if (enabled && autoPrompt) _handleBiometricLogin();
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    final ok = await _biometric.authenticate('Login to LunchMate');
    if (!ok || !mounted) return;

    final creds = await _biometric.readCredentials();
    if (creds == null) {
      if (mounted) setState(() => _biometricReady = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _loginUser(
        identifier: creds['identifier']!,
        pin: creds['pin']!,
      );
      if (!mounted) return;
      _goHome(user);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');

      // PIN changed or account removed: stop using the saved login.
      if (message.contains('Invalid email/mobile number or PIN')) {
        await _biometric.disable();
        if (mounted) setState(() => _biometricReady = false);
        _showError(
          'Your saved login is no longer valid. Please login with your PIN.',
        );
      } else {
        _showError(message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// After a PIN login, offer to turn on fingerprint login.
  Future<void> _offerEnableBiometric(String identifier, String pin) async {
    if (!await _biometric.isAvailable()) return;

    final saved = await _biometric.savedIdentifier();
    final alreadyThisUser =
        saved != null && saved == identifier.trim().toLowerCase();
    if (alreadyThisUser) {
      // Keep the saved PIN in sync with the one that just worked.
      await _biometric.enable(identifier: saved, pin: pin);
      return;
    }

    if (!mounted) return;
    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable fingerprint login?'),
        content: const Text(
          'Next time you can login with your fingerprint instead of typing your PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (wantsIt != true) return;

    // Confirm with a fingerprint before saving.
    final ok = await _biometric.authenticate('Confirm to enable fingerprint');
    if (!ok) return;

    await _biometric.enable(
      identifier: identifier.trim().toLowerCase(),
      pin: pin,
    );
  }

  // ---------------- LOGIN ----------------

  void _goHome(Map<String, dynamic> user) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
          (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Welcome ${user['name']} (${user['role']}) - ${user['teamName']}',
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final identifier = _employeeController.text;
      final pin = _pinController.text;

      final user = await _loginUser(identifier: identifier, pin: pin);

      if (!mounted) return;

      await _offerEnableBiometric(identifier, pin);

      if (!mounted) return;
      _goHome(user);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCreateTeam() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateTeamScreen(),
      ),
    );
  }

  void _navigateToJoinTeam() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JoinTeamScreen(),
      ),
    );
  }

  void _showTeamOptions() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            AppDimensions.radiusExtraLarge,
          ),
        ),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get Started with LunchMate',
                style: AppTextStyles.headingSmall.copyWith(
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: AppDimensions.sm),

              Text(
                'Create a new team or join your existing team.',
                style: AppTextStyles.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppDimensions.xxl),

              _teamOption(
                icon: Icons.add_business_rounded,
                title: 'Create a Team',
                subtitle: 'Start a new lunch expense group',
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _navigateToCreateTeam();
                },
              ),

              const SizedBox(height: AppDimensions.md),

              _teamOption(
                icon: Icons.groups_rounded,
                title: 'Join a Team',
                subtitle: 'Join using your team invitation code',
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _navigateToJoinTeam();
                },
              ),

              const SizedBox(height: AppDimensions.sm),
            ],
          ),
        );
      },
    );
  }

  Widget _teamOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppDimensions.radiusMedium,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(
            AppDimensions.radiusMedium,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusMedium,
                ),
              ),
              child: Icon(
                icon,
                color: colors.primary,
              ),
            ),

            const SizedBox(width: AppDimensions.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: AppDimensions.xs),

                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xxl,
              vertical: AppDimensions.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 76,
                        width: 76,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppDimensions.xl),

                    Text(
                      'LunchMate',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingLarge.copyWith(
                        color: colors.onSurface,
                        fontSize: 30,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: AppDimensions.sm),

                    Text(
                      'Your team’s daily lunch expenses',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'Welcome back!',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: AppDimensions.sm),

                    Text(
                      'Login to manage your lunch expenses.',
                      style: AppTextStyles.body.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'Email / Mobile Number',
                      style: AppTextStyles.label.copyWith(color: colors.onSurface),
                    ),

                    const SizedBox(height: AppDimensions.sm),

                    TextFormField(
                      controller: _employeeController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Enter email or mobile number',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email or mobile number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    Text(
                      '4-Digit PIN',
                      style: AppTextStyles.label.copyWith(
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: AppDimensions.sm),

                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: _obscurePin,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Enter your 4-digit PIN',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),
                        counterText: '',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePin = !_obscurePin;
                            });
                          },
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your PIN';
                        }

                        if (value.length != 4) {
                          return 'PIN must contain exactly 4 digits';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed:
                        _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                          height: 23,
                          width: 23,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text('Login'),
                      ),
                    ),

                    // FINGERPRINT LOGIN (only after the user enabled it)
                    if (_biometricReady) ...[
                      const SizedBox(height: AppDimensions.md),
                      SizedBox(
                        height: AppDimensions.buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleBiometricLogin,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Login with fingerprint'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: colors.outline),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md,
                          ),
                          child: Text(
                            'NEW TO LUNCHMATE?',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: colors.outline),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: OutlinedButton.icon(
                        onPressed: _showTeamOptions,
                        icon: const Icon(Icons.groups_rounded),
                        label: const Text('Create or Join a Team'),
                      ),
                    ),

                    const SizedBox(height: 36),

                    Text(
                      'Simple lunch tracking for your team.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}