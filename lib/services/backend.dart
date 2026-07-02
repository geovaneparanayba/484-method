import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ponte com o Supabase. Projetada para degradar com elegância: sem URL/chave
/// configuradas, [instance] é null e o app roda 100% local (ProgressStore +
/// AnalyticsService em localStorage). Com chaves, faz sign-in anônimo (cada
/// usuário ganha um id estável sem cadastro) e espelha progresso e eventos.
///
/// Toda chamada de rede é fire-and-forget e protegida: o local é a fonte de
/// verdade da UI; o Supabase é o espelho durável (cross-device + analytics).
/// Senha errada no painel de uso — distinta de outras falhas (rede,
/// secret não configurado) para a UI poder dizer "senha incorreta".
class DevStatsAuthException implements Exception {
  const DevStatsAuthException();
}

class Backend {
  Backend._(this.client);

  final SupabaseClient client;

  static Backend? instance;

  /// Inicializa se as credenciais existirem. Falha silenciosa (offline,
  /// projeto fora do ar) mantém o app em modo local.
  static Future<void> init({
    required String url,
    required String anonKey,
  }) async {
    if (url.isEmpty || anonKey.isEmpty) return;
    try {
      // publishableKey aceita tanto a anon key (JWT legado) quanto a
      // publishable key nova — ambas são apenas a chave pública da API.
      await Supabase.initialize(url: url, publishableKey: anonKey);
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      instance = Backend._(client);
    } catch (e) {
      debugPrint('[backend] indisponível, seguindo local-only: $e');
    }
  }

  String? get userId => client.auth.currentUser?.id;

  /// Bucket privado das gravações de fala aberta do desafio de 21 dias
  /// (baseline/final), pro antes/depois com rating cego. RLS: cada usuário só
  /// acessa a própria pasta {uid}/. Ver migração cohort_recordings_storage.
  static const _cohortBucket = 'cohort-recordings';

  /// Sobe a gravação (baseline/final) pro Storage e registra os metadados.
  /// Best-effort: qualquer falha retorna false e o app segue — o áudio é um
  /// artefato de validação, não a métrica norte. Objeto em {uid}/{kind}-{ts}.wav.
  Future<bool> uploadCohortRecording({
    required String kind,
    required Uint8List wavBytes,
    required int durationMs,
    required int cohortDay,
  }) async {
    final uid = userId;
    if (uid == null) return false;
    try {
      final path = '$uid/$kind-${DateTime.now().millisecondsSinceEpoch}.wav';
      await client.storage.from(_cohortBucket).uploadBinary(
            path,
            wavBytes,
            fileOptions: const FileOptions(contentType: 'audio/wav'),
          );
      await client.from('cohort_recordings').insert({
        'user_id': uid,
        'kind': kind,
        'storage_path': path,
        'duration_ms': durationMs,
        'cohort_day': cohortDay,
      });
      return true;
    } catch (e) {
      debugPrint('[backend] uploadCohortRecording falhou: $e');
      return false;
    }
  }

  Future<void> pushProgress(Map<String, dynamic> snapshot) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await client.from('progress').upsert({
        'user_id': uid,
        ...snapshot,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[backend] pushProgress falhou (local mantém): $e');
    }
  }

