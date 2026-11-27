#!/usr/bin/env bash
# Lógica de la action (antes inline en action.yml). Lee todo de las env HYPEGRAM_*.
set -e

DEFAULT_SUCCESS=(
  "https://cataas.com/cat/gif/says/Deployed!"
  "https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif"
  "https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif"
  "https://media.giphy.com/media/26u4cqiYI30juCOGY/giphy.gif"
  "https://media.giphy.com/media/3oz8xAFtqoOUUrsh7W/giphy.gif"
  "https://media.giphy.com/media/l0HlBO7eyXzSZkJri/giphy.gif"
  "https://media.giphy.com/media/26BRBKqUiq586bRVm/giphy.gif"
  "https://media.giphy.com/media/YTbZzCkRQCEJa/giphy.gif"
  "https://media.giphy.com/media/d86kftzaeizO8/giphy.gif"
  "https://media.giphy.com/media/l46CyJmS9KUbokzsI/giphy.gif"
)

DEFAULT_FAILURE=(
  "https://cataas.com/cat/gif/says/Failed"
  "https://media.giphy.com/media/l1J9EdzfOSgfyueLm/giphy.gif"
  "https://media.giphy.com/media/26xBI73gWquCBBCDe/giphy.gif"
  "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif"
  "https://media.giphy.com/media/xT9IgIc0lryrxvqVGM/giphy.gif"
  "https://media.giphy.com/media/9Y5BbDSkSTiY8/giphy.gif"
)

POOL=()
if [ -n "$HYPEGRAM_GIFS" ]; then
  while IFS= read -r line; do
    trimmed="${line//$'\r'/}"
    trimmed="$(echo -n "$trimmed" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$trimmed" ] && POOL+=("$trimmed")
  done <<< "$HYPEGRAM_GIFS"
elif [ "$HYPEGRAM_STATUS" = "failure" ]; then
  POOL=("${DEFAULT_FAILURE[@]}")
else
  POOL=("${DEFAULT_SUCCESS[@]}")
fi

if [ ${#POOL[@]} -eq 0 ]; then
  echo "::error::hypegram: GIF pool is empty."
  exit 1
fi

RANDOM_GIF="${POOL[$RANDOM % ${#POOL[@]}]}"
echo "hypegram: selected GIF -> $RANDOM_GIF"

API="https://api.telegram.org/bot${HYPEGRAM_TOKEN}"

# Un aviso que no salió no tumba el workflow (el deploy ya pasó): por defecto
# se deja un warning y se sale con 0. Con fail_on_error=true, el step falla.
fail() {
  if [ "${HYPEGRAM_FAIL_ON_ERROR:-false}" = "true" ]; then
    echo "::error::$1"
    exit 1
  fi
  echo "::warning::$1"
  exit 0
}
PARSE_MODE="${HYPEGRAM_PARSE_MODE:-}"

# Telegram cap: max 1024 chars en el caption de sendAnimation. Recortamos con …
# — mejor una notificación cortita que un error del step.
truncate_caption() {
  local text="$1"
  if [ ${#text} -gt 1024 ]; then text="${text:0:1020}…"; fi
  printf '%s' "$text"
}

# Texto plano a partir de HTML: sin etiquetas y con las entidades básicas de
# vuelta. Es el reintento cuando Telegram rechaza el formato (caption largo o
# HTML mal cerrado): mejor sin negritas que sin aviso.
html_to_plain() {
  printf '%s' "$1" | sed -e 's/<[^>]*>//g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g'
}

# --form-string y no -F: con -F, un caption que empieza con < o @ curl lo
# toma como archivo a leer («<b>Deploy</b>» buscaba el archivo «b>Deploy…»).
send_animation() {
  local caption="$1" mode="$2"
  local args=( -sS -X POST "${API}/sendAnimation" -F "chat_id=${HYPEGRAM_CHAT_ID}" -F "animation=@${TMP_GIF}" --form-string "caption=${caption}" )
  [ -n "$mode" ] && args+=( --form-string "parse_mode=${mode}" )
  curl "${args[@]}"
}

TMP_GIF="$(mktemp --suffix=.gif)"
if ! curl -sfL "$RANDOM_GIF" -o "$TMP_GIF"; then
  echo "::warning::hypegram: could not download $RANDOM_GIF, falling back to sendMessage."
  FALLBACK_TEXT="${HYPEGRAM_CAPTION:-Deploy notification for ${HYPEGRAM_REPO}}"
  args=( -sS -X POST "${API}/sendMessage" --data-urlencode "chat_id=${HYPEGRAM_CHAT_ID}" --data-urlencode "text=${FALLBACK_TEXT}" )
  [ -n "$PARSE_MODE" ] && args+=( --data-urlencode "parse_mode=${PARSE_MODE}" )
  RESPONSE="$(curl "${args[@]}")"
  # Antes salía con 0 aunque Telegram rechazara el mensaje.
  if ! echo "$RESPONSE" | grep -q '"ok":true'; then
    fail "hypegram: Telegram API returned an error: $RESPONSE"
  fi
  echo "hypegram: sent (text fallback)."
  exit 0
fi

if [ -n "$PARSE_MODE" ]; then
  # Con formato no se recorta antes: el tope es sobre el texto visible y
  # cortar el crudo puede partir una etiqueta.
  RESPONSE="$(send_animation "$HYPEGRAM_CAPTION" "$PARSE_MODE")"
  if ! echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "::warning::hypegram: Telegram rejected the ${PARSE_MODE} caption ($RESPONSE), retrying as plain text."
    RESPONSE="$(send_animation "$(truncate_caption "$(html_to_plain "$HYPEGRAM_CAPTION")")" '')"
  fi
else
  RESPONSE="$(send_animation "$(truncate_caption "$HYPEGRAM_CAPTION")" '')"
fi

rm -f "$TMP_GIF"

if ! echo "$RESPONSE" | grep -q '"ok":true'; then
  fail "hypegram: Telegram API returned an error: $RESPONSE"
fi

echo "hypegram: sent successfully."
