# Changelog

All notable changes to IG Follow Audit. Versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

Groundwork for **snapshot history**: keeping each imported export inside the app, so you can delete the `.zip` afterwards and later see who followed or unfollowed you between exports. Nothing in the app uses this yet.

### Added

- Snapshots: a saved copy of an export's followers and following lists, with the date it was imported and the date the data was taken. The second date starts as a guess (the newest follow date in the export) and can be corrected.
- A snapshot store that keeps one JSON file per snapshot in the app's own Application Support folder. It skips importing the same export twice, and leaves damaged files, or files saved by a newer version of the app, untouched instead of deleting them.

## [1.0.1] - 2026-10-09

A bug-fix release. **If you're on 1.0.0, please update.** 1.0.0 can crash as soon as you scroll a list.

### Fixed

#### The app crashed when scrolling through a list

**What happened:** after importing an Instagram export, scrolling through a list could make the app quit straight away. The crash only showed up with real-sized exports of hundreds or thousands of accounts. The small sample data used during development never triggered it, which is why it shipped in 1.0.0.

The app was stopped by this error:

```
Fatal error: No Observable object of type AppModel found.
A View.environmentObject(_:) for AppModel may be missing as an ancestor of this view.
```

**Why it happened:** the app keeps all its data (the lists, your ticks, the search text) in one shared object called `AppModel`. SwiftUI hands that object down to every view through what it calls the *environment*.

The round "done" button on each row was its own small view, and it fetched `AppModel` from the environment. The account list is drawn by a macOS table (`NSTableView`), which saves memory by *recycling* rows. When a row scrolls off screen, its view is reused for a row scrolling into view instead of being thrown away. Recycled rows don't reliably get SwiftUI's environment again. So once you'd scrolled far enough for rows to be recycled, a done button would look for `AppModel`, find nothing and crash the app. Short lists never recycle rows, so they never crashed.

**The fix:** the done button no longer looks `AppModel` up from the environment. Each row now hands it the model directly when the row is built, so a recycled row always has what it needs. The other parts of a row were already built this way, which is why only the button was affected.

#### A hidden problem that would have become a crash in future macOS versions

**What happened:** while hunting the crash above, a second problem turned up. Each time a long list changed (switching lists, typing a search, or re-sorting after scrolling down), macOS logged this warning:

```
WARNING: Application performed a reentrant operation in its NSTableView delegate.
This warning will become an assert in the future.
```

Nothing visibly broke. But macOS's "will become an assert" means a future version is expected to crash on it instead of just warning.

**Why it happened:** when a list's contents changed, SwiftUI updated the existing table in place. It worked out the difference between thousands of old and new rows and applied it to a table that was already scrolled partway down. In the middle of that update, the table asked for row details again, which triggered a second update while the first was still running. That nested ("reentrant") update is what macOS warns about.

**The fix:** the table is now rebuilt fresh whenever you switch lists, search, or change the sort, instead of being patched in place. A macOS table only creates the rows currently on screen, so this is quick even for thousands of accounts. The only visible change is that searching or re-sorting takes you back to the top of the list. Clicking a column header still sorts as before.

A smaller related fix: switching lists used to clear the row selection even when nothing was selected. That caused a needless extra update. Now it only clears the selection when something is selected.

### Added

- **Scroll stress test** for debug builds. `IGFA_SCROLLTEST=1 IGFA_EXPORT=<export> swift run` loads an export and scrolls every list from top to bottom, ticking rows, searching and re-sorting along the way, then simulates a header click to check that sorting still works. It reproduced both bugs above using a fake export with 4,000 accounts, and it now passes repeatedly with no crashes or warnings.

### How it was verified

- The stress test passed on several runs with a generated 4,000-following / 3,500-follower export: no crashes and no reentrancy warnings.
- All 14 unit tests pass.
- The release build is universal (Apple Silicon and Intel), and its signature checks out after unzipping.
- It has not yet been re-tested against a real Instagram export.

## [1.0.0] - 2026-10-09

First public release.

### Added

- Native, offline macOS app (SwiftUI, macOS 14 or later, universal).
- Reads Instagram's official "Download Your Information" export, as either a `.zip` or an extracted folder. Handles both the older and newer `followers`/`following` JSON layouts, and spots HTML exports.
- Built-in `.zip` reader based on Apple's Compression framework, with no third-party dependencies.
- Lists: **Not Following Back**, **Fans**, **Following** and **Followers**, with counts.
- Search, sort by name or date, tick accounts off as you go (saved between launches) with a progress bar, open profiles, copy usernames, and export any list as CSV.
- App Sandbox with no network permission, so the app can't connect to anything.
- App icon based on Lucide's "user-round-search" glyph (ISC License).
- MIT License.

### Known issues

- Crashes when scrolling long lists. **Fixed in 1.0.1.**
- Deactivated accounts appear in the lists, because Instagram's export still includes them.

[1.0.1]: https://github.com/n1soryu/ig-follow-audit/releases/tag/v1.0.1
[1.0.0]: https://github.com/n1soryu/ig-follow-audit/releases/tag/v1.0.0
