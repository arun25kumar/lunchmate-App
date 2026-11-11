
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

import '../../../data/datasources/remote/email_datasource.dart';
import '../../../data/datasources/remote/firestore_team_datasource.dart';
import '../../../data/repositories/team_repository_impl.dart';

import '../../../domain/entities/team.dart';
import '../../../domain/usecases/create_team.dart';

import 'team_created_screen.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _teamNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _upiController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  // UI states
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  late final FirestoreTeamDataSource _dataSource;
  late final CreateTeam _createTeamUseCase;

  // UPI validation
  static final RegExp _upiRegex =
  RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();

    // Initialize datasource.
    _dataSource = FirestoreTeamDataSource();

    // Initialize repository.
    final repository = TeamRepositoryImpl(
      dataSource: _dataSource,
    );

    // Initialize use case.
    _createTeamUseCase = CreateTeam(repository);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _upiController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();

    super.dispose();
  }

  // ---------------------------------
  // SAVE UPI ID
  // ---------------------------------

  Future<void> _saveUpiId({
    required String teamId,
    required String upiId,
  }) async {
    await _dataSource.saveUpiId(
      teamId: teamId,
      upiId: upiId,
    );
  }

  // ---------------------------------
  // CREATE TEAM
  // ---------------------------------

  Future<void> _createTeam() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. CREATE TEAM IN FIRESTORE
      final Team team = await _createTeamUseCase(
        teamName: _teamNameController.text.trim(),
        adminName: _adminNameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        pin: _pinController.text.trim(),
      );

      // 2. SAVE UPI ID
      try {
        await _saveUpiId(
          teamId: team.teamId,
          upiId: _upiController.text.trim(),
        );
      } catch (e) {
        debugPrint('UPI saving failed: $e');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Team created, but UPI ID could not be saved.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 3. SEND TEAM INVITATION EMAIL
      try {
        await EmailDataSource().sendTeamInvite(
          toEmail: team.email,
          adminName: team.adminName,
          teamName: team.teamName,
          teamCode: team.teamCode,
        );
      } catch (e) {
        debugPrint('Invite email failed: $e');
      }

      if (!mounted) return;

      // 4. NAVIGATE TO SUCCESS SCREEN
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TeamCreatedScreen(
            teamName: team.teamName,
            teamCode: team.teamCode,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------
  // COMMON TEXT FIELD
  // ---------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        helperText: helperText,
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

  // ---------------------------------
  // SECTION TITLE
  // ---------------------------------

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headingSmall.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // ---------------------------------
  // BUILD UI
  // ---------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Team'),
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
                        'Start your office lunch team',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'Create a team and invite your colleagues '
                            'using a team invitation code.',
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

                _buildTextField(
                  controller: _teamNameController,
                  label: 'Team Name',
                  icon: Icons.groups_outlined,
                ),

                const SizedBox(height: AppDimensions.xxl),

                // ADMIN DETAILS
                _sectionTitle('Admin Details'),

                const SizedBox(height: 14),

                // ADMIN NAME
                _buildTextField(
                  controller: _adminNameController,
                  label: 'Admin Name',
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 14),

                // EMAIL
                _buildTextField(
                  controller: _emailController,
                  label: 'Email ID',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final v = value?.trim() ?? '';

                    if (v.isEmpty) {
                      return 'Email ID is required';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v)) {
                      return 'Enter a valid email address';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // MOBILE NUMBER
                _buildTextField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mobile Number is required';
                    }

                    if (value.length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // UPI ID
                _buildTextField(
                  controller: _upiController,
                  label: 'UPI ID',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.emailAddress,
                  helperText: 'Members will pay you on this UPI ID',
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(
                      RegExp(r'\s'),
                    ),
                  ],
                  validator: (value) {
                    final v = value?.trim() ?? '';

                    if (v.isEmpty) {
                      return 'UPI ID is required';
                    }

                    if (!_upiRegex.hasMatch(v)) {
                      return 'Enter a valid UPI ID like name@bank';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.xxl),

                // SECURITY DETAILS
                _sectionTitle('Security Details'),

                const SizedBox(height: 14),

                // CREATE PIN
                _buildTextField(
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
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
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

                const SizedBox(height: 14),

                // CONFIRM PIN
                _buildTextField(
                  controller: _confirmPinController,
                  label: 'Confirm 4-Digit PIN',
                  icon: Icons.lock_reset_outlined,
                  keyboardType: TextInputType.number,
                  obscureText: _obscureConfirmPin,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPin
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPin = !_obscureConfirmPin;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm PIN is required';
                    }

                    if (value.length != 4) {
                      return 'PIN must contain exactly 4 digits';
                    }

                    if (value != _pinController.text) {
                      return 'PIN does not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // CREATE TEAM BUTTON
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTeam,
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Create Team'),
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
