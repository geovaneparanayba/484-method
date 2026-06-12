#!/usr/bin/env bash
# Roda o app no Chrome com as credenciais do .env injetadas via dart-define
# (a chave não fica em asset nem em código).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Arquivo .env não encontrado. Copie .env.example para .env e preencha." >&2
  exit 1
fi

set -a
source .env
set +a

exec flutter run -d chrome \
  --dart-define=AZURE_SPEECH_KEY="${AZURE_SPEECH_KEY:-}" \
  --dart-define=AZURE_SPEECH_REGION="${AZURE_SPEECH_REGION:-brazilsouth}"
