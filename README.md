# Pane

<img width="952" height="685" alt="Screenshot 2026-07-02 at 12 09 54 AM" src="https://github.com/user-attachments/assets/e4a2a0c4-e370-4dcb-9553-0f396c6da89f" />

A quiet place for notes. macOS-only, built in SwiftUI.

## Install

Download the latest `Pane-x.y.z.dmg` from the [Releases](../../releases) page, open it, and drag **Pane** to your Applications folder.

# First launch (IMPORTANT): 

Pane isn't notarized through Apple, so macOS will block it the first time with a dialog like *"Pane Not Opened — Apple could not verify..."*. To allow it:

1. Click **Done** to dismiss the dialog.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the **Security** section. You'll see a line about Pane being blocked, with an **Open Anyway** button. Click it.
4. Enter your password or Touch ID if prompted.
5. Launch Pane again from Applications. A final confirmation dialog appears — click **Open**.

After that one ritual, regular double-click works forever.

**Terminal shortcut** (if you're comfortable with the command line):

```
xattr -d com.apple.quarantine /Applications/Pane.app
```

That strips the quarantine flag and Pane opens normally on the first try.

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
