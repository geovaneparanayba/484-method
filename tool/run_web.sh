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

# A chave do Azure NÃO vai mais pro cliente: a avaliação passa pela Edge
# Function `assess` (chave como secret do Supabase). Só as chaves públicas
# do Supabase entram no build.
exec flutter run -d chrome --profile --web-port 8484 \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
