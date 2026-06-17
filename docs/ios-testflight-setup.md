# iOS → TestFlight: engatilhar quando o Apple Developer Program estiver ativo

Status: **bloqueado por Apple Developer Program** (US$ 99/ano, ainda não
adquirido). O CI atual (`.github/workflows/ios.yml`) já compila o app pra iOS
SEM assinatura a cada push. Este doc adiciona o build **assinado** + upload
pro **TestFlight**. Tudo aqui é executável em minutos assim que a conta existir.

Dados do app (já no projeto):
- Bundle ID: `com.method484.method484`
- Nome: `Method484` · iOS deployment target: 13.0
- Repo: `geovaneparanayba/484-method` (privado)

---

## Parte A — No portal da Apple (uma vez, após o enrollment)

1. **Inscrever-se** no Apple Developer Program e anotar o **Team ID**
   (Membership → Team ID, 10 caracteres).
2. **App ID / Identifier**: Certificates, IDs & Profiles → Identifiers → `+` →
   App IDs → App. Bundle ID **explícito** = `com.method484.method484`.
3. **Certificado de distribuição**: Certificates → `+` → *Apple Distribution*.
   Gere o CSR no Keychain Access (você precisa fazer isso num Mac com acesso ao
   Keychain — serve este). Baixe o `.cer`, abra no Keychain, e **exporte como
   `.p12`** (com senha) — esse `.p12` + a senha viram secrets.
4. **Provisioning profile (App Store)**: Profiles → `+` → *App Store
   Connect* → escolha o App ID e o certificado de distribuição acima → baixe o
   `.mobileprovision`.
5. **App Store Connect**: crie o registro do app (apps.apple.com → My Apps →
   `+`) com o mesmo bundle ID.
6. **Chave de API do App Store Connect** (pro upload sem senha): App Store
   Connect → Users and Access → Integrations → App Store Connect API → `+`.
   Anote **Issuer ID** e **Key ID**, e baixe o arquivo **`.p8`** (só baixa uma
   vez). Função "App Manager" basta.

---

## Parte B — Criar os secrets no GitHub

Com os arquivos da Parte A em mãos, rode (precisa do `gh` autenticado):

```bash
REPO=geovaneparanayba/484-method

# Certificado de distribuição (.p12) e sua senha
base64 -i Distribution.p12 | gh secret set BUILD_CERTIFICATE_BASE64 --repo $REPO
printf '%s' 'SENHA_DO_P12' | gh secret set P12_PASSWORD --repo $REPO

# Provisioning profile (App Store)
base64 -i method484.mobileprovision | gh secret set PROVISIONING_PROFILE_BASE64 --repo $REPO

# App Store Connect API key
printf '%s' 'ISSUER_ID'  | gh secret set APPSTORE_ISSUER_ID --repo $REPO
printf '%s' 'KEY_ID'     | gh secret set APPSTORE_KEY_ID    --repo $REPO
gh secret set APPSTORE_PRIVATE_KEY --repo $REPO < AuthKey_XXXXX.p8

# Chaves de runtime (o build assinado precisa delas; o CI não-assinado não)
# Pegue os valores do .env local.
printf '%s' 'AZURE_SPEECH_KEY'    | gh secret set AZURE_SPEECH_KEY    --repo $REPO
printf '%s' 'brazilsouth'         | gh secret set AZURE_SPEECH_REGION --repo $REPO
printf '%s' 'SUPABASE_URL'        | gh secret set SUPABASE_URL        --repo $REPO
printf '%s' 'SUPABASE_ANON_KEY'   | gh secret set SUPABASE_ANON_KEY   --repo $REPO
```

Conferir: `gh secret list --repo geovaneparanayba/484-method`.

---

## Parte C — Adicionar os 2 arquivos ao repo

> ⚠️ O token atual do `gh` tem escopo `repo` mas **não** `workflow`, então push
> de arquivos em `.github/workflows/` é rejeitado. Duas opções:
> (a) adicionar pela **UI web** do GitHub (Add file → Create new file), como já
> fizemos com `ios.yml`; ou (b) rodar `gh auth refresh -h github.com -s workflow`
> (o endpoint de device flow do GitHub andou dando 503 — tentar de novo) e aí o
> Claude empurra direto.

### C.1 — `ios/ExportOptions.plist`

Troque `YOUR_TEAM_ID` pelo Team ID da Parte A.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.method484.method484</key>
    <string>Method484 App Store</string>
  </dict>
</dict>
</plist>
```

(`Method484 App Store` = o **nome** do provisioning profile criado na Parte A;
ajuste se você nomeou diferente.)

### C.2 — `.github/workflows/ios-testflight.yml`

```yaml
name: iOS TestFlight

# Build ASSINADO + upload pro TestFlight. Disparo manual ou ao criar uma tag
# v*. Requer os secrets de docs/ios-testflight-setup.md (Apple Developer ativo).

on:
  workflow_dispatch:
  push:
    tags: ['v*']

jobs:
  testflight:
    name: Build assinado + TestFlight
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Dependências
        run: flutter pub get

      - name: Importar certificado de distribuição
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          p12-password: ${{ secrets.P12_PASSWORD }}

      - name: Instalar provisioning profile
        run: |
          PROFILES=~/Library/MobileDevice/Provisioning\ Profiles
          mkdir -p "$PROFILES"
          echo "${{ secrets.PROVISIONING_PROFILE_BASE64 }}" | base64 --decode \
            > "$PROFILES/method484.mobileprovision"

      - name: Build IPA assinado
        run: |
          flutter build ipa --release \
            --export-options-plist=ios/ExportOptions.plist \
            --dart-define=AZURE_SPEECH_KEY="${{ secrets.AZURE_SPEECH_KEY }}" \
            --dart-define=AZURE_SPEECH_REGION="${{ secrets.AZURE_SPEECH_REGION }}" \
            --dart-define=SUPABASE_URL="${{ secrets.SUPABASE_URL }}" \
            --dart-define=SUPABASE_ANON_KEY="${{ secrets.SUPABASE_ANON_KEY }}"

      - name: Upload pro TestFlight
        uses: apple-actions/upload-testflight-build@v3
        with:
          app-path: build/ios/ipa/Method484.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
```

Se o nome do `.ipa` não for `Method484.ipa`, troque por `build/ios/ipa/*.ipa`.

---

## Parte D — Rodar e verificar

1. Actions → **iOS TestFlight** → *Run workflow* (ou `git tag v0.1.0 && git push --tags`).
2. Acompanhar: `gh run watch <id> --repo geovaneparanayba/484-method --exit-status`.
3. App Store Connect → TestFlight → o build aparece em "Processing"; depois
   adicione ao seu dispositivo (TestFlight no iPhone).

### Tropeços comuns
- **No profiles matching**: bundle ID do profile ≠ `com.method484.method484`,
  ou o profile não cobre o certificado importado.
- **No signing certificate**: `.p12` é de *Apple Distribution* (não Development)
  e a `P12_PASSWORD` confere.
- **Invalid API key**: o `.p8` foi passado inteiro (com as linhas BEGIN/END).
- Se a configuração manual de signing custar muito, o **Codemagic** automatiza
  todo esse passo de assinatura — alternativa, não obrigatório.
```
