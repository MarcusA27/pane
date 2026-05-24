# Pane

A quiet place for notes. macOS-only, built in SwiftUI.

## Install

Download the latest `Pane-x.y.z.dmg` from the [Releases](../../releases) page, open it, and drag **Pane** to your Applications folder.

**First launch:** Pane isn't notarized through Apple, so macOS will refuse to open it on a normal double-click. Instead:

1. Open Applications in Finder.
2. **Right-click** Pane and choose **Open**.
3. Click **Open** in the dialog.

After that, regular double-click works.

Requires macOS 14 (Sonoma) or later. Universal binary — runs on Apple Silicon and Intel.

## Build from source

```
git clone <this repo>
cd <repo>
./run.sh
```

Requires Xcode 15+ command line tools and Swift 5.9+.

To produce a release DMG:

```
./release.sh
# output in dist/
```

## Data

Notes live in `~/Library/Application Support/LiquidGlassNotes/notes.json`. Back that up if you care about it.
