import 'dart:math';

import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../models/lesson.dart';
import '../services/analytics_service.dart';
import '../services/entitlement_service.dart';
import '../services/progress_store.dart';
import '../services/pronunciation_assessor.dart';
import '../services/backend.dart';
import 'cohort_recording_screen.dart';
import 'cohort_review_screen.dart';
import 'lesson_screen.dart';
import 'paywall_screen.dart';
import 'privacy_policy_screen.dart';
import 'stats_screen.dart';
import 'word_memory_screen.dart';

/// Dashboard: a barra das 484 horas, o streak e a porta de entrada das
/// lições. É a tela que o aluno vê todo dia — precisa mostrar progresso
/// real em segundos, não conclusão de telas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.entitlement,
    required this.assessor,
    this.analytics,
    this.onDataCleared,
    this.autostartFirstLesson = false,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final ProgressStore store;
  final EntitlementService entitlement;
  final PronunciationAssessor assessor;
  final AnalyticsService? analytics;

  /// Chamado após a exclusão de dados (o app volta ao onboarding).
  final VoidCallback? onDataCleared;

  /// Logo após o onboarding: abre a 1ª lição automaticamente (conserto do
  /// funil consentimento→1ª lição), em vez de deixar o novato na dashboard.
  final bool autostartFirstLesson;

  /// Tema atual e callback pra trocar (Sistema/Claro/Escuro). Controlados e
  /// persistidos pelo App; aqui só exibimos o seletor no menu.
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Survey de abandono respondido nesta sessão (esconde o card na hora).
  bool _abandonAnswered = false;

  // #8: por padrão só mostra concluídos + treino atual + poucos bloqueados —
  // muitos cadeados em sequência davam sensação de caminho longo e cansativo.
  bool _showAllLessons = false;

  // Desafio do dia, resolvido fora do build (o sorteio tem efeito colateral de
  // persistir no ProgressStore). Null = nenhuma lição elegível (não deve
  // acontecer: a lição 1 está sempre liberada) ou ainda não resolvido.
  Lesson? _challenge;

  // #5/#13 Missões: rótulos pras primeiras lições não-bônus (camada leve por
  // cima do currículo). Sem número fixo no texto — o índice da missão não é
  // o mesmo da lição (bônus não contam), então numerar as duas confundia
  // (ex.: "Missão 7" dentro do card da lição 8). A UI sempre prefixa com
  // "Missão atual" em vez de expor esse índice.
  static const _missions = [
    'Fale sem ler pela primeira vez',
    'Melhore sua segunda tentativa',
    'Corrija seu primeiro som difícil',
    'Ganhe seus primeiros 5 minutos aprovados',
    'Responda mais rápido',
    'Use uma frase real de viagem',
    'Complete seu primeiro bloco de fala ativa',
  ];

  String? _missionFor(String lessonId) {
    var idx = 0;
    for (final l in fase1Lessons) {
      if (l.bonus) continue;
      if (l.id == lessonId) {
        return idx < _missions.length ? _missions[idx] : null;
      }
      idx++;
    }
    return null;
  }

  // #10 Survey de abandono: opções de motivo (valor p/ evento, rótulo p/ UI).
  static const _abandonOptions = [
    ('nao_entendi', 'Não entendi o que fazer'),
    ('vergonha', 'Tive vergonha de gravar'),
    ('microfone', 'O microfone não funcionou'),
    ('dificil', 'Achei difícil'),
    ('facil_demais', 'Achei fácil demais'),
    ('sem_valor', 'Não vi valor'),
    ('sem_tempo', 'Estou sem tempo'),
  ];

  @override
  void initState() {
    super.initState();
    _ensureDailyChallenge();
    // Conserto do funil: quem acabou de consentir entra direto na 1ª lição,
    // em vez de cair na dashboard vazia ("0 de 484h" assusta e não tem CTA).
    // Só no 1º acesso (progresso zero); initState roda 1x, sem repetir.
    if (widget.autostartFirstLesson &&
        widget.store.totalApproved == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLesson(fase1Lessons.first);
      });
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todos os seus dados?'),
        content: const Text(
            'Progresso, streak, lições concluídas, o consentimento de '
            'gravação e as gravações do desafio serão apagados deste '
            'dispositivo e da nuvem. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.clearAll();
    widget.onDataCleared?.call();
  }

  /// Abre a oferta Beta Fundador (teste de willingness-to-pay). O paywall
  /// cuida do preço testado, do funil e da captura de e-mail (fake door); o
  /// pagamento real via Pix entra dentro dele depois. Ao voltar, atualiza a
  /// home (o CTA de Fundador some se a pessoa deixou o e-mail).
  Future<void> _openPaywall() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaywallScreen(
        store: widget.store,
        analytics: widget.analytics,
      ),
    ));
    if (mounted) setState(() {});
  }

  /// CTA da oferta Beta Fundador na dashboard. Aparece no "momento uau" (a
  /// pessoa já viu seu antes/depois → sabe que funciona) e some quando ela
  /// entra na lista de Fundadores. Não bloqueia nada: mede intenção sem
  /// tirar as lições grátis de quem só quer praticar.
  Widget _founderOfferCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: _openPaywall,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.workspace_premium,
                  size: 36, color: theme.colorScheme.tertiary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seja um Fundador do 484',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Garanta acesso vitalício e ajude a decidir o que vem '
                      'depois da Trilha 1.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PrivacyPolicyScreen(),
    ));
  }

  /// Seletor de tema: Sistema (segue o aparelho), Claro ou Escuro.
  void _openThemeChooser() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, label) in const [
              (ThemeMode.system, 'Sistema'),
              (ThemeMode.light, 'Claro'),
              (ThemeMode.dark, 'Escuro'),
            ])
              ListTile(
                title: Text(label),
                trailing:
                    widget.themeMode == mode ? const Icon(Icons.check) : null,
                onTap: () {
                  widget.onThemeModeChanged?.call(mode);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openWordMemory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WordMemoryScreen(onReviewWord: _reviewWord),
    ));
  }

  /// "Revisar agora": abre o treino da 1ª lição que contém a palavra, já no
  /// item dela (via startItemIndex) — em vez de retomar o índice salvo.
  void _reviewWord(String word) {
    for (final lesson in fase1Lessons) {
      final idx = lesson.items.indexWhere((it) => it.text == word);
      if (idx >= 0) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LessonScreen(
            lesson: lesson,
            assessor: widget.assessor,
            store: widget.store,
            analytics: widget.analytics,
            rigorous: widget.store.rigorousMode,
            startItemIndex: idx,
          ),
        )).then((_) {
          if (mounted) setState(() {});
        });
        return;
      }
    }
  }

  Future<void> _openStats() async {
    final backend = Backend.instance;
    if (backend == null) return;
    await StatsScreen.openWithPasswordGate(context, backend);
  }

  /// Alterna o acesso na implementação fake (web/dev) para testar os dois
  /// estados do gating sem loja. Some quando a impl real (RevenueCat) entrar.
  Future<void> _toggleFounderAccess() async {
    await widget.entitlement
        .setFounderAccess(!widget.entitlement.hasFounderAccess);
    // Acesso mudou: o desafio salvo pode ter virado paywall (ou liberado).
    _ensureDailyChallenge();
    if (mounted) setState(() {});
  }

  /// Explica o efeito antes de ligar: o critério mais rígido vale para
  /// qualquer tentativa a partir de agora (lições já concluídas continuam
  /// concluídas, mas refazê-las ou seguir adiante usa o novo critério) —
  /// sem isso, a mesma pronúncia passar antes e reprovar depois confunde.
  Future<bool> _confirmEnableRigorous() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar modo desafio?'),
        content: const Text(
            'A partir de agora, toda gravação — inclusive em lições que '
            'você já concluiu, se refizer — só é aprovada com pronúncia '
            'bem próxima da nativa. O que já está concluído continua '
            'concluído; só o critério das próximas tentativas muda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  bool _isPaywalled(int i) =>
      i >= kFreeLessonCount && !widget.entitlement.hasFounderAccess;

  /// O pré-requisito é a lição anterior NÃO bônus — lições bônus nunca
  /// bloqueiam (nem precisam de) progressão.
  bool _isProgressionUnlocked(int i) {
    int prereq = i - 1;
    while (prereq >= 0 && fase1Lessons[prereq].bonus) {
      prereq--;
    }
    return prereq < 0 ||
        widget.store.isLessonCompleted(fase1Lessons[prereq].id);
  }

  /// Resolve o desafio de hoje em [_challenge]. Tem efeito colateral (persiste
  /// o sorteio), então roda FORA do build — no initState e depois de eventos
  /// que mudam a elegibilidade (concluir lição, alternar acesso). Reaproveita
  /// o sorteio salvo do dia se ele ainda for elegível; re-sorteia se o acesso
  /// foi perdido (virou paywall) ou o id não existe mais (currículo mudou).
  void _ensureDailyChallenge() {
    final savedId = widget.store.dailyChallengeLessonId;
    if (savedId != null) {
      final idx = fase1Lessons.indexWhere((l) => l.id == savedId);
      if (idx >= 0 && !_isPaywalled(idx) && _isProgressionUnlocked(idx)) {
        _challenge = fase1Lessons[idx];
        return;
      }
    }
    _challenge = _pickDailyChallenge();
  }

  /// Sorteia uma lição do dia entre as liberadas e ainda não concluídas — dá
  /// visibilidade às bônus (que a "próxima melhor ação" nunca aponta) e vira
  /// revisão quando a trilha liberada está toda feita. Persiste o sorteio
  /// (não troca a cada rebuild; expira sozinho ao virar o dia).
  Lesson? _pickDailyChallenge() {
    final unlocked = [
      for (final (i, l) in fase1Lessons.indexed)
        if (!_isPaywalled(i) && _isProgressionUnlocked(i)) l,
    ];
    if (unlocked.isEmpty) return null;
    final incomplete = [
      for (final l in unlocked)
        if (!widget.store.isLessonCompleted(l.id)) l,
    ];
    final pool = incomplete.isNotEmpty ? incomplete : unlocked;
    final picked = pool[Random().nextInt(pool.length)];
    widget.store.setDailyChallenge(picked.id);
    return picked;
  }

  Widget _dailyChallengeCard(ThemeData theme, Lesson lesson) {
    final done = widget.store.dailyChallengeCompleted;
    final isReview = widget.store.isLessonCompleted(lesson.id) && !done;
    return Card(
      child: ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.local_fire_department,
          color: theme.colorScheme.secondary,
        ),
        title: const Text('Desafio de hoje'),
        subtitle: Text(done
            ? '${lesson.title} — feito! Amanhã tem outro.'
            : isReview
                ? '${lesson.title} · revisão'
                : lesson.title),
        trailing: done ? null : const Icon(Icons.chevron_right),
        onTap: done ? null : () => _openLesson(lesson),
      ),
    );
  }

  /// Desafio de 21 dias (instrumento de validação do beta): mede outcome, não
  /// só comportamento — confiança inicial vs. final + o antes/depois. O card
  /// muda conforme o estágio: entrar → em andamento → fechar → concluído.
  Widget _cohortCard(ThemeData theme) {
    final store = widget.store;

    if (!store.cohortStarted) {
      return _cohortCta(
        theme,
        color: theme.colorScheme.primaryContainer,
        accent: theme.colorScheme.primary,
        icon: Icons.flag,
        title: 'Desafio de 21 dias',
        subtitle:
            'Treine o ouvido e a boca todo dia. No fim, veja seu antes e depois.',
        onTap: _startCohort,
      );
    }

    if (store.cohortFinalDone) {
      return Card(
        child: ListTile(
          leading:
              Icon(Icons.emoji_events, color: theme.colorScheme.secondary),
          title: const Text('Desafio de 21 dias concluído'),
          subtitle: const Text('Ver seu antes e depois'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openReview,
        ),
      );
    }

    if (store.cohortFinalUnlocked) {
      return _cohortCta(
        theme,
        color: theme.colorScheme.secondaryContainer,
        accent: theme.colorScheme.secondary,
        icon: Icons.emoji_events,
        title: 'Você chegou ao dia ${store.cohortDay}!',
        subtitle: 'Feche o desafio e veja seu antes e depois.',
        onTap: _finishCohort,
      );
    }

    final day = store.cohortDay.clamp(1, ProgressStore.cohortLength);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Desafio de 21 dias · Dia $day de ${ProgressStore.cohortLength}',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: day / ProgressStore.cohortLength,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.primary,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text('Pratique um pouco hoje pra manter o ritmo.',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _cohortCta(
    ThemeData theme, {
    required Color color,
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  /// Guardar gravações é uma base LGPD diferente de processá-las na hora (loop
  /// de lição), então pede consentimento próprio. Só faz sentido com backend
  /// (o áudio vai pro Storage); em local-only o desafio roda só com confiança.
  Future<bool> _confirmVoiceStorageConsent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar suas gravações do desafio?'),
        content: const Text(
            'Pra você comparar seu antes e depois, o 484 vai GUARDAR duas '
            'gravações suas (hoje e no fim dos 21 dias) — não só analisar na '
            'hora, como nas lições. Ficam num espaço privado; você pode apagar '
            'tudo quando quiser em "Apagar meus dados". Sem isso, o desafio '
            'segue só com a sua autoavaliação.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não, obrigado'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pode guardar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _recordCohortSpeech(String kind) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CohortRecordingScreen(
        kind: kind,
        store: widget.store,
        backend: Backend.instance,
        analytics: widget.analytics,
      ),
    ));
  }

  Future<void> _startCohort() async {
    // O áudio só pode ser guardado com backend; sem ele, desafio de confiança.
    final canRecord = Backend.instance != null;
    if (canRecord && !widget.store.hasVoiceStorageConsent) {
      if (await _confirmVoiceStorageConsent()) {
        await widget.store.grantVoiceStorageConsent();
      }
    }
    if (!mounted) return;
    final score = await showConfidenceSurvey(
      context,
      title: 'Desafio de 21 dias',
      question: 'Antes de começar: como você se sente falando inglês hoje?',
    );
    if (score == null) return;
    await widget.store.startCohort(score);
    widget.analytics?.log('cohort_started', {
      'baseline_confidence': score,
      'audio_consent': widget.store.hasVoiceStorageConsent,
    });
    if (!mounted) return;
    // Gravação de baseline (best-effort): registra a fala de hoje pro depois.
    if (canRecord && widget.store.hasVoiceStorageConsent) {
      await _recordCohortSpeech('baseline');
    }
    if (mounted) setState(() {});
  }

  Future<void> _finishCohort() async {
    final score = await showConfidenceSurvey(
      context,
      title: 'Você chegou ao fim do desafio!',
      question: 'Agora, como você se sente falando inglês?',
    );
    if (score == null) return;
    await widget.store.setFinalConfidence(score);
    widget.analytics?.log('final_confidence', {'final_confidence': score});
    if (!mounted) return;
    // Gravação final (best-effort) antes do antes/depois, se houve consentimento.
    if (Backend.instance != null && widget.store.hasVoiceStorageConsent) {
      await _recordCohortSpeech('final');
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CohortReviewScreen(
        store: widget.store,
        analytics: widget.analytics,
      ),
    ));
    if (mounted) setState(() {});
  }

  void _openReview() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CohortReviewScreen(
        store: widget.store,
        analytics: widget.analytics,
      ),
    )).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// A "próxima melhor ação": a 1ª lição não-bônus ainda não concluída (o
  /// caminho principal é linear). Null = concluiu tudo.
  Lesson? _nextLesson() {
    for (final l in fase1Lessons) {
      if (l.bonus) continue;
      if (!widget.store.isLessonCompleted(l.id)) return l;
    }
    return null;
  }

  /// Card de uma única ação clara no topo do dashboard (#8): evita o paradoxo
  /// de escolha — diz o próximo passo e leva direto a ele.
  Widget _nextBestActionCard(ThemeData theme, Lesson next, bool isFirst) {
    // #9: a ação precisa nomear o treino, a micro-habilidade e a recompensa
    // concreta mais próxima — meta de hoje ou primeiro marco, o que fizer
    // mais sentido pra quem ainda não chegou lá.
    final String text;
    if (isFirst) {
      text = 'Seu próximo passo: fazer sua primeira tentativa de fala '
          '(~5 min) e destravar sua meta de hoje.';
    } else if (!widget.store.reachedFirstMilestone) {
      final remaining = ProgressStore.firstMilestoneSeconds -
          widget.store.totalApproved.inSeconds;
      final remainingMin = (remaining / 60).ceil().clamp(1, 999);
      text = 'Seu próximo passo: treinar "${next.title}" — foco: '
          '${next.microSkill} (${next.items.length} tentativas de fala) e '
          'chegar mais perto do seu primeiro marco — faltam '
          '~${remainingMin}min aprovados.';
    } else {
      text = 'Seu próximo passo: treinar "${next.title}" — foco: '
          '${next.microSkill} (${next.items.length} tentativas de fala) e '
          'ganhar mais minutos aprovados na sua jornada.';
    }
    final mission = _missionFor(next.id);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => _openLesson(next),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próxima melhor ação',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    if (mission != null) ...[
                      Text('Missão atual: $mission',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(text, style: theme.textTheme.bodyMedium),
                    ] else
                      Text(text, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.play_circle_fill,
                  size: 40, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  /// #7: meta curta do dia — o 1º degrau da hierarquia de progresso, antes
  /// do primeiro marco e da jornada de 484h.
  Widget _todayGoalCard(ThemeData theme) {
    final today = widget.store.approvedToday;
    final goal = ProgressStore.dailyGoalSeconds;
    final reached = today.inSeconds >= goal;
    final remaining = (goal - today.inSeconds).clamp(0, goal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meta de hoje: ${_format(Duration(seconds: goal))} aprovados',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (today.inSeconds / goal).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text(
              reached
                  ? 'Você bateu sua meta de hoje. 🎉'
                  : 'Você fez ${_format(today)}. '
                      'Faltam ${_format(Duration(seconds: remaining))}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// #7: primeiro marco (10min aprovados) — a ponte entre a meta de hoje e a
  /// jornada de 484h. Some quando alcançado.
  Widget _firstMilestoneCard(ThemeData theme) {
    final total = widget.store.totalApproved;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Primeiro marco: '
                '${_format(Duration(seconds: ProgressStore.firstMilestoneSeconds))} '
                'aprovados',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.store.firstMilestoneFraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.secondary,
              backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text('${_format(total)} de ${_format(Duration(seconds: ProgressStore.firstMilestoneSeconds))}',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  /// #10: "Modo precisão" (ex-"Modo desafio") — copy menos intimidante, sem
  /// prometer "pronúncia nativa"; avisa quem ainda está construindo base.
  Widget _precisionModeCard(ThemeData theme) {
    final hasEnoughBase =
        widget.store.totalApproved.inSeconds >= 30 * 60;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: widget.store.rigorousMode,
            onChanged: (v) async {
              if (v && !await _confirmEnableRigorous()) return;
              await widget.store.setRigorousMode(v);
              setState(() {});
            },
            title: const Text('Modo precisão'),
            subtitle: const Text(
                'Use quando quiser treinar com critério mais exigente de '
                'clareza, ritmo e pronúncia. Recomendado depois dos '
                'primeiros 30 minutos aprovados.'),
            secondary: const Icon(Icons.fitness_center),
          ),
          if (!hasEnoughBase)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Você ainda está construindo base. O modo precisão pode '
                'ficar difícil demais no começo.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  /// #8: reduz o efeito visual de muitos bloqueios — mostra concluídos, o
  /// treino atual e só os próximos poucos bloqueados; o resto fica atrás de
  /// um botão "Ver próximos treinos da trilha".
  List<Widget> _lessonList(ThemeData theme) {
    const lockedVisibleLimit = 3;
    final next = _nextLesson();
    final nextIndex = next == null ? -1 : fase1Lessons.indexOf(next);
    final widgets = <Widget>[];
    var lockedShown = 0;
    var hiddenCount = 0;

    for (final (i, lesson) in fase1Lessons.indexed) {
      final completed = widget.store.isLessonCompleted(lesson.id);
      final paywalled = _isPaywalled(i);
      final progressionUnlocked = _isProgressionUnlocked(i);
      final unlocked = !paywalled && progressionUnlocked;
      final isCurrent = i == nextIndex;

      bool visible;
      if (_showAllLessons || completed || isCurrent || unlocked) {
        visible = true;
      } else if (lockedShown < lockedVisibleLimit) {
        visible = true;
        lockedShown++;
      } else {
        visible = false;
      }

      if (!visible) {
        hiddenCount++;
        continue;
      }

      if (i == 0 || i == 6 || i == 11 || i == 18) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
          child: Text(
            switch (i) {
              0 => 'Zona 1 — Reconhecimento e confiança',
              6 => 'Zona 2 — Som e sílaba forte',
              11 => 'Zona 3 — Da palavra à frase',
              _ => 'Zona 4 — Conversa do dia a dia',
            },
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      }

      final mission = _missionFor(lesson.id);
      final String subtitle;
      if (paywalled) {
        subtitle = 'Beta Fundador';
      } else if (!progressionUnlocked) {
        subtitle = 'Complete a missão anterior para liberar';
      } else if (lesson.bonus) {
        subtitle =
            'Bônus opcional · ${lesson.items.length} tentativas de fala · ~5 min';
      } else {
        subtitle = '${lesson.items.length} tentativas de fala · ~5 min';
      }
      final IconData trailing;
      if (paywalled) {
        trailing = Icons.workspace_premium_outlined;
      } else if (!progressionUnlocked) {
        trailing = Icons.lock_outline;
      } else {
        trailing = completed ? Icons.replay : Icons.play_arrow;
      }
      widgets.add(Card(
        child: ListTile(
          // Paywalled fica tocável para mostrar o aviso do gate.
          enabled: unlocked || paywalled,
          leading: CircleAvatar(
            backgroundColor: completed
                ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: completed
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface,
            child: completed
                ? const Icon(Icons.check, size: 20)
                : Text('${i + 1}'),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(lesson.title)),
              if (lesson.bonus) ...[
                const SizedBox(width: 6),
                Icon(Icons.star, size: 16, color: theme.colorScheme.secondary),
              ],
            ],
          ),
          isThreeLine: mission != null && !completed,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mission != null && !completed)
                Text('Missão atual: $mission',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600)),
              Text(subtitle),
            ],
          ),
          trailing: Icon(trailing),
          onTap: paywalled
              ? _openPaywall
              : unlocked
                  ? () => _openLesson(lesson)
                  : null,
        ),
      ));
    }

    if (hiddenCount > 0 && !_showAllLessons) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton(
          onPressed: () => setState(() => _showAllLessons = true),
          child: const Text('Ver próximos treinos da trilha'),
        ),
      ));
    }

    return widgets;
  }

  // #10 Card de abandono: aparece quando a pessoa começou mas não fechou o
  // 1º ciclo (gravou, mas não chegou ao antes/depois). Pergunta o porquê.
  Widget _abandonCard(ThemeData theme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O que te impediu de continuar?',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (val, label) in _abandonOptions)
                    ActionChip(
                      label: Text(label),
                      onPressed: () => _answerAbandon(val),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  void _answerAbandon(String reason) {
    widget.analytics?.log('abandon_reason', {'reason': reason});
    widget.store.setAskedAbandon();
    setState(() => _abandonAnswered = true);
  }

  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonScreen(
        lesson: lesson,
        assessor: widget.assessor,
        store: widget.store,
        analytics: widget.analytics,
        rigorous: widget.store.rigorousMode,
      ),
    ));
    // Progresso pode ter mudado: reavalia elegibilidade e refaz o sorteio se
    // o dia virou enquanto a tela estava aberta.
    _ensureDailyChallenge();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.store.totalApproved;
    final next = _nextLesson();
    final challenge = _challenge;
    // #10: começou a praticar (gravou) mas não chegou ao antes/depois → perguntar.
    final askAbandon = !_abandonAnswered &&
        widget.store.hasDone('first_recording_completed') &&
        !widget.store.hasDone('first_before_after_seen') &&
        !widget.store.hasAskedAbandon;
    // Oferta Beta Fundador: só depois do "momento uau" (viu o antes/depois) e
    // enquanto a pessoa não entrou na lista de Fundadores.
    final showFounderOffer = widget.store.hasDone('first_before_after_seen') &&
        !widget.store.hasLeftFounderEmail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('484 Method'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClearData();
              if (v == 'toggle_founder') _toggleFounderAccess();
              if (v == 'privacy') _openPrivacyPolicy();
              if (v == 'stats') _openStats();
              if (v == 'theme') _openThemeChooser();
              if (v == 'words') _openWordMemory();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'theme',
                child: Text('Tema'),
              ),
              if (Backend.instance != null)
                const PopupMenuItem(
                  value: 'words',
                  child: Text('Meu mapa de fala'),
                ),
              if (Backend.instance != null)
                const PopupMenuItem(
                  value: 'stats',
                  child: Text('Painel de uso'),
                ),
              const PopupMenuItem(
                value: 'privacy',
                child: Text('Política de privacidade'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Apagar meus dados'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (askAbandon) ...[
                _abandonCard(theme),
                const SizedBox(height: 12),
              ],
              if (next != null) ...[
                _nextBestActionCard(theme, next, total == Duration.zero),
                const SizedBox(height: 12),
              ],
              _cohortCard(theme),
              const SizedBox(height: 12),
              // #7: meta de hoje (curta e tangível) antes do primeiro marco
              // e da jornada de 484h — hierarquia do mais imediato pro mais
              // distante, pra "1min aprovado" não parecer minúsculo demais.
              _todayGoalCard(theme),
              const SizedBox(height: 12),
              if (challenge != null) ...[
                _dailyChallengeCard(theme, challenge),
                const SizedBox(height: 12),
              ],
              if (showFounderOffer) ...[
                _founderOfferCard(theme),
                const SizedBox(height: 12),
              ],
              if (!widget.store.reachedFirstMilestone) ...[
                _firstMilestoneCard(theme),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jornada 484h iniciada',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: widget.store.goalFraction,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: theme.colorScheme.secondary,
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        total.inSeconds > 0
                            ? '${_format(total)} de treino aprovado no total'
                            : 'Comece o primeiro treino hoje.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (widget.store.streakDays > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🔥 ${widget.store.streakDays} '
                          '${widget.store.streakDays == 1 ? "dia" : "dias"} seguidos',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _precisionModeCard(theme),
              const SizedBox(height: 16),
              Text('Trilha 1 — Saia do inglês mudo',
                  style: theme.textTheme.titleMedium),
              Text('Inglês que você já conhece',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              ..._lessonList(theme),
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    if (d.inMinutes > 0) return '${d.inMinutes}min ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}
