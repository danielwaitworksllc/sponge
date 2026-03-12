#!/usr/bin/env bash
# release.sh — Build, sign with Sparkle EdDSA, tag, and publish a new Sponge release.
#
# Usage: ./scripts/release.sh 1.3
#
# Prerequisites:
#   1. SPARKLE_PRIVATE_KEY env var set (base64 key from Sparkle's generate_keys tool)
#   2. `gh` CLI authenticated
#   3. Sparkle's `sign_update` tool in PATH (see below)
#
# To get sign_update: after adding Sparkle via Xcode SPM, it lives at:
#   ~/Library/Developer/Xcode/DerivedData/Sponge-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
# Or download from https://github.com/sparkle-project/Sparkle/releases and add to /usr/local/bin/

set -e

VERSION="${1:?Usage: $0 <version>  e.g.  $0 1.3}"
TAG="v${VERSION}"
APP_NAME="Sponge"
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
BUILD_DIR="/Users/danielwait/Library/Developer/Xcode/DerivedData/Sponge-abyqkaxkuzaomxcgonignswyrnps/Build/Products/Debug"
APPCAST="docs/appcast.xml"

echo "==> Building ${APP_NAME} ${VERSION}..."
cd "$(dirname "$0")/.."
cd Sponge && xcodebuild -scheme Sponge -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -5
cd ..

echo "==> Creating zip..."
cd "${BUILD_DIR}"
ditto -c -k --keepParent "${APP_NAME}.app" "/tmp/${ZIP_NAME}"
cd -

ZIP_PATH="/tmp/${ZIP_NAME}"
ZIP_SIZE=$(stat -f%z "${ZIP_PATH}")

echo "==> Signing with Sparkle EdDSA..."
# sign_update outputs: sparkle:edSignature="..." length="..."
SIGNATURE=$(sign_update "${ZIP_PATH}" --ed-key-file <(echo "${SPARKLE_PRIVATE_KEY}") 2>/dev/null \
    | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')

if [ -z "${SIGNATURE}" ]; then
    echo "ERROR: sign_update failed. Is SPARKLE_PRIVATE_KEY set and sign_update in PATH?"
    exit 1
fi

echo "Signature: ${SIGNATURE}"

echo "==> Updating appcast.xml..."
RELEASE_URL="https://github.com/danielwaitworksllc/classrecordingmacapp/releases/download/${TAG}/${ZIP_NAME}"
TODAY=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

# Prepend new item to appcast (simple heredoc approach — keeps history)
NEW_ITEM="        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${TODAY}</pubDate>
            <sparkle:version>$(git rev-list --count HEAD)</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url=\"${RELEASE_URL}\"
                sparkle:edSignature=\"${SIGNATURE}\"
                length=\"${ZIP_SIZE}\"
                type=\"application/octet-stream\"
            />
        </item>"

# Insert after <channel> block header (before first <item>)
awk -v new_item="${NEW_ITEM}" '/<item>/ && !inserted { print new_item; inserted=1 } { print }' \
    "${APPCAST}" > /tmp/appcast_new.xml && mv /tmp/appcast_new.xml "${APPCAST}"

echo "==> Committing appcast + tagging..."
git add "${APPCAST}"
git commit -m "Release ${VERSION} — update appcast.xml"
git tag "${TAG}"

echo "==> Pushing..."
git push origin main
git push origin "${TAG}"

echo "==> Creating GitHub release..."
gh release create "${TAG}" "${ZIP_PATH}" \
    --title "Sponge v${VERSION}" \
    --notes "See CHANGELOG.md for details."

echo ""
echo "✓ Released ${TAG}"
echo "  Appcast: https://danielwaitworksllc.github.io/classrecordingmacapp/appcast.xml"
echo "  Users will be notified automatically on next app launch."
