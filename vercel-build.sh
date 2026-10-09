#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Starting Unified GozVision Web Build for Vercel "
echo "=================================================="

# 1. Ensure Flutter SDK is installed and available
if ! command -v flutter &> /dev/null; then
    echo "[1/5] Flutter not found in PATH. Checking or downloading Flutter SDK..."
    if [ ! -d "$HOME/flutter" ]; then
        echo "Cloning Flutter SDK (stable channel)..."
        git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
    fi
    export PATH="$PATH:$HOME/flutter/bin"
fi

echo "Flutter version:"
flutter --version

# 2. Prepare clean output directory
echo "[2/5] Initializing distribution directory..."
rm -rf dist
mkdir -p dist/clinic dist/patient

# 3. Copy Marketing Landing Page to root (/)
echo "[3/5] Deploying public website to / ..."
cp -r apps/website/* dist/

# 3.5 Ensure client asset configuration exists for Flutter copyAssets
echo "[3.5/5] Ensuring client configuration assets exist..."
mkdir -p apps/clinic/assets apps/patient/assets

if [ ! -f "apps/clinic/assets/app.env" ]; then
    echo "  -> Writing apps/clinic/assets/app.env..."
    cat << 'EOF' > apps/clinic/assets/app.env
SUPABASE_URL=https://zxvdcazzayuwgzpeabfc.supabase.co
SUPABASE_ANON_KEY=sb_publishable_sMWTt1A74hs3AEgQhyMQHg_aWAwL2lk
ADK_BACKEND_URL=https://d7icpdzxenshi.cloudfront.net
EOF
fi

if [ ! -f "apps/patient/assets/app.env" ]; then
    echo "  -> Writing apps/patient/assets/app.env..."
    cat << 'EOF' > apps/patient/assets/app.env
ADK_BACKEND_URL=https://d7icpdzxenshi.cloudfront.net
SUPABASE_URL=https://zxvdcazzayuwgzpeabfc.supabase.co
SUPABASE_ANON_KEY=sb_publishable_sMWTt1A74hs3AEgQhyMQHg_aWAwL2lk
DEMO_PATIENT_EMAIL=demo-patient@gozvision.demo
DEMO_PATIENT_PASSWORD=gozvision-demo
EOF
fi

# 4. Resolve Dart/Flutter Workspace dependencies
echo "[4/5] Resolving Flutter workspace dependencies..."
flutter pub get

# 5. Build Flutter Web applications
echo "[5/5] Compiling Flutter Web portals..."

echo "  -> Compiling Clinic Suite (B2B) for /clinic ..."
cd apps/clinic
flutter build web --release --base-href "/clinic/"
cp -r build/web/* ../../dist/clinic/
cd ../..

echo "  -> Compiling Patient Copilot (PWA) for /patient ..."
cd apps/patient
flutter build web --release --base-href "/patient/"
cp -r build/web/* ../../dist/patient/
cd ../..

echo "=================================================="
echo " Unified Build Complete! Output assembled in dist "
echo " /        -> Marketing Landing Page               "
echo " /clinic  -> Goz Clinic Suite                     "
echo " /patient -> Goz Patient Copilot PWA              "
echo "=================================================="
