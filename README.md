# ig-follow-audit

Find the Instagram accounts you follow that don't follow you back, using **only Instagram's official "Download Your Information" export**. No scraping, no logging in, no API calls.

The tool reads your exported data and gives you a plain list. You do the unfollowing yourself in the Instagram app, so nothing automated ever touches your account.

## Why

- **Stays within the ToS.** It never logs in to Instagram or automates any actions. It only reads a file you downloaded yourself.
- **Reliable.** Scrapers break every time Instagram changes its site. The data export format rarely changes.
- **Private.** Everything runs locally and your data never leaves your machine.

<p align="center"><img src="Resources/Icon/AppIcon-1024.png" width="128" alt="App icon"></p>

<p align="center">
  <img src="docs/screenshots/welcome-light.png" width="49%" alt="Welcome screen">
  <img src="docs/screenshots/results-light.png" width="49%" alt="Results (sample data)">
</p>

## How it works

1. Request your data from Instagram (see below).
2. Open **IG Follow Audit** and drop the downloaded `.zip` (or the extracted folder) onto the window.
3. It compares `following` with `followers` and lists everyone you follow who doesn't follow you back.

```
following  −  followers  =  people who don't follow you back
```

The app is a native macOS app (SwiftUI), about 600 KB. It runs in the macOS App Sandbox **with no network permission**, so the system itself prevents it from sending anything anywhere.

## Getting your data from Instagram

1. Instagram → **Settings** → **Accounts Center** → **Your information and permissions** → **Download your information**.
2. Choose **Some of your information** and select **Followers and following** only.
3. Pick **Download to device**, set **Format: JSON** and **Date range: All time**.
4. Wait for the email from Instagram (anywhere from minutes to a few hours), then download the `.zip`.

The files we need are in the archive at:

```
connections/followers_and_following/
├── followers_1.json   (can be split into followers_2.json, … for large accounts)
└── following.json
```

## Using the app

- The sidebar has **Not Following Back** (accounts you follow that don't follow you), **Fans** (the reverse), plus everyone you follow and everyone who follows you.
- Search, and sort by username or date (when you followed them, or when they followed you).
- Double-click a row, or click **Open Profile**, to open the profile in your browser. Then unfollow in Instagram yourself.
- Tick the circle next to an account as you deal with it. Progress is shown at the top, and your ticks are remembered between launches.
- Right-click rows to copy usernames or mark several as done. Use **Export CSV** in the toolbar to save the list.

## Building

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not needed.

```bash
./scripts/build-app.sh          # builds "build/IG Follow Audit.app"
open "build/IG Follow Audit.app"
./scripts/test.sh                # runs the tests
```

Drag the `.app` into `/Applications` if you like. It is ad-hoc signed, not notarized, so if macOS refuses to open it the first time, right-click it and choose **Open**.

### Project layout

```
Sources/FollowAuditCore/   export parsing, .zip reading, comparison (no UI)
Sources/IGFollowAudit/     the SwiftUI app
Tests/                     tests; fake exports are generated at runtime
Resources/                 Info.plist and sandbox entitlements
scripts/build-app.sh       packages the .app
scripts/make-icon.swift    regenerates Resources/AppIcon.icns
```

Screenshots use generated sample data, not real accounts. In debug builds, `IGFA_SNAPSHOT=<dir> IGFA_EXPORT=<export> swift run` renders the window to PNGs, which is handy for checking UI changes.

## Project status

- [x] Repository setup
- [x] Parse followers / following from the JSON export (old and new Instagram layouts)
- [x] Compute non-followers-back (and fans)
- [x] Mac app: drag and drop, search, sort, open profiles, Done tracking, CSV export
- [x] Tests with fake export data
- [x] App icon

## Privacy note

Your Instagram export contains personal data. The `.gitignore` excludes `data/`, `*.zip`, and the export JSON files so you don't accidentally commit them. **Keep your exports in `data/`.**

## Credits

App icon glyph: [Lucide](https://lucide.dev) "user-round-search", ISC License (see `Resources/Icon/LUCIDE-LICENSE.txt`).

## License

Private, for personal use.
