# ig-follow-audit

Find the Instagram accounts you follow that don't follow you back, using **only Instagram's official "Download Your Information" export**. No scraping, no logging in, no API calls.

The tool reads your exported data and gives you a plain list. You do the unfollowing yourself in the Instagram app, so nothing automated ever touches your account.

## Why

- **Stays within the ToS.** It never logs in to Instagram or automates any actions. It only reads a file you downloaded yourself.
- **Reliable.** Scrapers break every time Instagram changes its site. The data export format rarely changes.
- **Private.** Everything runs locally and your data never leaves your machine.

## How it works

1. Request your data from Instagram (see below).
2. Point the tool at the downloaded `.zip` (or the extracted folder).
3. It compares `following` with `followers` and prints everyone you follow who doesn't follow you back.

```
following  −  followers  =  people who don't follow you back
```

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

## Usage

> 🚧 Work in progress, coming soon.

```bash
python3 -m ig_follow_audit path/to/instagram-export.zip
```

## Project status

- [x] Repository setup
- [ ] Parse followers / following from the JSON export
- [ ] Compute non-followers-back
- [ ] CLI output (plain list + optional CSV / clickable profile links)
- [ ] Tests with sample (fake) export data

## Privacy note

Your Instagram export contains personal data. The `.gitignore` excludes `data/`, `*.zip`, and the export JSON files so you don't accidentally commit them. **Keep your exports in `data/`.**

## License

Private, for personal use.
