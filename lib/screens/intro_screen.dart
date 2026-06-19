import 'package:flutter/material.dart';

/// Porta de entrada da demo (moldura pra quem abre o link cold — investidor,
/// beta tester). Enquadra o problema + a promessa + o diferencial e leva
/// direto pro "momento mágico" (falar e receber feedback). Some depois do
/// consentimento — usuário recorrente cai direto no app.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onStart});

  /// "Experimentar agora" → segue para o onboarding (como funciona + consentimento).
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('484 Method',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(
                    'Você entende inglês,\nmas trava na hora de falar?',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Aqui você fala desde o primeiro minuto: ouve, repete e '
                    'recebe feedback de pronúncia em português — no seu '
                    'próprio áudio.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Não é Duolingo nem ChatGPT. É treino de fala pra quem '
                        'congela na hora de abrir a boca.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onStart,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Experimentar agora'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Demo · funciona no navegador, com o seu microfone.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
