#!/usr/bin/env bash
# Tests de hypegram.sh con un `curl` falso en el PATH. Sin deps: bash puro.
# Cada llamada a curl se guarda en $CALLS/<n>/<k> (un archivo por argumento,
# porque el caption trae saltos de línea).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../hypegram.sh"
export LANG=C.UTF-8 LC_ALL=C.UTF-8
fails=0; total=0

setup() {
	WORK="$(mktemp -d)"; export CALLS="$WORK/calls"; mkdir -p "$CALLS" "$WORK/bin"
	export FAKE_DOWNLOAD=ok FAKE_RESPONSES='{"ok":true}'
	cat > "$WORK/bin/curl" <<'FAKE'
#!/usr/bin/env bash
n=$(ls "$CALLS" | wc -l); d="$CALLS/$n"; mkdir -p "$d"; k=0
for a in "$@"; do printf '%s' "$a" > "$d/$k"; k=$((k+1)); done
# Descarga del GIF: curl -sfL <url> -o <file>
if [ "$1" = "-sfL" ]; then
	[ "$FAKE_DOWNLOAD" = ok ] || exit 22
	: > "$4"; exit 0
fi
# Llamadas al API: responde en orden lo que diga FAKE_RESPONSES (separado por |).
api=$(ls "$CALLS" | wc -l); api=$((api-1))
IFS='|' read -ra R <<< "$FAKE_RESPONSES"
idx=$(( api - 1 )); [ $idx -ge ${#R[@]} ] && idx=$(( ${#R[@]} - 1 ))
printf '%s' "${R[$idx]}"
FAKE
	chmod +x "$WORK/bin/curl"
	export PATH="$WORK/bin:$PATH"
	export HYPEGRAM_TOKEN=T HYPEGRAM_CHAT_ID=42 HYPEGRAM_STATUS=success HYPEGRAM_CAPTION='' HYPEGRAM_GIFS='https://x/a.gif' HYPEGRAM_REPO=o/r HYPEGRAM_PARSE_MODE='' HYPEGRAM_FAIL_ON_ERROR=''
}

# Valor del campo de formulario <name> en la llamada <n> (busca "name=..." en cualquier arg).
field() { local d="$CALLS/$1" f; for f in $(ls "$d" | sort -n); do case "$(cat "$d/$f")" in "$2="*) cat "$d/$f" | sed "1s/^$2=//"; return 0;; esac; done; return 1; }
# Flag que precede al campo <name> en la llamada <n> (-F, --form-string, --data-urlencode).
flag_of() { local d="$CALLS/$1" f prev=''; for f in $(ls "$d" | sort -n); do case "$(cat "$d/$f")" in "$2="*) echo "$prev"; return 0;; esac; prev="$(cat "$d/$f")"; done; return 1; }
url_of() { local d="$CALLS/$1" f; for f in $(ls "$d" | sort -n); do case "$(cat "$d/$f")" in https://api.telegram.org/*) cat "$d/$f"; return 0;; esac; done; }
ncalls() { ls "$CALLS" | wc -l; }

check() { total=$((total+1)); if eval "$2"; then echo "ok - $1"; else echo "not ok - $1"; fails=$((fails+1)); fi; }
run() { bash "$SCRIPT" > "$WORK/out" 2>&1; echo $? > "$WORK/code"; }
code() { cat "$WORK/code"; }

# ── Lo que ya hacía ─────────────────────────────────────────────────────────
setup; HYPEGRAM_CAPTION=$'✅ Deploy\nlinea 2'; run
check 'manda sendAnimation con el caption' '[[ "$(url_of 1)" == *sendAnimation ]] && [ "$(field 1 caption)" = "$HYPEGRAM_CAPTION" ] && [ "$(code)" = 0 ]'

setup; HYPEGRAM_CAPTION="$(printf 'x%.0s' {1..1500})"; run
check 'sin parse_mode, un caption largo se recorta a 1020 + …' '[ "$(field 1 caption)" = "$(printf "x%.0s" {1..1020})…" ]'

setup; FAKE_DOWNLOAD=fail; HYPEGRAM_CAPTION='hola'; run
check 'si el GIF no baja, cae a sendMessage con el texto' '[[ "$(url_of 1)" == *sendMessage ]] && [ "$(field 1 text)" = hola ] && [ "$(code)" = 0 ]'

setup; FAKE_RESPONSES='{"ok":false,"description":"boom"}'; HYPEGRAM_CAPTION='hola'; HYPEGRAM_FAIL_ON_ERROR=true; run
check 'con fail_on_error=true, si Telegram rechaza, el step falla' '[ "$(code)" = 1 ]'

# ── Lo nuevo ────────────────────────────────────────────────────────────────
setup; HYPEGRAM_CAPTION='<b>Deploy</b> listo'; run
check 'un caption que empieza con < se manda literal (curl -F lo leía como archivo)' '[ "$(flag_of 1 caption)" = "--form-string" ] && [ "$(field 1 caption)" = "<b>Deploy</b> listo" ]'

setup; HYPEGRAM_CAPTION='@todos deploy'; run
check 'un caption que empieza con @ se manda literal' '[ "$(flag_of 1 caption)" = "--form-string" ] && [ "$(field 1 caption)" = "@todos deploy" ]'

setup; HYPEGRAM_PARSE_MODE=HTML; HYPEGRAM_CAPTION='<b>ok</b>'; run
check 'parse_mode=HTML viaja a sendAnimation' '[ "$(field 1 parse_mode)" = HTML ]'

setup; HYPEGRAM_CAPTION='hola'; run
check 'sin parse_mode no se manda el campo' '! field 1 parse_mode >/dev/null'

setup; FAKE_DOWNLOAD=fail; HYPEGRAM_PARSE_MODE=HTML; HYPEGRAM_CAPTION='<b>ok</b>'; run
check 'el respaldo sendMessage también respeta parse_mode' '[ "$(field 1 parse_mode)" = HTML ] && [ "$(field 1 text)" = "<b>ok</b>" ]'

setup; HYPEGRAM_PARSE_MODE=HTML; HYPEGRAM_CAPTION="<b>titulo</b> $(printf 'y%.0s' {1..1100})"; run
check 'con parse_mode no se recorta antes (cortaría una etiqueta)' '[ "$(field 1 caption)" = "$HYPEGRAM_CAPTION" ]'

setup; FAKE_RESPONSES='{"ok":false,"description":"Bad Request: message caption is too long"}|{"ok":true}'
HYPEGRAM_PARSE_MODE=HTML; HYPEGRAM_CAPTION="<b>a &amp; b</b> $(printf 'z%.0s' {1..1100})"; run
plain="a & b $(printf 'z%.0s' {1..1100})"
check 'si Telegram rechaza el formato, reintenta en texto plano: sin etiquetas, recortado' \
	'[ "$(ncalls)" = 3 ] && [[ "$(url_of 2)" == *sendAnimation ]] && ! field 2 parse_mode >/dev/null && [ "$(field 2 caption)" = "${plain:0:1020}…" ] && [ "$(code)" = 0 ]'

setup; FAKE_RESPONSES='{"ok":false}|{"ok":false}'; HYPEGRAM_PARSE_MODE=HTML; HYPEGRAM_CAPTION='<b>x</b>'; HYPEGRAM_FAIL_ON_ERROR=true; run
check 'con fail_on_error=true, si también falla en plano, el step falla' '[ "$(code)" = 1 ]'

# ── fail_on_error (v1.2.0) ──────────────────────────────────────────────────
# Un aviso que no salió no debería tumbar el deploy que ya salió bien. Por
# defecto: warning y exit 0, sin tener que poner continue-on-error.
setup; FAKE_RESPONSES='{"ok":false,"description":"Forbidden: bot was blocked"}'; HYPEGRAM_CAPTION='hola'; run
check 'por defecto, si Telegram rechaza, el step no falla y deja un warning' '[ "$(code)" = 0 ] && grep -q "::warning::hypegram: Telegram API returned an error" "$WORK/out"'

setup; FAKE_RESPONSES='{"ok":false}'; HYPEGRAM_CAPTION='hola'; HYPEGRAM_FAIL_ON_ERROR=false; run
check 'con fail_on_error=false explícito, tampoco falla' '[ "$(code)" = 0 ]'

# El respaldo sendMessage antes salía con 0 aunque Telegram lo rechazara.
setup; FAKE_DOWNLOAD=fail; FAKE_RESPONSES='{"ok":false,"description":"chat not found"}'; HYPEGRAM_CAPTION='hola'; HYPEGRAM_FAIL_ON_ERROR=true; run
check 'con fail_on_error=true, si el respaldo sendMessage es rechazado, el step falla' '[ "$(code)" = 1 ] && grep -q "chat not found" "$WORK/out"'

setup; FAKE_DOWNLOAD=fail; FAKE_RESPONSES='{"ok":false,"description":"chat not found"}'; HYPEGRAM_CAPTION='hola'; run
check 'por defecto, si el respaldo sendMessage es rechazado, warning y exit 0' '[ "$(code)" = 0 ] && grep -q "::warning::.*chat not found" "$WORK/out"'

echo "# $((total-fails))/$total"
[ $fails -eq 0 ]
