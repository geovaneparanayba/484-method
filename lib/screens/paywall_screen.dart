import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/pricing.dart';
import '../services/progress_store.dart';

/// Oferta "Beta Fundador" instrumentada — na prática, um teste de
/// willingness-to-pay. Cada usuário vê uma variante de preço ESTÁVEL
/// ([PriceVariant], atribuída pelo ProgressStore) e todo o funil
/// (`paywall_viewed` → `paywall_subscribe_clicked` → `paywall_email_captured`)
/// é logado com o `price_bucket`, pra medir conversão POR PREÇO e desenhar a
/// curva de demanda.
///
/// Hoje é fake door: o CTA leva à captura de e-mail (lista de Fundadores),
/// não a um pagamento — de propósito, pra provar intenção real antes de
/// construir cobrança. O Pix entra depois em [_startCheckout]; o preço, o
/// evento e a tela não mudam quando ele chegar.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.store, this.analytics});

  final ProgressStore store;
  final AnalyticsService? analytics;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Step { offer, email, done }

class _PaywallScreenState extends State<PaywallScreen> {
  // Estável durante toda a sessão do paywall (não re-sorteia a cada rebuild).
  late final PriceVariant _variant = widget.store.assignedPriceVariant();
  _Step _step = _Step.offer;
  final _emailController = TextEditingController();
  bool _emailValid = false;

  // Segmenta todo evento do funil pelo preço testado.
  Map<String, Object?> get _priceProps => {
        'price_bucket': _variant.bucket,
        'amount_cents': _variant.amountCents,
      };

  @override
  void initState() {
    super.initState();
    widget.analytics?.log('paywall_viewed', _priceProps);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Ponto de entrada do "pagar": HOJE abre a captura de e-mail (fake door).
  /// AMANHÃ (Pix), trocar por algo como:
  ///   launchUrl(pixCheckoutUri(_variant.amountCents))
  /// e tratar o retorno — o evento `paywall_subscribe_clicked` e o preço já
  /// estão prontos, então a métrica de conversão não muda de forma.
  void _startCheckout() {
    widget.analytics?.log('paywall_subscribe_clicked', _priceProps);
    setState(() => _step = _Step.email);
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    // Sinal forte do teste: intenção com nome atrás (não só um clique). O
    // e-mail vai no evento (tabela `events`, RLS por user_id) pra o dev
    // conseguir chamar os interessados — consentido: a pessoa digitou pra
    // entrar na lista.
    widget.analytics?.log('paywall_email_captured', {
      ..._priceProps,
      'email': email,
    });
    await widget.store.setLeftFounderEmail();
    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  void _dismiss() {
    if (_step == _Step.offer) {
      widget.analytics?.log('paywall_dismissed', _priceProps);
    }
    Navigator.of(context).pop();
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
            child: switch (_step) {
              _Step.offer => _offer(theme),
              _Step.email => _email(theme),
              _Step.done => _done(theme),
            },
          ),
        ),
      ),
    );
  }

  Widget _offer(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.workspace_premium,
            size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Seja um Fundador do 484',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Você já provou que consegue falar. Os primeiros que apoiarem o '
          'projeto garantem acesso vitalício e ajudam a decidir o que vem '
          'depois da Trilha 1.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _benefit(theme, Icons.lock_open,
            'Acesso vitalício de Fundador — sem mensalidade'),
        _benefit(theme, Icons.record_voice_over,
            'Feedback de pronúncia em português, em cada tentativa'),
        _benefit(theme, Icons.rocket_launch,
            'Acesso antecipado às próximas trilhas, à medida que saem'),
        _benefit(theme, Icons.favorite,
            'Você molda o produto: fala direto com quem constrói'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text(
              _variant.priceLabel,
              style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(_variant.cadenceLabel, style: theme.textTheme.bodySmall),
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
          onPressed: _startCheckout,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Quero ser Fundador'),
          ),
        ),
        TextButton(
          onPressed: _dismiss,
          child: const Text('Agora não'),
        ),
      ],
    );
  }

  Widget _email(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined,
            size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Garanta seu preço de Fundador',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        // Honesto sobre o fake door: ainda não há cobrança. A pessoa entra
        // numa lista e trava o preço que viu.
        Text(
          'O pagamento ainda não abriu. Deixe seu e-mail: você entra na lista '
          'de Fundadores e trava o preço de ${_variant.priceLabel} quando '
          'abrirmos — a gente te chama primeiro.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Seu melhor e-mail',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            final valid = _emailRegex.hasMatch(v.trim());
            if (valid != _emailValid) setState(() => _emailValid = valid);
          },
          onSubmitted: (_) {
            if (_emailValid) _submitEmail();
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _emailValid ? _submitEmail : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Garantir minha vaga'),
          ),
        ),
        TextButton(
          onPressed: _dismiss,
          child: const Text('Agora não'),
        ),
        const SizedBox(height: 8),
        Text(
          'Só pra te avisar da abertura. Sem spam; você pode sair quando '
          'quiser.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _done(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle,
            size: 64, color: theme.colorScheme.secondary),
        const SizedBox(height: 16),
        Text('Você está na lista de Fundadores',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Assim que o pagamento abrir, a gente te chama com o preço de '
          'Fundador garantido. Enquanto isso, continue treinando — sua '
          'prática não para.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Voltar a treinar'),
          ),
        ),
      ],
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
