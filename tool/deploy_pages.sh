#!/usr/bin/env bash
# Build da demo web e publish no GitHub Pages (branch gh-pages).
#
# Requisitos: .env com SUPABASE_URL/SUPABASE_ANON_KEY, `gh` autenticado, e o
# repo PÚBLICO (Pages grátis só em repo público; ou GitHub Pro).
#
# A chave do Azure NÃO entra no build — a avaliação passa pela Edge Function
# `assess`. Só as chaves públicas do Supabase (anon, protegida por RLS) vão
# no bundle. --pwa-strategy=none desliga o service worker (sem cache de
# versão velha; a demo sempre serve o build atual).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Arquivo .env não encontrado." >&2
  exit 1
fi
set -a
source .env
set +a

REPO="https://github.com/geovaneparanayba/484-method.git"
URL="https://geovaneparanayba.github.io/484-method/"

flutter build web --release --base-href /484-method/ --pwa-strategy=none \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# .nojekyll evita o Jekyll do Pages mexer nos assets do Flutter.
touch build/web/.nojekyll

# Publica o build como raiz da branch gh-pages (repo git efêmero, force-push).
cd build/web
rm -rf .git
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.email="g.paranayba@gmail.com" -c user.name="geovaneparanayba" \
  commit -q -m "Deploy 484 Method — demo web"
git push -fq "$REPO" gh-pages

echo "Publicado em $URL (o CDN leva ~1 min para atualizar)."
