<div align="center">

# 🎉 hypegram

**Send Telegram deploy notifications with a random celebration (or dejection) GIF.**
A hyped-up cousin of [`appleboy/telegram-action`](https://github.com/appleboy/telegram-action) — same drop-in feel, but with animated flair.

[![GitHub release](https://img.shields.io/github/v/tag/0xAI-Builders/hypegram?label=version)](https://github.com/0xAI-Builders/hypegram/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Made by 0xAI-Builders](https://img.shields.io/badge/made%20by-0xAI--Builders-purple)](https://github.com/0xAI-Builders)

**[📖 Full docs on the retro site →](https://0xai-builders.github.io/hypegram/)**

</div>

---

## Why hypegram?

`appleboy/telegram-action` sends plain text. It works. It's boring.

`hypegram` sends a random GIF from a curated pool (or your own) via `sendAnimation`. Every deploy becomes a small dopamine hit. Failures still get notified — with a sad-cat GIF and the failure caption, so the pain is at least aesthetically pleasing.

- ✅ Drop-in — same shape as `appleboy/telegram-action`
- 🎬 Random GIF per run — pool switches based on `status`
- 🎨 Bring your own GIF list, or use the built-in one
- 🪂 Never silent — falls back to `sendMessage` if the GIF download fails
- 🐚 Pure `bash` + `curl` — no Docker, no Node, fastest step in your workflow

## Quick start

```yaml
- name: Notify Telegram on success
  if: success()
  uses: 0xAI-Builders/hypegram@v1
  with:
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
    caption: |
      ✅ Deploy: ${{ github.repository }}
      📝 ${{ github.event.head_commit.message }}
      👤 ${{ github.actor }}

- name: Notify Telegram on failure
  if: failure()
  uses: 0xAI-Builders/hypegram@v1
  with:
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
    status: failure
    caption: |
      ❌ Deploy failed: ${{ github.repository }}
      🔗 https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

## Inputs

| Name      | Required | Default      | Description |
|-----------|----------|--------------|-------------|
| `token`   | ✅ yes   | —            | Telegram bot token from [@BotFather](https://t.me/BotFather). |
| `chat_id` | ✅ yes   | —            | Target chat or user ID. Send `/start` to your bot, then hit `https://api.telegram.org/bot<TOKEN>/getUpdates` to find yours. |
| `status`  | no       | `success`    | `success` or `failure`. Picks the built-in GIF pool that fits the mood. |
| `caption` | no       | *(empty)*    | Multi-line caption sent with the GIF. Plain text — Telegram doesn't render Markdown here. |
| `gifs`    | no       | *(built-in)* | Newline-separated list of GIF URLs. Overrides the built-in pool. |

## Using it across multiple repos

You probably want one bot + one chat notifying every CI you have. The clean way:

### Option A — Org secrets (recommended)

1. Go to `github.com/organizations/<your-org>/settings/secrets/actions`.
2. Create `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` — select **All repositories** (or a subset).
3. In every workflow, reference them as `${{ secrets.TELEGRAM_BOT_TOKEN }}` / `${{ secrets.TELEGRAM_CHAT_ID }}`.

Now the exact same YAML snippet works everywhere without duplicating secrets per repo.

### Option B — Per-repo secrets

For personal or one-off repos: `Repo → Settings → Secrets and variables → Actions → New repository secret`.

## Non-CI use cases

`hypegram` is just an HTTP call wrapped in a composite action — it works anywhere a workflow runs.

**Scheduled cheer (weekly celebration):**

```yaml
on:
  schedule:
    - cron: '0 17 * * 5'   # every Friday at 5pm UTC

jobs:
  cheer:
    runs-on: ubuntu-latest
    steps:
      - uses: 0xAI-Builders/hypegram@v1
        with:
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
          caption: "🎉 It's Friday. Ship something reckless."
```

**Manual dispatch — celebrate arbitrary things:**

```yaml
on:
  workflow_dispatch:
    inputs:
      message:
        description: 'What are we celebrating?'
        required: true

jobs:
  hype:
    runs-on: ubuntu-latest
    steps:
      - uses: 0xAI-Builders/hypegram@v1
        with:
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
          caption: ${{ github.event.inputs.message }}
```

**Release announcement:**

```yaml
on:
  release:
    types: [published]

jobs:
  announce:
    runs-on: ubuntu-latest
    steps:
      - uses: 0xAI-Builders/hypegram@v1
        with:
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
          caption: |
            🚀 New release: ${{ github.event.release.tag_name }}
            ${{ github.event.release.html_url }}
```

## Custom GIF pools

Curate your own vibe:

```yaml
- uses: 0xAI-Builders/hypegram@v1
  with:
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
    caption: "Shipped 🚀"
    gifs: |
      https://media.giphy.com/media/xxx/giphy.gif
      https://media.giphy.com/media/yyy/giphy.gif
      https://cataas.com/cat/gif/says/Ship%20it
```

Any URL that resolves to a GIF (or MP4/MPEG-4) works — Giphy, Tenor, Cataas, your own S3 bucket, whatever.

## How it works

1. Picks a random URL from the pool (custom `gifs` if provided, otherwise the built-in pool matching `status`).
2. Downloads the GIF with `curl` and posts it to Telegram via [`sendAnimation`](https://core.telegram.org/bots/api#sendanimation).
3. If the download fails, falls back to `sendMessage` with the caption as plain text — you always get *something*.

Steps run in ~2 seconds on `ubuntu-latest`. No Docker pull, no Node install.

## FAQ

**Can I use Markdown in the caption?**
`sendAnimation` accepts `parse_mode`, but hypegram doesn't expose it yet — captions are plain text. Open an issue if you want it.

**Can I send video instead of GIF?**
Telegram's `sendAnimation` accepts GIF, MPEG-4 without sound, and short MP4s. Any of those in the `gifs` input will work.

**What runners does it need?**
Anything with `bash` + `curl`. Any `ubuntu-*` image works out of the box. Should also work on macOS runners.

**Does it work on self-hosted runners?**
Yes, as long as the runner can `curl` both `api.telegram.org` and the GIF URLs.

## Contributing

PRs welcome. Ideas that would land cleanly:

- `parse_mode` input (Markdown/HTML rendering)
- `disable_notification` input (silent send)
- `reply_to_message_id` input (threaded replies)
- Per-status caption defaults
- Video/Photo send modes

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

*Made with 🍌 by [0xAI-Builders](https://github.com/0xAI-Builders)*

</div>
