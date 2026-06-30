import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import 'privacy_policy_screen.dart';

/// Consentimento de gravação de voz (LGPD), antes do primeiro treino.
///
/// A landing (IntroScreen) já vendeu e explicou o método; aqui fica só o
/// aceite. O app não grava nada sem este consentimento explícito, e o
/// usuário não chega ao dashboard sem passar por aqui.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.store,
    required this.onDone,
    this.onBack,
  });

  final ProgressStore store;
  final VoidCallback onDone;

  /// Permite recuar para a landing sem aceitar — quem está em dúvida não
  /// fica preso só entre "aceitar" e nada mais.
  final VoidCallback? onBack;

  Future<void> _acceptAndStart() async {
    await store.grantVoiceConsent();
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: onBack == null
          ? null
          : AppBar(
              leading: BackButton(onPressed: onBack),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: theme.colorScheme.onSurface,
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mic, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Sua voz, suas regras',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    'Para avaliar sua pronúncia, o app grava sua voz durante '
                    'os exercícios e envia o áudio para análise automática '
                    '(Microsoft Azure).\n\n'
                    '• O áudio é usado apenas para avaliar a pronúncia\n'
                    '• Não é usado para treinar modelos de IA\n'
                    '• Também registramos dados técnicos agregados (navegador, '
                    'sistema operacional, idioma) para entender o uso do app\n'
                    '• Você pode apagar seus dados quando quiser',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _acceptAndStart,
                    child: const Text('Aceitar e fazer meu primeiro teste de fala'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sem o aceite não dá para praticar, porque todo o método '
                    'é baseado na sua voz.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()),
                    ),
                    child: const Text('Ler a política de privacidade'),
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
