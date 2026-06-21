import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';

/// Oferta "Beta Fundador" — aparece quando o usuário toca numa lição além
/// das gratuitas. A compra real entra via RevenueCat no mobile; por ora o
/// CTA chama [onSubscribe], que anuncia a disponibilidade (o menu de dev
/// libera o acesso para teste na web).
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.onSubscribe});

  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.workspace_premium,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Beta Fundador',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'As $kFreeLessonCount primeiras lições são suas, de graça. '
                  'O Beta Fundador abre a Fase 1 completa.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _benefit(theme, Icons.hearing,
                    '10 lições som-first — ouça, repita e destrave a fala'),
                _benefit(theme, Icons.record_voice_over,
                    'Feedback de pronúncia em português, na sua tentativa'),
                _benefit(theme, Icons.fitness_center,
                    'Modo desafio para chegar perto da pronúncia nativa'),
                _benefit(theme, Icons.trending_up,
                    'Progresso medido em minutos de fala aprovada'),
                const SizedBox(height: 24),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text(
                      'R\$ 47',
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'acesso vitalício à Fase 1',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Não é assinatura. É um voto de confiança em uma ideia '
                      'que ainda está nascendo — e que você ajuda a moldar.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onSubscribe,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Apoiar o Method 484'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Agora não'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }
}
