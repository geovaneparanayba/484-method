import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import 'privacy_policy_screen.dart';

/// Onboarding de primeiro uso: promessa → como funciona (regra som-first)
/// → consentimento de gravação de voz (LGPD).
///
/// O app não grava nada antes do aceite explícito da última página, e o
/// usuário não chega ao dashboard sem passar por aqui.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store, required this.onDone});

  final ProgressStore store;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _acceptAndStart() async {
    await widget.store.grantVoiceConsent();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    _page1(theme),
                    _page2(theme),
                    _page3(theme),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pageScaffold(List<Widget> children) {
    // Rolável para não estourar em telas baixas (o botão de consentimento
    // precisa estar sempre alcançável).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _page1(ThemeData theme) {
    return _pageScaffold([
      Text('484 Method',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Text(
        'Você sabe mais inglês do que consegue falar.\n'
        'A gente te ajuda a destravar o som.',
        style: theme.textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Prática oral guiada, medida em minutos aprovados — '
        'não em telas assistidas.',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      FilledButton(onPressed: _next, child: const Text('Continuar')),
    ]);
  }

  Widget _page2(ThemeData theme) {
    return _pageScaffold([
      Text('Primeiro escute, depois fale.',
          style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Text(
        'Em cada lição você OUVE uma palavra (sem ler nada), repete '
        'do seu jeito, recebe feedback — e só então a escrita aparece. '
        'É assim que o som entra na frente da letra.',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      FilledButton(onPressed: _next, child: const Text('Continuar')),
    ]);
  }

  Widget _page3(ThemeData theme) {
    return _pageScaffold([
      Icon(Icons.mic, size: 48, color: theme.colorScheme.primary),
      const SizedBox(height: 16),
      Text('Sua voz, suas regras',
          style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Text(
        'Para avaliar sua pronúncia, o app grava sua voz durante os '
        'exercícios e envia o áudio para análise automática '
        '(Microsoft Azure).\n\n'
        '• O áudio é usado apenas para avaliar a pronúncia\n'
        '• Não é usado para treinar modelos de IA\n'
        '• Você pode apagar seus dados quando quiser',
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 32),
      FilledButton(
        onPressed: _acceptAndStart,
        child: const Text('Aceito a gravação de voz — começar'),
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
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PrivacyPolicyScreen(),
        )),
        child: const Text('Ler a política de privacidade'),
      ),
    ]);
  }
}
