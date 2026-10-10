<p align="center">
  <img src="Resources/Icon/AppIcon-1024.png" width="128" alt="IG Follow Audit icon">
</p>

<h1 align="center">IG Follow Audit</h1>

<p align="center">
  A small, offline Mac app that shows which Instagram accounts you follow don't follow you back,<br>
  using only the data export Instagram gives you.
</p>

> [!WARNING]
> **This entire project was vibecoded.**
> Every line of code, the tests, the icon and this README were written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from plain-English prompts. The repository owner directed the work but did not write or review the code line by line.
>
> In practice that means:
> - The owner has tested it on their own real Instagram export, and it worked as expected. It hasn't had any wider testing beyond that.
> - There may be bugs nobody has noticed. Double-check before unfollowing anyone important.
> - It comes with **no warranty or support**. Use it at your own risk.
>
> See [How this was made](#how-this-was-made) for details.

<p align="center">
  <img src="docs/screenshots/welcome-light.png" width="49%" alt="Welcome screen">
  <img src="docs/screenshots/results-light.png" width="49%" alt="Results screen with sample data">
</p>
<p align="center"><sub>Screenshots use made-up sample accounts.</sub></p>

## What it does

You request your data from Instagram, drop the `.zip` onto the app, and it compares the people you follow with the people who follow you:

```
following  −  followers  =  people who don't follow you back
```

- **Not Following Back:** accounts you follow that don't follow you.
- **Fans:** accounts that follow you that you don't follow back.
- **Following / Followers:** the full lists.
- **History:** every export you import is saved as a snapshot inside the app, so you can delete the `.zip` afterwards. Import a new export every few weeks and the **Overview** shows who followed and unfollowed you since last time, who came back, who left soon after following, and a chart of your followers over time.
- Search, sort by name or date, and tick accounts off as you go. Progress is saved between launches.
- Open a profile in your browser, copy usernames, or export any list as CSV.

The app **never logs in to Instagram and never unfollows anyone**. It only shows you a list. You do any unfollowing yourself in the Instagram app.

> [!NOTE]
> **Deactivated accounts show up too.** Instagram's export still lists accounts that have been deactivated, so the app shows them like any other account. They usually land in **Not Following Back**, because a deactivated account can't follow you. The export doesn't say which accounts are deactivated, and the app is offline, so it can't tell them apart. If **Open** takes you to Instagram's "Sorry, this page isn't available" page, the account is probably deactivated or deleted.

## Privacy

- **No network access.** The app runs in the macOS App Sandbox without the network permission, so macOS itself blocks it from connecting to anything.
- **Only the files you pick.** It can read only the export you drop or choose, and write only where you save a CSV or backup.
- **Nothing is uploaded or collected.** The app stores your snapshots (the follower and following lists from each export you import) and the usernames you've ticked off. They're kept as JSON files in the app's own sandbox folder, `~/Library/Containers/<bundle id>/Data/Library/Application Support/IG Follow Audit/`, and never leave your Mac. **Snapshots → Show in Finder** opens that folder, and **Delete All Data…** removes everything.
- **Back it up yourself.** Once you've deleted the export `.zip` files, the app has the only copy of your history. Use **File → Back Up History…** (⇧⌘S) to save it all to one file, and **Restore History…** to bring it back on a new Mac. Restoring adds to what's already there and skips snapshots it already has.

Your export contains personal data, so keep it out of git. The `.gitignore` already excludes `data/`, `*.zip` and the export's JSON files. Keeping exports in `data/` is the safest option.

## Getting your Instagram export

1. In Instagram, go to **Settings → Accounts Center → Your information and permissions → Download your information**.
2. Choose **Some of your information** and select only **Followers and following**.
3. Pick **Download to device**, with **Format: JSON** and **Date range: All time**.
4. Wait for Instagram's email (anywhere from minutes to a few hours), then download the `.zip`.

The app reads these files from the archive:

```
connections/followers_and_following/
├── followers_1.json   (large accounts get followers_2.json, … too)
└── following.json
```

If you picked **HTML** instead of JSON, the app will tell you. Request the export again in JSON.

## Install

### Download (easiest)

1. Download `IG-Follow-Audit-<version>.zip` from the [latest release](https://github.com/n1soryu/ig-follow-audit/releases/latest).
2. Unzip it and drag **IG Follow Audit** into your **Applications** folder.
3. Open it. The first time, macOS will block it (see below).

Requires macOS 14 or later. It runs natively on both Apple Silicon and Intel Macs. See the [changelog](CHANGELOG.md) for what changed in each version.

**First launch:** the app isn't notarized by Apple (that needs a paid developer account), so macOS says it can't verify the app. To open it anyway:

- Open **System Settings → Privacy & Security**, scroll down to the message about IG Follow Audit, and click **Open Anyway**. You only have to do this once.
- Or, in Terminal: `xattr -dr com.apple.quarantine "/Applications/IG Follow Audit.app"`

Only do this if you trust the download. The full source code is in this repo, so you can always build it yourself instead.

### Build from source

You need macOS 14 or later and the Xcode Command Line Tools (full Xcode isn't needed):

```bash
xcode-select --install
git clone https://github.com/n1soryu/ig-follow-audit.git
cd ig-follow-audit
./scripts/build-app.sh
open "build/IG Follow Audit.app"
```

This builds a universal app, about 2 MB, at `build/IG Follow Audit.app`. Apps you build yourself aren't flagged as downloaded, so they open without the Gatekeeper prompt.

## Using the app

1. Drop your export `.zip` (or the folder you extracted it to) onto the window, or click **Choose File…** (⌘O). The app saves it as a snapshot. You can delete the `.zip` afterwards.
2. **Overview** shows your counts, what changed since the previous snapshot, and your follower growth. Each number links to its list.
3. Pick a list in the sidebar. Click **Open** (or double-click a row) to open the profile in your browser, then deal with it in Instagram.
4. Click the circle next to an account to mark it done. Right-click selected rows to copy usernames or mark several at once.
5. Use **Export CSV** in the toolbar to save the current list.
6. A few weeks later, request a new export and import it the same way (**File → How to Get an Export…** has the steps). The app reminds you once your latest export is a month old.
7. **Snapshots** lists every import. If the app guessed an export's date wrong, click the date to fix it. The menu at the bottom of the sidebar switches to an older snapshot.

## How it works

- **Parsing:** Instagram has changed the export's layout over time. Older files put the username in `value`. Newer `following.json` files put it in `title`, with links like `instagram.com/_u/name`. The parser handles both and falls back to the profile link. Usernames are compared case-insensitively.
- **Reading the `.zip`:** a small built-in reader using Apple's Compression framework. No third-party dependencies, and no need to extract the archive first.
- **Comparison:** set difference in both directions, de-duplicated. Order follows the export.
- **Snapshots:** one JSON file per import, named by ID. Each records when it was imported and when the data was taken. The second is a guess: the date in Instagram's file name (`instagram-name-YYYY-MM-DD-…`), else the file's creation date, never earlier than the newest follow in the data. Importing the same export twice is detected by a fingerprint of its contents.

## Development

```
Sources/FollowAuditCore/   export parsing, .zip reading, comparison, snapshots and history (no UI)
Sources/IGFollowAudit/     the SwiftUI app
Tests/                     tests; fake exports are generated at runtime
Resources/                 Info.plist, sandbox entitlements, app icon
docs/screenshots/          README screenshots (sample data)
scripts/build-app.sh       builds and signs the universal .app
scripts/package-release.sh zips the .app for a GitHub release
scripts/test.sh            runs the tests
scripts/make-icon.swift    regenerates Resources/AppIcon.icns
```

```bash
./scripts/test.sh   # 42 tests
swift run           # debug build, no sandbox (saves to ~/Library/Application Support/IG Follow Audit)
```

Quirks of building with only the Command Line Tools:

- **Use `./scripts/test.sh`, not plain `swift test`.** Plain `swift test` sometimes can't find the Swift Testing plugin. The script passes its path explicitly.
- **There's no `@State` in the views.** On current SDKs, SwiftUI's `@State` is a macro whose plugin only ships with full Xcode, so view state lives in the `@Observable` `AppModel` instead.

**UI snapshots:** debug builds can render the window to PNGs (light and dark) without Screen Recording permission. The screenshots above were made this way:

```bash
IGFA_SNAPSHOT=/tmp/shots IGFA_EXPORT=/path/to/sample-export swift run
```

`IGFA_EXPORT` can list several exports separated by `:`, imported in order, to fill the history and the growth chart. `IGFA_WINDOW=1000x1400` renders at a custom size. These runs use a throwaway data folder, never your saved history. Set `IGFA_DATA_DIR` to point any debug run at a folder of your choice.

**Scroll stress test:** debug builds can also load an export and scroll every list top to bottom, searching, sorting and ticking rows along the way. Use a large export, since problems only show up with thousands of rows:

```bash
IGFA_SCROLLTEST=1 IGFA_EXPORT=/path/to/export.zip swift run
```

## Known limitations

- Deactivated accounts can't be detected or filtered out (see the note under [What it does](#what-it-does)).
- The export only identifies accounts by username, so someone who renames their account between two exports shows up as one account unfollowing you and a new one following you.
- Snapshot history is new and has only been tested with sample data.
- Tested on one person's real export, on one Mac.
- macOS only.
- If Instagram changes the export format again, parsing may break.
- Not notarized, so downloaded copies need **Open Anyway** on first launch.

## How this was made

This project was built in a few conversational sessions with [Claude Code](https://claude.com/claude-code), Anthropic's AI coding assistant. The owner described what they wanted: an offline Mac app based only on the official export, then a nicer UI and an icon. The AI planned it, wrote and tested the code, designed the UI and icon, wrote the docs and made the commits. Commits carry a `Co-Authored-By: Claude` trailer.

What was actually checked:

- The automated tests pass. They use generated fake exports in both Instagram layouts, plus zip and folder variants and error cases.
- The app builds, launches, and runs sandboxed.
- The UI was checked using rendered screenshots of sample data.
- The owner ran it on their own real Instagram export, and the results were correct. That's also how we learned that deactivated accounts appear in the lists.

What was **not** done: a human code review, or testing with other people's exports, on other Macs or on other macOS versions. Treat it accordingly.

## Credits

- App icon glyph: [Lucide](https://lucide.dev) "user-round-search", ISC License (see [`Resources/Icon/LUCIDE-LICENSE.txt`](Resources/Icon/LUCIDE-LICENSE.txt)).
- Not affiliated with, endorsed by, or connected to Instagram or Meta. "Instagram" is a trademark of Meta Platforms, Inc.

## License

[MIT](LICENSE) © 2026 Niso Ryu. The Lucide icon glyph is under its own ISC License, which is also permissive.
