import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ponte com o Supabase. Projetada para degradar com elegância: sem URL/chave
/// configuradas, [instance] é null e o app roda 100% local (ProgressStore +
/// AnalyticsService em localStorage). Com chaves, faz sign-in anônimo (cada
/// usuário ganha um id estável sem cadastro) e espelha progresso e eventos.
///
/// Toda chamada de rede é fire-and-forget e protegida: o local é a fonte de
/// verdade da UI; o Supabase é o espelho durável (cross-device + analytics).
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
  /// em qualquer falha (função não configurada, offline, timeout) — o app
  /// usa a mensagem fixa nesse caso.
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

  /// LGPD: apaga os dados remotos do usuário (progresso + eventos). Chamado
  /// pela exclusão de dados do app, fechando o ciclo "apagar = some de tudo".
  /// Falha silenciosa não impede a limpeza local (fonte de verdade da UI).
  Future<void> deleteRemoteData() async {
    final uid = userId;
    if (uid == null) return;
    try {
      await client.from('events').delete().eq('user_id', uid);
      await client.from('progress').delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('[backend] deleteRemoteData falhou: $e');
    }
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
}
