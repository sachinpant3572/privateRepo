#!/usr/bin/env bash
# Sets up a fresh Linux (Ubuntu) container to run, test and export the prototype:
# Godot, Android export templates, signing tools and a debug keystore.
# Safe to re-run; skips steps that are already done.
set -euo pipefail
VERSION=4.7.2-stable
TEMPLATES=/root/.local/share/godot/export_templates/${VERSION/-/.}
SDK=/opt/android-sdk
RELEASES=https://github.com/godotengine/godot/releases/download/$VERSION

if ! command -v godot >/dev/null; then
	mkdir -p /opt/godot
	curl -sSL -o /tmp/godot.zip "$RELEASES/Godot_v${VERSION}_linux.x86_64.zip"
	unzip -oq /tmp/godot.zip -d /opt/godot && rm /tmp/godot.zip
	ln -sf "/opt/godot/Godot_v${VERSION}_linux.x86_64" /usr/local/bin/godot
fi

if [ ! -f "$TEMPLATES/android_debug.apk" ]; then
	mkdir -p "$TEMPLATES" /tmp/godot-tpl
	curl -sSL -o /tmp/godot-tpl/t.tpz "$RELEASES/Godot_v${VERSION}_export_templates.tpz"
	unzip -oq /tmp/godot-tpl/t.tpz templates/android_debug.apk templates/android_release.apk templates/version.txt -d /tmp/godot-tpl
	mv /tmp/godot-tpl/templates/* "$TEMPLATES/"
	rm -f /tmp/godot-tpl/t.tpz
fi

if ! command -v apksigner >/dev/null; then
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apksigner zipalign android-sdk-platform-tools >/dev/null
fi
# Godot only needs adb and the build tools, so a minimal SDK layout is enough.
mkdir -p "$SDK/platform-tools" "$SDK/build-tools/31.0.2"
ln -sf "$(command -v adb)" "$SDK/platform-tools/adb"
ln -sf "$(command -v apksigner)" "$SDK/build-tools/31.0.2/apksigner"
ln -sf "$(command -v zipalign)" "$SDK/build-tools/31.0.2/zipalign"

KEYSTORE=/root/.android/debug.keystore
if [ ! -f "$KEYSTORE" ]; then
	mkdir -p /root/.android
	keytool -genkeypair -keystore "$KEYSTORE" -storepass android -alias androiddebugkey \
		-keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

JAVA_HOME_DIR=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
mkdir -p /root/.config/godot
cat > "/root/.config/godot/editor_settings-${VERSION%%.*}.$(echo "$VERSION" | cut -d. -f2 | cut -d- -f1).tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA_HOME_DIR"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS

godot --version
