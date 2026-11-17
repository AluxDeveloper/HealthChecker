#!/bin/zsh
# Instalează Sarcini pe simulatorul iOS (Device Hub) al acestui Mac.
# Rulare:  zsh instaleaza.sh
set -e
cd "$(dirname "$0")"

if ! xcrun simctl help >/dev/null 2>&1; then
  echo "Lipsește Xcode. Instalează-l din App Store, deschide-l o dată, apoi rulează din nou."
  exit 1
fi

# 1. Baza de date PostgreSQL
zsh ./setup_db.sh

# 2. Un iPhone în simulator (cel pornit sau primul disponibil)
DEV=$(xcrun simctl list devices booted | grep -m1 -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || true)
if [[ -z "$DEV" ]]; then
  DEV=$(xcrun simctl list devices available | grep -m1 'iPhone' | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || true)
  if [[ -z "$DEV" ]]; then
    echo "Nu există niciun iPhone în simulator. Adaugă unul din Xcode → Settings → Components."
    exit 1
  fi
  echo "→ Pornesc simulatorul…"
  xcrun simctl boot "$DEV"
fi
open -a DeviceHub 2>/dev/null || open -a Simulator

# 3. Aplicația
echo "→ Instalez Sarcini…"
xattr -dr com.apple.quarantine Sarcini.app 2>/dev/null || true
xcrun simctl install "$DEV" Sarcini.app
xcrun simctl launch "$DEV" com.bunelu.sarcini >/dev/null
echo "✓ Gata! Sarcini e deschisă în Device Hub."
