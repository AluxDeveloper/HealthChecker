#!/bin/zsh
# Pregătește PostgreSQL pentru aplicația Sarcini pe un Mac nou.
# Se poate rula de mai multe ori fără probleme.
set -e

# Trebuie să fie aceeași parolă ca în lib/config/db_config.dart.
DB_USER=sarcini_app
DB_NAME=sarcini
DB_PASSWORD='32aa078c632cae7a686699da72a7f0b6'

if ! command -v psql >/dev/null; then
  if ! command -v brew >/dev/null; then
    echo "Lipsește Homebrew. Instalează-l de pe https://brew.sh și rulează din nou scriptul."
    exit 1
  fi
  echo "→ Instalez PostgreSQL…"
  brew install postgresql@18
  brew link --force postgresql@18 >/dev/null 2>&1 || true
  export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
fi

if ! pg_isready -q -h 127.0.0.1; then
  echo "→ Pornesc PostgreSQL…"
  brew services start postgresql@18 >/dev/null 2>&1 || brew services start postgresql
  for i in {1..20}; do pg_isready -q -h 127.0.0.1 && break; sleep 1; done
fi

echo "→ Creez utilizatorul și baza de date (dacă lipsesc)…"
psql -d postgres -v ON_ERROR_STOP=1 -q <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
SQL
if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
  createdb -O $DB_USER $DB_NAME
fi

echo "✓ Baza de date e gata. Tabelele le creează aplicația la prima pornire."
