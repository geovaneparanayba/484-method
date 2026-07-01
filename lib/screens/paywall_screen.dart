import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../services/analytics_service.dart';
import '../services/entitlement_service.dart';

/// Oferta "Beta Fundador" — aparece quando o usuário toca numa lição além
/// das gratuitas. A compra real entra via RevenueCat no mobile; por ora o
/// CTA chama [onSubscribe], que anuncia a disponibilidade (o menu de dev
/// libera o acesso para teste na web).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.onSubscribe, this.analytics});

  final VoidCallback onSubscribe;
  final AnalyticsService? analytics;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    widget.analytics?.log('paywall_viewed');
  }

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
                Text('Desbloqueie a Trilha 1 completa',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Você já provou que consegue. '
                  'As próximas ${fase1Lessons.length - kFreeLessonCount} lições continuam de onde você parou.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _benefit(theme, Icons.hearing,
                    'Ouça, repita e desbloqueie palavras que você já conhece'),
                _benefit(theme, Icons.record_voice_over,
                    'Feedback de pronúncia em português, em cada tentativa'),
                _benefit(theme, Icons.fitness_center,
                    'Modo precisão para quem quer critério mais exigente'),
                _benefit(theme, Icons.trending_up,
                    'Progresso em minutos reais de fala aprovada'),
                const SizedBox(height: 24),
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
                      'acesso vitalício à Trilha 1',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pagamento único. Sem assinatura.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    widget.analytics?.log('paywall_subscribe_clicked');
                    widget.onSubscribe();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Quero continuar treinando'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.analytics?.log('paywall_dismissed');
                    Navigator.of(context).pop();
                  },
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
