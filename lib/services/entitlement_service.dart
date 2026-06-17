import 'package:shared_preferences/shared_preferences.dart';

/// Acesso pago ao conteúdo além das lições grátis (oferta "Beta Fundador").
///
/// Abstração de plataforma, no mesmo espírito da gravação de áudio: na
/// web/dev usamos [LocalEntitlementService] (toggle persistido) porque o SDK
/// do RevenueCat (`purchases_flutter`) só roda em iOS/Android. Quando houver
/// build mobile + conta Apple, uma implementação baseada em RevenueCat
/// satisfaz ESTA MESMA interface — sem tocar na UI nem no gating.
abstract interface class EntitlementService {
  /// O usuário tem acesso à oferta Beta Fundador (Fase 1 completa)?
  bool get hasFounderAccess;

  /// Define o acesso. Na implementação fake (web/dev) é o gatilho de teste;
  /// a real (RevenueCat) sincroniza com a loja após a compra/restauração.
  Future<void> setFounderAccess(bool value);
}

/// Quantas lições da Fase 1 ficam liberadas sem o Beta Fundador.
const int kFreeLessonCount = 3;

/// Implementação local (web/dev): persiste o acesso em SharedPreferences,
/// permitindo testar os dois estados sem loja. Default: sem acesso.
class LocalEntitlementService implements EntitlementService {
  LocalEntitlementService(this._prefs);

  static const _kFounderAccess = 'founder_access';

  final SharedPreferences _prefs;

  static Future<LocalEntitlementService> load() async =>
      LocalEntitlementService(await SharedPreferences.getInstance());

  @override
  bool get hasFounderAccess => _prefs.getBool(_kFounderAccess) ?? false;

  @override
  Future<void> setFounderAccess(bool value) async {
    await _prefs.setBool(_kFounderAccess, value);
  }
}
