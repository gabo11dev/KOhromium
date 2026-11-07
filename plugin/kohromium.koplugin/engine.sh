#!/bin/sh
APP_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || exit 1
export LD_LIBRARY_PATH="$APP_DIR/runtime/lib"
export FONTCONFIG_FILE="$APP_DIR/runtime/share/fonts.conf"
export FONTCONFIG_PATH="$APP_DIR/runtime/share"
export XDG_CACHE_HOME="$APP_DIR/state/cache"
export GSETTINGS_BACKEND=memory
export GIO_USE_VFS=local
unset LD_PRELOAD
mkdir -p "$XDG_CACHE_HOME" || exit 1
exec "$APP_DIR/engine/chromium-headless-shell" "$@"
