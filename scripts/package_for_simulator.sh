#!/bin/zsh
# Face pachetul de trimis altcuiva: dist/Sarcini-simulator.zip
# Rulează-l din nou după fiecare modificare a aplicației.
set -e
cd "$(dirname "$0")/.."

flutter build ios --simulator

OUT=dist/Sarcini
rm -rf "$OUT" dist/Sarcini-simulator.zip
mkdir -p "$OUT"
cp -R build/ios/iphonesimulator/Runner.app "$OUT/Sarcini.app"
cp scripts/install_on_simulator.sh "$OUT/instaleaza.sh"
cp scripts/CITESTE.md "$OUT/CITESTE.md"

(cd dist && ditto -c -k --norsrc --noextattr --keepParent Sarcini Sarcini-simulator.zip)
rm -rf "$OUT"
echo "✓ Pachet gata: $(pwd)/dist/Sarcini-simulator.zip"
