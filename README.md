# hypegram

Send a Telegram notification with a random celebration (or dejection) GIF from your GitHub Actions workflow. A hyped-up cousin of [`appleboy/telegram-action`](https://github.com/appleboy/telegram-action) — same drop-in feel, but with animated flair.

## Usage

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

| Name      | Required | Default     | Description |
|-----------|----------|-------------|-------------|
| `token`   | yes      | —           | Telegram bot token from [@BotFather](https://t.me/BotFather). |
| `chat_id` | yes      | —           | Target chat or user ID. |
| `status`  | no       | `success`   | `success` or `failure`. Selects the default GIF pool when `gifs` is not provided. |
| `caption` | no       | *(empty)*   | Caption sent with the GIF. Plain text. |
| `gifs`    | no       | *(built-in)* | Newline-separated list of GIF URLs. Overrides the default pool. |

## Custom GIF pool

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

## How it works

1. Picks a random URL from the pool (custom `gifs` if provided, otherwise the built-in pool matching `status`).
2. Downloads the GIF and posts it to Telegram via [`sendAnimation`](https://core.telegram.org/bots/api#sendanimation).
3. If the download fails, falls back to `sendMessage` with the caption as plain text — the notification always goes through.

## Requirements

- Runner with `bash` and `curl` (any `ubuntu-*` image works out of the box).

## License

MIT — see [LICENSE](LICENSE).
