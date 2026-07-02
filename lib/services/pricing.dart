/// Teste de willingness-to-pay da oferta "Beta Fundador".
///
/// O preço é uma HIPÓTESE até haver conversão: o objetivo é achar a curva de
/// demanda (qual preço as pessoas realmente escolhem), não faturar ainda.
/// Cada usuário recebe uma variante ESTÁVEL (ver ProgressStore.assignedPriceVariant)
/// e todo o funil é logado com o `bucket`, pra medir conversão por preço.
///
/// Hoje o fluxo é fake door (captura de e-mail). O pagamento real via Pix
/// entra depois, em PaywallScreen — o preço, o evento e a tela não mudam.
/// Mexer nas variantes aqui altera o experimento sem tocar em nenhuma UI.
class PriceVariant {
  const PriceVariant({
    required this.bucket,
    required this.amountCents,
    required this.priceLabel,
    required this.cadenceLabel,
  });

  /// Id estável usado nos eventos de analytics — segmenta o funil por preço.
  final String bucket;

  /// Valor em centavos de real (ex.: 4700 = R$ 47,00) — o que o Pix vai cobrar.
  final int amountCents;

  /// Preço já formatado pra exibir (ex.: 'R\$ 47').
  final String priceLabel;

  /// Uma linha do que o preço compra (ex.: 'acesso vitalício de Fundador').
  final String cadenceLabel;
}

/// As variantes em teste. Três pontos de preço pra desenhar a curva de
/// demanda; a atribuição por usuário é estável (senão a conversão por preço
/// vira ruído).
const kPriceVariants = <PriceVariant>[
  PriceVariant(
    bucket: 'founder_2790',
    amountCents: 2790,
    priceLabel: 'R\$ 27,90',
    cadenceLabel: 'acesso vitalício de Fundador',
  ),
  PriceVariant(
    bucket: 'founder_4700',
    amountCents: 4700,
    priceLabel: 'R\$ 47',
    cadenceLabel: 'acesso vitalício de Fundador',
  ),
  PriceVariant(
    bucket: 'founder_6790',
    amountCents: 6790,
    priceLabel: 'R\$ 67,90',
    cadenceLabel: 'acesso vitalício de Fundador',
  ),
];