  Future<void> pushEvent(String event, Map<String, Object?> props) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await client.from('events').insert({
        'user_id': uid,
        'event': event,
        'props': props,
      });
    } catch (e) {
      debugPrint('[backend] pushEvent falhou: $e');
    }
  }

  /// Feedback de pronúncia gerado pela Edge Function (Claude). Retorna null
  /// em qualquer falha (função não configurada, offline, timeout, ou teto
  /// diário atingido → 429) — o app usa a mensagem fixa nesse caso.
  Future<String?> generateFeedback(Map<String, Object?> params) async {
    if (userId == null) return null;
    try {
      final res = await client.functions
          .invoke('feedback', body: params)
          .timeout(const Duration(seconds: 6));
      if (res.status != 200) return null;
      final data = res.data;
      final message = (data is Map) ? data['message'] as String? : null;
      return (message != null && message.trim().isNotEmpty) ? message : null;
    } catch (e) {
      debugPrint('[backend] generateFeedback falhou: $e');
      return null;
    }
  }

  /// LGPD: apaga os dados remotos do usuário (progresso + eventos + gravações
  /// do desafio). Chamado pela exclusão de dados do app, fechando o ciclo
  /// "apagar = some de tudo". Falha silenciosa não impede a limpeza local
  /// (fonte de verdade da UI).
  Future<void> deleteRemoteData() async {
    final uid = userId;
    if (uid == null) return;
    // Gravações do desafio (Storage + metadados) num bloco PRÓPRIO: uma falha
    // aqui (ex.: Storage fora do ar) não pode impedir a exclusão de
    // progresso/eventos, que é o núcleo do direito de apagamento.
    try {
      final recs = await client
          .from('cohort_recordings')
          .select('storage_path')
          .eq('user_id', uid);
      final paths = [
        for (final r in (recs as List)) r['storage_path'] as String,
      ];
      if (paths.isNotEmpty) {
        await client.storage.from(_cohortBucket).remove(paths);
      }
      await client.from('cohort_recordings').delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('[backend] deleteRemoteData (gravações) falhou: $e');
    }
    try {
      await client.from('events').delete().eq('user_id', uid);
      await client.from('progress').delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('[backend] deleteRemoteData falhou: $e');
    }
  }

  /// Painel de uso interno. A senha é checada pela Edge Function `dev-stats`
  /// (secret DEV_STATS_PASSWORD) — get_dev_stats() não é mais chamável direto
  /// pelo cliente (EXECUTE revogado de anon/authenticated), então não basta
  /// ter a anon key pública para ler os agregados de todos os usuários.
  Future<Map<String, dynamic>> fetchDevStats(String password) async {
    final res = await client.functions.invoke(
      'dev-stats',
      body: {'password': password},
    );
    if (res.status == 401) throw const DevStatsAuthException();
    if (res.status != 200) {
      throw Exception('Painel indisponível (código ${res.status}).');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Rating cego: lista as gravações do desafio (baseline/final) com URLs
  /// ASSINADAS geradas pela Edge Function `dev-stats` (service role assina o
  /// bucket privado), atrás do mesmo gate de senha do painel. Cada item traz
  /// url, kind, duration_ms e a nota já dada (score/note), se houver.
  Future<List<Map<String, dynamic>>> fetchCohortRecordings(
      String password) async {
    final res = await client.functions.invoke(
      'dev-stats',
      body: {'password': password, 'action': 'list_recordings'},
    );
    if (res.status == 401) throw const DevStatsAuthException();
    if (res.status != 200) {
      throw Exception('Falha ao carregar gravações (código ${res.status}).');
    }
    final data = res.data;
    final list = (data is Map ? data['recordings'] : null) as List?;
    return (list ?? const []).cast<Map<String, dynamic>>();
  }

  /// Rating cego: grava/atualiza a nota (1–5) de uma gravação. Passa pela
  /// mesma Edge Function/gate de senha; a tabela cohort_ratings não tem policy
  /// de cliente (só a service role escreve).
  Future<void> saveCohortRating(
      String password, String recordingId, int score, String? note) async {
    final res = await client.functions.invoke('dev-stats', body: {
      'password': password,
      'action': 'rate',
      'recording_id': recordingId,
      'score': score,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (res.status == 401) throw const DevStatsAuthException();
    if (res.status != 200) {
      throw Exception('Falha ao salvar a nota (código ${res.status}).');
    }
  }

  /// Liga/desliga global do app (app_config/'maintenance'), checado no boot.
  /// Fail-open: qualquer falha (offline, tabela ausente) devolve false — a
  /// checagem de manutenção nunca pode derrubar o app por acidente.
  Future<bool> fetchMaintenanceMode() async {
    try {
      final row = await client
          .from('app_config')
          .select('value')
          .eq('key', 'maintenance')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      final value = row?['value'];
      return value is Map && value['on'] == true;
    } catch (e) {
      debugPrint('[backend] fetchMaintenanceMode falhou (seguindo no ar): $e');
      return false;
    }
  }

  /// Liga/desliga o app pelo painel do dev. A escrita passa pela Edge
  /// Function `dev-stats` (a tabela não tem policy de escrita), atrás do
  /// mesmo gate de senha do painel. Devolve as stats atualizadas (inclui
  /// `maintenance_mode` confirmado pelo servidor).
  Future<Map<String, dynamic>> setMaintenanceMode(
      String password, bool on) async {
    final res = await client.functions.invoke(
      'dev-stats',
      body: {'password': password, 'set_maintenance': on},
    );
    if (res.status == 401) throw const DevStatsAuthException();
    if (res.status != 200) {
      throw Exception('Não foi possível alterar (código ${res.status}).');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Progresso remoto (para hidratar o cache local em outro dispositivo).
  Future<Map<String, dynamic>?> pullProgress() async {
    final uid = userId;
    if (uid == null) return null;
    try {
      return await client
          .from('progress')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
    } catch (e) {
      debugPrint('[backend] pullProgress falhou: $e');
      return null;
    }
  }

  /// Histórico de tentativas do próprio usuário (RLS: só enxerga as suas).
  /// Alimenta a tela "Minhas palavras" — a memória de erros e acertos.
  /// Lista vazia em qualquer falha (offline) → a tela mostra estado vazio.
  Future<List<Map<String, dynamic>>> fetchAttemptHistory() async {
    final uid = userId;
    if (uid == null) return const [];
    try {
      final rows = await client
          .from('events')
          .select('props, created_at')
          .eq('user_id', uid)
          .eq('event', 'attempt_assessed')
          .order('created_at');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[backend] fetchAttemptHistory falhou: $e');
      return const [];
    }
  }
}
