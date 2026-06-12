import 'package:flutter/material.dart';

import 'screens/practice_screen.dart';
import 'services/pronunciation_assessor.dart';

// Injetadas em tempo de build pelo tool/run_web.sh (que lê o .env).
const _azureKey = String.fromEnvironment('AZURE_SPEECH_KEY');
const _azureRegion =
    String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'brazilsouth');

void main() {
  runApp(const Method484App());
}

class Method484App extends StatelessWidget {
  const Method484App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '484 Method',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _azureKey.isEmpty
          ? const _MissingKeyScreen()
          : PracticeScreen(
              assessor: AzurePronunciationAssessor(
                subscriptionKey: _azureKey,
                region: _azureRegion,
              ),
            ),
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
