import 'package:flutter/material.dart';

class TeamJoinedScreen extends StatelessWidget {
  final String teamName;
  final String teamCode;

  const TeamJoinedScreen({
    super.key,
    required this.teamName,
    required this.teamCode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Team Joined'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SUCCESS ICON
              Icon(
                Icons.check_circle_rounded,
                size: 85,
                color: colors.primary,
              ),

              const SizedBox(height: 24),

              // SUCCESS TITLE
              Text(
                'Team Joined Successfully!',
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
                'Welcome to $teamName! You have successfully joined your office lunch team.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // TEAM INFORMATION
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
                      'YOUR TEAM',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      teamName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Divider(
                      color: colors.onPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'TEAM INVITATION CODE',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    SelectableText(
                      teamCode,
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // CONTINUE
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil(
                          (route) => route.isFirst,
                    );
                  },
                  child: const Text('Continue to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}