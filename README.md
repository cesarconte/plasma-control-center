# Plasma Control Centre

A KDE Plasma 6 System Tray whose popup looks and behaves like the **macOS Control Center**.

It is **not** a new tray written from scratch: it is the official Plasma System Tray
(`plasma-workspace` v6.8.1, `applets/systemtray`) built as a standalone applet with its own ID
(`org.cesar.plasmacontrolcenter`), so every feature keeps working — StatusNotifier items, hosted
plasmoids (volume, network, Bluetooth, notifications…), shortcuts, per-entry visibility, panel
icon size/spacing/direction, keep-open pin, and so on. Only the look of the popup changed, and two
layout features were added.

## What changed

| | Stock System Tray | Plasma Control Centre |
|---|---|---|
| Popup | Plain list in two columns | Rounded translucent tiles with a round icon badge, title and status line |
| Header | "Status and Notifications" | "Control Center" |
| Order of entries | Fixed (by category) | Drag & drop in **Edit Controls** mode |
| Size of entries | Fixed | Small (1×1), Medium (2×1), Large (2×2), Wide (4×1) — via the tile's resize button / right click in edit mode, or the **Tile size** selector in the settings |
| Settings | Stock ones | Same ones + a *Tile size* column |

The panel part of the tray (icons shown outside the popup) is untouched.

## Install

### Arch / CachyOS (recommended)

```bash
git clone https://github.com/cesarconte/plasma-control-center.git
cd plasma-control-center/packaging/arch
makepkg -si
```

### Any distribution

Dependencies: Qt 6.8+, KDE Frameworks 6.10+, `libplasma`, `plasma-workspace`, `extra-cmake-modules`, `cmake`, `ninja`, `gettext`.

```bash
./scripts/install.sh        # builds and runs `sudo cmake --install`
```

### Use it in the panel

The stock tray cannot be added from *Add Widgets* (it is an embedded containment), so swap it with:

```bash
./scripts/replace-system-tray.sh            # stock tray -> Plasma Control Centre
./scripts/replace-system-tray.sh --restore  # back to the stock tray
```

then restart the shell if needed: `plasmashell --replace &`.

> Settings are stored per applet instance, so the new tray starts with default entries and you
> choose again what to show in the panel / popup / never.

## Using it

1. Click the tray's arrow to open the popup.
2. Press the ✎ button (**Edit Controls**): tiles wiggle, drag them to reorder, use the corner button (or right click) to resize, **Done** to finish. ↺ restores the default layout.
3. The same tile size can be set from *Configure System Tray…* → *Entries* → *Tile size*.

## Languages

All strings go through KDE's `i18n`; the interface follows the language chosen in System Settings.
English is the source language; **Spanish (Spain)** is included (`po/es`).

To add or update a translation:

```bash
./scripts/extract-messages.sh            # refreshes po/*.pot and merges existing catalogs
mkdir po/<lang> && msginit -i po/plasma_applet_org.cesar.plasmacontrolcenter.pot \
    -l <lang> -o po/<lang>/plasma_applet_org.cesar.plasmacontrolcenter.po
```

## Development

```bash
cmake -S . -B build -G Ninja && ninja -C build
QT_PLUGIN_PATH=$PWD/build/bin plasmoidviewer -a org.cesar.plasmacontrolcenter
```

Source layout: `src/*.cpp|h` — C++ of the stock tray (models, StatusNotifier host, settings);
`src/qml/` — the QML UI (the redesign lives in `AbstractItem.qml`, `HiddenItemsView.qml`,
`ExpandedRepresentation.qml`, `main.qml`, `ConfigGeneral.qml`); `src/dbusmenuqt/` — copy of the
`libdbusmenuqt` helper from `plasma-workspace`.

## License

GPL-2.0-or-later. Derived from KDE Plasma Workspace; see [NOTICE.md](NOTICE.md).
