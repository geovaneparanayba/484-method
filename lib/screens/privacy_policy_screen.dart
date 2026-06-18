import 'package:flutter/material.dart';

/// Política de privacidade (LGPD). Acessível no onboarding (antes do
/// consentimento) e pelo menu do app. Texto curto e direto — a gravação de
/// voz é dado pessoal sensível e o usuário precisa entender o tratamento.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Política de privacidade')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('484 Method — Privacidade',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Última atualização: junho de 2026',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                section(
                  'O que coletamos',
                  'Para avaliar sua pronúncia, o app grava sua voz durante os '
                      'exercícios. Guardamos também seu progresso (minutos de '
                      'prática aprovada, lições concluídas, streak) e eventos '
                      'de uso do app.',
                ),
                section(
                  'Como usamos sua voz',
                  'O áudio é enviado ao serviço de análise de pronúncia da '
                      'Microsoft Azure apenas para gerar sua nota e o feedback. '
                      'Os scores podem ser enviados à Anthropic (Claude) para '
                      'escrever o feedback em português. O áudio NÃO é usado '
                      'para treinar modelos de IA.',
                ),
                section(
                  'Onde os dados ficam',
                  'Seu progresso fica no aparelho e, quando há conexão, é '
                      'espelhado na nossa base (Supabase) ligada a um '
                      'identificador anônimo — sem nome, e-mail ou telefone.',
                ),
                section(
                  'Consentimento',
                  'A gravação só acontece após o seu aceite explícito no '
                      'início do app. Sem o aceite, não é possível praticar, '
                      'porque o método é baseado na sua voz.',
                ),
                section(
                  'Exclusão dos seus dados',
                  'A qualquer momento, em "Apagar meus dados" no menu, você '
                      'remove progresso, streak, lições e consentimento — tanto '
                      'do aparelho quanto da nossa base. A ação é definitiva.',
                ),
                section(
                  'Contato',
                  'Dúvidas sobre seus dados: g.paranayba@gmail.com.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
