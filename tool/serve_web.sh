#!/usr/bin/env bash
# Compila a build web de RELEASE e serve em http://localhost:8484 com um
# servidor estático leve. Mais estável que `flutter run` nesta máquina
# (8 GB de RAM): o daemon de dev do Flutter morre sob pressão de memória.
# Use tool/run_web.sh quando precisar de hot reload.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Arquivo .env não encontrado. Copie .env.example para .env e preencha." >&2
  exit 1
fi

set -a
source .env
set +a

# Chave do Azure não entra no build (a avaliação passa pela Edge Function
# `assess`); só as chaves públicas do Supabase.
flutter build web \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# Derruba o que estiver na porta e sobe o servidor estático.
lsof -ti :8484 | xargs kill -9 2>/dev/null || true
echo "Servindo em http://localhost:8484"
exec python3 -m http.server 8484 --directory build/web
