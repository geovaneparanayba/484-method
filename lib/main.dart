import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/backend.dart';
import 'services/backend_assessor.dart';
import 'services/device_info.dart';
import 'services/entitlement_service.dart';
import 'services/progress_store.dart';

// Injetadas em tempo de build pelos scripts em tool/ (que leem o .env).
// A chave do Azure NÃO entra aqui: a avaliação passa pela Edge Function
// `assess`, então a chave vive só como secret do Supabase (não vaza na web).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Backend é obrigatório: a avaliação de pronúncia roda pela Edge Function.
  // Sem credenciais Supabase, Backend.instance fica null → tela de setup.
  await Backend.init(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  final store = await ProgressStore.load(backend: Backend.instance);
  final analytics = await AnalyticsService.load(backend: Backend.instance);
  // Uma vez por sessão: browser/SO/idioma agregados, nunca o user-agent cru.
  analytics.log('device_info', collectDeviceInfo());
  // Topo do funil de aquisição: quem chega ainda sem consentimento vai ver a
  // landing. (Recorrente já consentiu e cai direto no app — não conta de novo.)
  if (!store.hasVoiceConsent) analytics.log('landing_viewed');
  // Web/dev usa o fake local; mobile trocará por RevenueCat na mesma interface.
  final entitlement = await LocalEntitlementService.load();
  runApp(Method484App(
      store: store, analytics: analytics, entitlement: entitlement));
}

class Method484App extends StatefulWidget {
  const Method484App({
    super.key,
    required this.store,
    required this.entitlement,
    this.analytics,
  });

  final ProgressStore store;
  final EntitlementService entitlement;
  final AnalyticsService? analytics;

  @override
  State<Method484App> createState() => _Method484AppState();
}

class _Method484AppState extends State<Method484App> {
  static const _navy  = Color(0xFF1B2D4F);
  static const _gold  = Color(0xFFC9A252);
  static const _cream = Color(0xFFF5F2EB);

  static ThemeData _buildTheme() {
    final cs = ColorScheme.fromSeed(seedColor: _navy).copyWith(
      primary: _navy,
      onPrimary: Colors.white,
      secondary: _gold,
      onSecondary: Colors.white,
      tertiary: _gold,
      onTertiary: Colors.white,
      surface: _cream,
      onSurface: _navy,
      surfaceContainerHighest: const Color(0xFFEBE7DE),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        headlineLarge:  GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, height: 1.2),
        headlineSmall:  GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        titleLarge:     GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        titleMedium:    GoogleFonts.playfairDisplay(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: _navy.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _gold : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _gold.withValues(alpha: 0.4) : null,
        ),
      ),
    );
  }

  // Landing antes do onboarding: enquadra a demo pra quem abre o link cold.
  // Em memória (some no reload) — o usuário recorrente já tem consentimento
  // e cai direto no app, sem ver a landing nem o onboarding.
  bool _introSeen = false;

  // Logo após o onboarding, leva direto à 1ª lição (conserto do funil
  // consentimento→1ª lição). A HomeScreen consome no initState (roda 1x só).
  bool _justOnboarded = false;

  @override
  Widget build(BuildContext context) {
    final Widget home;
    final backend = Backend.instance;
    if (backend == null) {
      home = const _MissingConfigScreen();
    } else if (!widget.store.hasVoiceConsent) {
      // LGPD: nenhuma gravação antes do consentimento do onboarding.
      home = _introSeen
          ? OnboardingScreen(
              store: widget.store,
              onDone: () {
                widget.analytics?.log('onboarding_consent_accepted');
                // Cai direto na 1ª lição (não na dashboard vazia) — remove o
                // atrito consentimento→1ª lição e leva ao "aha" do loop.
                setState(() => _justOnboarded = true);
              },
              onBack: () => setState(() => _introSeen = false),
            )
          : IntroScreen(onStart: () {
              widget.analytics?.log('onboarding_cta_clicked');
              setState(() => _introSeen = true);
            });
    } else {
      home = HomeScreen(
        store: widget.store,
        entitlement: widget.entitlement,
        assessor: BackendPronunciationAssessor(backend),
        analytics: widget.analytics,
        autostartFirstLesson: _justOnboarded,
        // Exclusão de dados derruba o consentimento → volta ao onboarding.
        onDataCleared: () => setState(() {}),
      );
    }
    return MaterialApp(
      title: '484 Method',
      theme: _buildTheme(),
      home: home,
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase não configurado.\n\n'
            '1. Copie .env.example para .env e preencha SUPABASE_URL e '
            'SUPABASE_ANON_KEY.\n'
            '2. Rode o app com: ./tool/run_web.sh',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
