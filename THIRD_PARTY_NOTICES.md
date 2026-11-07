# Third-party components

## Chromium and private runtime

The binary distribution uses the engine/runtime from Khromium 156.0 HF. Chromium headless-shell 156.0.8078.73 ARMhf originates from Raspberry Pi Debian package `1:156.0.8078.73-1~deb12u1+rpt1`, with matching Chromium common data. Exact package hashes/source URL are retained in the packaged manifest. The engine executable's interpreter path is changed from `/mnt/us/khromiumld.so` to `/mnt/us/kohromiumld.so`; engine code is unchanged.

Corresponding Chromium source/packages are available from https://archive.raspberrypi.com/debian/pool/main/c/chromium/ . Chromium and its components retain their upstream BSD/other licenses. Private Debian 12 ARMhf libraries, glibc 2.36 and DejaVu fonts retain their individual licenses. Copyright/source metadata and license texts are included under `kohromium.koplugin/licenses/`. Debian corresponding sources are available at https://sources.debian.org/ and https://deb.debian.org/debian/pool/ using the versions recorded in the bundled metadata.

## KOReader

KOReader is a separate prerequisite and is not bundled. This plugin uses its documented/source APIs for widgets, the on-screen keyboard, rendering, settings, input and process support. KOReader is AGPL-3.0 software: https://github.com/koreader/koreader . Its v2026.07.1 Linux runtime was used for development tests only. The plugin does not redistribute that test installation.

API references include KOReader's `frontend/ui/widget/inputdialog.lua`, `frontend/ui/widget/imagewidget.lua`, `frontend/ui/renderimage.lua`, `frontend/ui/uimanager.lua` and the POSIX usage in `plugins/terminal.koplugin/main.lua`. Original plugin code is MIT-licensed and calls KOReader-provided modules at runtime.

## Khromium

The offline home page and engine integration approach derive from the MIT-licensed Khromium project: https://github.com/gabo11dev/Khromium . Existing notices are preserved by the included MIT license and engine/runtime license directory.
