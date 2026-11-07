# KOhromium 156.0 HF Alpha 1 validation

This is a new native KOReader plugin. It has not been tested on a physical Kindle.

- Development used the official KOReader Linux x86-64 v2026.07.1 runtime, native SDL/BlitBuffer widgets, Xvfb and a real Chromium 156 engine.
- The local socket/CDP transport starts Chromium, obtains document titles and PNG screenshots, then terminates/reaps the child.
- The UI integration test registers the plugin menu, opens the browser, displays the home screenshot, opens KOReader menus and its text dialog, and verifies that they are above the browser in the real widget stack.
- The touch-mode test uses KOReader's Spanish on-screen keyboard configuration, taps a page field, edits it through the native text widget and presses the dialog's Enter action. Chromium receives ñ KOReader and an Enter keydown.
- Page zoom changes the engine viewport; native KOReader displays the resulting PNG. Closing frees the page buffer, stops the engine, restores the underlying KOReader widget and balances the standby inhibition.
- Startup capture requests are gated during early navigation and have a retry watchdog. The native browser is not a modal layer, so its menu and keyboard remain visible above it.
- Private runtime/engine data are reused from the HF build; only the ELF interpreter path changes. Package checks include hashes, the native plugin tree and exclusion of GTK2 executables, profiles, logs and development files.

Pending physical verification: KOReader plugin loading/menu placement on the PW4, actual touchscreen gestures, Kindle framebuffer/e-ink behavior, suspend/rotation events, Wi-Fi/HTTPS, free RAM with an open book and long sessions. Desktop success does not establish these properties.

The real-engine navigation integration test also passed: back, forward, reload, Android 11 user agent, arrow key dispatch, wheel scrolling, child shutdown and broken-pipe handling without SIGPIPE.
