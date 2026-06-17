import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/backend.dart';
import 'services/entitlement_service.dart';
import 'services/progress_store.dart';
import 'services/pronunciation_assessor.dart';

// Injetadas em tempo de build pelos scripts em tool/ (que leem o .env).
const _azureKey = String.fromEnvironment('AZURE_SPEECH_KEY');
const _azureRegion =
    String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'brazilsouth');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem credenciais Supabase, Backend.instance fica null e o app roda local.
  await Backend.init(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  final store = await ProgressStore.load(backend: Backend.instance);
  final analytics = await AnalyticsService.load(backend: Backend.instance);
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
  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_azureKey.isEmpty) {
      home = const _MissingKeyScreen();
    } else if (!widget.store.hasVoiceConsent) {
      // LGPD: nenhuma gravação antes do consentimento do onboarding.
      home = OnboardingScreen(
        store: widget.store,
        onDone: () => setState(() {}),
      );
    } else {
      home = HomeScreen(
        store: widget.store,
        entitlement: widget.entitlement,
        assessor: AzurePronunciationAssessor(
          subscriptionKey: _azureKey,
          region: _azureRegion,
        ),
        analytics: widget.analytics,
        // Exclusão de dados derruba o consentimento → volta ao onboarding.
        onDataCleared: () => setState(() {}),
      );
    }
    return MaterialApp(
      title: '484 Method',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: home,
    );
  }
}

class _MissingKeyScreen extends StatelessWidget {
  const _MissingKeyScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chave do Azure não configurada.\n\n'
            '1. Copie .env.example para .env e preencha a chave.\n'
            '2. Rode o app com: ./tool/run_web.sh',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
