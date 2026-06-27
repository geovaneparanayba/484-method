import 'dart:io';

/// Mobile/desktop (Android, iOS, etc.): sem conceito de "navegador", só SO.
/// `source` fixo em "app" — sem referrer de URL como na web (install
/// referrer do Android seria outra integração, fora de escopo).
Map<String, String> collectDeviceInfo() => {
      'browser': 'n/a',
      'os': Platform.operatingSystem,
      'locale': Platform.localeName,
      'source': 'app',
    };
