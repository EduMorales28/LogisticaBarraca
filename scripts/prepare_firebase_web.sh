#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Verificando Flutter..."
flutter --version >/dev/null

echo "[2/4] Instalando dependencias..."
flutter pub get

echo "[3/4] Compilando web release..."
flutter build web --release --dart-define=LOCAL_ONLY_MODE=false

echo "[4/4] Validando Firebase CLI..."
if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI no esta instalada. Instala con: npm install -g firebase-tools"
  exit 1
fi

firebase use

echo "Listo: proyecto preparado para publicar en Firebase Hosting."
echo "Cuando quieras desplegar, ejecuta: firebase deploy --only hosting"
