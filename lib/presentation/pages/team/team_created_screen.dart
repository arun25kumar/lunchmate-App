
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TeamCreatedScreen extends StatelessWidget {
  final String teamName;
  final String teamCode;

  const TeamCreatedScreen({
    super.key,
    required this.teamName,
    required this.teamCode,
  });

  void _copyCode(BuildContext context) {
    Clipboard.setData(
      ClipboardData(text: teamCode),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Team code copied successfully!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Team Created'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 85,
                color: colors.primary,
              ),

              const SizedBox(height: 24),

              Text(
                'Team Created Successfully!',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '$teamName is ready. Invite your colleagues '
                    'using the team code below.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'TEAM INVITATION CODE',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 16),

                    SelectableText(
                      teamCode,
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),

                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: () => _copyCode(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Code'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
