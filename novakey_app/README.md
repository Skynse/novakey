# NovaKey Studio

Flutter desktop configuration app for the NovaKey RP2040 macropad.

## Run

```sh
flutter pub get
flutter run -d linux
```

Linux requires Python 3 for the bundled hidraw bridge. Build the firmware with
`../novakey/build.sh`, then flash `../novakey/build/novakey.uf2` using
BOOTSEL. The app requires NovaKey protocol 2.

If hidraw access is denied, install the real udev rule with:

```sh
./linux/install-udev.sh
```

That copies `linux/70-novakey.rules` into `/etc/udev/rules.d/`, reloads udev,
and triggers the hidraw devices. Unplug and reconnect the pad afterward. The app reports
actual connection errors and never treats the pad as connected without a reply.

## Profiles and actions

Create profiles with **+**. Select a key or encoder in the diagram or assignment
list to record a shortcut, build an ordered sequence, or open a file/URL.
Sequences support editable keyboard shortcuts, delays, US-layout ASCII text,
and files/URLs. Keyboard output is sent by the RP2040, including under Wayland.

**Combinations** let a held key or encoder button modify another key or encoder
direction. A combination modifier's standalone action executes on release if
no combination was used. Ordinary shortcuts retain key-down/key-up behavior.

**Run actions** enables host profiles, sequences and combinations. **Save onboard**
saves the current profile's basic keyboard shortcuts to the pad's nonvolatile
storage. App-only actions are unassigned in the onboard profile and the UI reports
this distinction. Losing the app releases output keys and restores onboard mode
after the firmware's three-second capture lease expires.

Profiles autosave atomically to `$XDG_CONFIG_HOME/novakey/profiles.json`, or
`~/.config/novakey/profiles.json`. Profile menu includes rename, duplicate,
delete, import and export. No app accounts or cloud storage are used.

## KDE Plasma 6 / Wayland

Enable **Auto-switch profiles**. Studio loads its own small, session-scoped KWin
script through D-Bus. Focus events flow from KWin to the native Linux runner,
then through a Flutter method channel. No X11 polling or `xdotool` is used.
Disabling integration or closing Studio unloads its script. After an app crash,
the next start replaces its stale script. It does not change global KWin settings.

To add your own apps: enable auto-switch, focus the desired app, return to Studio,
then use **Profile menu → Link application** and pick it from recent applications.
You can also enter a KDE desktop application ID or resource class manually and
unlink later. Matching uses exact normalized application identifiers, not titles
or substring matches. Unlinked applications retain the active profile.

KWin sends desktop IDs and resource classes only; window titles and content are
not collected. Only the KWin D-Bus owner can publish into Studio's focus interface.
Only one Studio instance can own this integration at a time.

## Development

Source is split into models, services, device views, studio UI and action editors.
`tool/generate_layout.py` generates both the hardware SVG and its click bounds.
`tool/kde_diagnostics.dart` is a manual live-session bridge diagnostic:

```sh
flutter run -d linux -t tool/kde_diagnostics.dart
```

Reference: [KWin scripting API](https://develop.kde.org/docs/plasma/kwin/api/).
