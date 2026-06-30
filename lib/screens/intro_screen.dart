import 'package:flutter/material.dart';

/// Landing da demo — clean e focada na conversão. Só o essencial: a dor, a
/// promessa em uma frase, o ciclo do método (diferencial) e um CTA. Some
/// após o consentimento (usuário recorrente cai direto no app).
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onStart});

  /// CTA → segue para o consentimento e o primeiro treino.
  final VoidCallback onStart;

  static const _cycle = ['Ouvir', 'Repetir', 'Gravar', 'Corrigir', 'Regravar'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.secondary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PROTÓTIPO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '484 Method',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Você entende inglês,\nmas trava quando precisa falar?',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Plataforma de fala ativa em inglês para quem entende '
                    'mais do que consegue falar. Você escuta, repete, grava '
                    'a sua voz e recebe feedback em português — e grava de '
                    'novo até soar mais natural.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _cycleFlow(theme),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: onStart,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Fazer meu primeiro treino de fala'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gratuito para começar. Sem cadastro.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
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

  Widget _cycleFlow(ThemeData theme) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _cycle.length; i++) ...[
            Chip(
              label: Text(_cycle[i]),
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.primaryContainer,
              side: BorderSide.none,
            ),
            if (i < _cycle.length - 1)
              Icon(Icons.arrow_forward,
                  size: 16, color: theme.colorScheme.outline),
          ],
        ],
      );
}
