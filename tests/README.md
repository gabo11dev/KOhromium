# Integration tests

The tests require the official KOReader Linux runtime (v2026.07.1 used here), real Chromium headless-shell and Xvfb. They are development inputs, not included in the plugin binary package.

`smoke.lua` runs inside KOReader's LuaJIT from the KOReader installation directory. Set KOHROMIUM_SOURCE to the source root and KOHROMIUM_TEST_ENGINE to a native engine executable. It tests transport, page title, PNG capture and process shutdown.

`ui.lua` initializes actual KOReader widgets and a reader-view return target; it uses an isolated copy of the plugin. It checks the native menu/keyboard stacking, Spanish virtual keyboard, page field tap, native editor Enter action, Chromium value/keydown, zoom and close/return. The reader return target is a KOReader widget, not a loaded book.

`run-ui.py` is the local development harness: set KOHROMIUM_TEST_RUNTIME to a development directory containing test-runtime/root/usr/bin/Xvfb, its native libraries under test-runtime/root/usr/lib/x86_64-linux-gnu, and official-engine/chrome-headless-shell-linux64/chrome-headless-shell. KOREADER_TEST_DIR optionally overrides build/lib/koreader. All state stays under build/. No hardware framebuffer is accessed. The harness can select a different engine via KOHROMIUM_TEST_ENGINE for protocol tests, but the bundled Kindle runtime still needs hardware verification.

`navigation.lua` exercises real Chromium back/forward, reload, Android user agent, arrow input, scrolling, shutdown and a broken socket without SIGPIPE. Run with the same LuaJIT/environment as smoke.lua.
