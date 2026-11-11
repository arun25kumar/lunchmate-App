import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/usecases/join_team.dart';

import 'team_joined_screen.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  final _teamCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();

  late final JoinTeam _joinTeamUseCase;

  bool _obscurePin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _joinTeamUseCase = JoinTeam(
      FirebaseFirestore.instance,
    );
  }

  @override
  void dispose() {
    _teamCodeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _joinTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _joinTeamUseCase(
        teamCode: _teamCodeController.text.trim(),
        employeeName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        pin: _pinController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TeamJoinedScreen(
            teamName: result['teamName'] as String,
            teamCode: result['teamCode'] as String,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: validator ??
              (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }
            return null;
          },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headingSmall.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Team'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusLarge,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: colors.primary,
                        size: 36,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'Join your office lunch team',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'Enter the invitation code shared by your team admin and your details to join.',
                        style: AppTextStyles.body.copyWith(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.xxl),

                // TEAM DETAILS
                _sectionTitle('Team Details'),

                const SizedBox(height: 14),

                _buildField(
                  controller: _teamCodeController,
                  label: '6-Digit Team Invitation Code',
                  icon: Icons.vpn_key_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (value) {
                    if (value == null || value.length != 6) {
                      return 'Enter a valid 6-digit team code';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.xxl),

                // YOUR DETAILS
                _sectionTitle('Your Details'),

                const SizedBox(height: 14),

                _buildField(
                  controller: _nameController,
                  label: 'Your Name',
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 14),

                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                _buildField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.xxl),

                // SECURITY DETAILS
                _sectionTitle('Security Details'),

                const SizedBox(height: 14),

                _buildField(
                  controller: _pinController,
                  label: 'Create 4-Digit PIN',
                  icon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePin = !_obscurePin);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'PIN is required';
                    }
                    if (value.length != 4) {
                      return 'PIN must contain exactly 4 digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // JOIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinTeam,
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Join Team'),
                  ),
                ),

                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}