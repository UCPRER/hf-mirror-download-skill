#!/usr/bin/env bash
set -u

ENDPOINT="${ENDPOINT:-https://hf-mirror.com}"
REPO_TYPE="${REPO_TYPE:-model}"
REVISION="${REVISION:-main}"
CACHE_DIR="${HF_HUB_CACHE:-}"
TOKEN="${HF_TOKEN:-}"
LOCAL_DIR=""
LOCAL_DIR_SET=0
MAX_TRIES="${MAX_TRIES:-20}"
TRY_TIMEOUT="${TRY_TIMEOUT:-30m}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"
USE_PROXY="${USE_PROXY:-0}"
PROXY_URL="${PROXY_URL:-http://127.0.0.1:9890}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
WGET_VERBOSE="${WGET_VERBOSE:-0}"
WGET_PROGRESS="${WGET_PROGRESS:-1}"
DRY_RUN=0
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()
tmp_dir=""

cleanup() {
  [ -n "$tmp_dir" ] && rm -rf "$tmp_dir"
}

interrupt() {
  echo
  echo "Interrupted."
  exit 130
}

trap cleanup EXIT
trap interrupt INT TERM

usage() {
  cat <<'EOF'
Usage:
  hf_mirror_download.sh [options] <repo_id>

Examples:
  scripts/hf_mirror_download.sh google/flan-t5-base
  scripts/hf_mirror_download.sh google/flan-t5-base --local-dir ./flan-t5-base
  scripts/hf_mirror_download.sh Qwen/Qwen2.5-0.5B --include '*.safetensors' --include '*.json'

Options:
  --local-dir DIR        Save to a normal directory. If omitted, save to HF cache.
  --cache-dir DIR        Hugging Face hub cache dir. Default: HF_HUB_CACHE or HF_HOME/hub.
  --revision REV         Branch/tag/commit. Default: main.
  --repo-type TYPE       model, dataset, or space. Default: model.
  --endpoint URL         Hub endpoint. Default: https://hf-mirror.com.
  --token TOKEN          Hugging Face token. Default: HF_TOKEN.
  --include GLOB         Include glob pattern. Can be repeated.
  --exclude GLOB         Exclude glob pattern. Can be repeated.
  --max-tries N          Retry count per file. Default: 20.
  --try-timeout DURATION Timeout per attempt. Default: 30m.
  --sleep SECONDS        Sleep between retries. Default: 10.
  --proxy URL            Use proxy URL for wget.
  --no-proxy             Do not use proxy. Default.
  --dry-run              List selected files without downloading.
  -h, --help             Show this help.

Notes:
  This script uses wget --continue for resume. It keeps no persistent helper logs,
  no .ok markers, and no .hfd/.hf-curl-download directory.
  Set WGET_PROGRESS=0 to hide wget progress, or WGET_VERBOSE=1 to debug wget.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_value() {
  [ "$#" -ge 2 ] || die "$1 requires a value"
}

REPO_ID=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --local-dir) need_value "$@"; LOCAL_DIR="$2"; LOCAL_DIR_SET=1; shift 2 ;;
    --cache-dir) need_value "$@"; CACHE_DIR="$2"; shift 2 ;;
    --revision) need_value "$@"; REVISION="$2"; shift 2 ;;
    --repo-type) need_value "$@"; REPO_TYPE="$2"; shift 2 ;;
    --endpoint) need_value "$@"; ENDPOINT="$2"; shift 2 ;;
    --token) need_value "$@"; TOKEN="$2"; shift 2 ;;
    --include) need_value "$@"; INCLUDE_PATTERNS+=("$2"); shift 2 ;;
    --exclude) need_value "$@"; EXCLUDE_PATTERNS+=("$2"); shift 2 ;;
    --max-tries) need_value "$@"; MAX_TRIES="$2"; shift 2 ;;
    --try-timeout) need_value "$@"; TRY_TIMEOUT="$2"; shift 2 ;;
    --sleep) need_value "$@"; SLEEP_SECONDS="$2"; shift 2 ;;
    --proxy) need_value "$@"; PROXY_URL="$2"; USE_PROXY=1; shift 2 ;;
    --no-proxy) USE_PROXY=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$REPO_ID" ] || die "unexpected positional argument: $1"
      REPO_ID="$1"
      shift
      ;;
  esac
done

[ -n "$REPO_ID" ] || { usage; exit 2; }
command -v wget >/dev/null 2>&1 || die "wget not found"
command -v timeout >/dev/null 2>&1 || die "timeout not found"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || die "$PYTHON_BIN not found"

case "$REPO_TYPE" in
  model) api_prefix="/api/models"; download_prefix=""; cache_prefix="models" ;;
  dataset) api_prefix="/api/datasets"; download_prefix="/datasets"; cache_prefix="datasets" ;;
  space) api_prefix="/api/spaces"; download_prefix="/spaces"; cache_prefix="spaces" ;;
  *) die "--repo-type must be model, dataset, or space" ;;
esac

urlenc_path() {
  "$PYTHON_BIN" -c 'import sys, urllib.parse; print("/".join(urllib.parse.quote(x, safe="") for x in sys.argv[1].split("/")))' "$1"
}

urlenc_part() {
  "$PYTHON_BIN" -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

matches_any() {
  local value="$1" pattern
  shift
  for pattern in "$@"; do
    [[ "$value" == $pattern ]] && return 0
  done
  return 1
}

should_download() {
  local file="$1"
  if [ "${#INCLUDE_PATTERNS[@]}" -gt 0 ]; then
    matches_any "$file" "${INCLUDE_PATTERNS[@]}" || return 1
  fi
  if [ "${#EXCLUDE_PATTERNS[@]}" -gt 0 ]; then
    matches_any "$file" "${EXCLUDE_PATTERNS[@]}" && return 1
  fi
  return 0
}

endpoint="${ENDPOINT%/}"
repo_path="$(urlenc_path "$REPO_ID")"
revision_path="$(urlenc_part "$REVISION")"
api_url="$endpoint$api_prefix/$repo_path/revision/$revision_path"
tmp_dir="$(mktemp -d)"

headers=()
[ -n "$TOKEN" ] && headers+=(--header="Authorization: Bearer $TOKEN")

proxy_args=(--no-hsts)
if [ "$USE_PROXY" = "0" ]; then
  proxy_args+=(-e use_proxy=no)
else
  proxy_args+=(-e use_proxy=yes -e "http_proxy=$PROXY_URL" -e "https_proxy=$PROXY_URL")
fi

wget_download_log_args=()
if [ "$WGET_VERBOSE" = "1" ]; then
  :
elif [ "$WGET_PROGRESS" = "1" ]; then
  wget_download_log_args+=(--quiet --show-progress --progress=bar:force)
else
  wget_download_log_args+=(--quiet)
fi

echo "Fetching file list: $api_url"
timeout --foreground "$TRY_TIMEOUT" wget "${proxy_args[@]}" "${headers[@]}" \
  --tries=5 --waitretry="$SLEEP_SECONDS" --connect-timeout=30 --read-timeout=120 \
  --quiet --output-document="$tmp_dir/repo.json" "$api_url" || die "failed to fetch repo metadata"

"$PYTHON_BIN" - "$tmp_dir/repo.json" "$tmp_dir/files.txt" > "$tmp_dir/commit.txt" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

sha = data.get("sha")
files = [x.get("rfilename") for x in data.get("siblings", []) if x.get("rfilename")]
if not sha or "siblings" not in data:
    raise SystemExit(data.get("error") or data.get("message") or "bad API response")

with open(sys.argv[2], "w", encoding="utf-8") as f:
    for name in files:
        f.write(name + "\n")
print(sha)
PY

commit_hash="$(cat "$tmp_dir/commit.txt")"
selected="$tmp_dir/selected.txt"
: > "$selected"
while IFS= read -r file; do
  should_download "$file" && printf "%s\n" "$file" >> "$selected"
done < "$tmp_dir/files.txt"

if [ "$LOCAL_DIR_SET" -eq 0 ]; then
  if [ -z "$CACHE_DIR" ]; then
    if [ -n "${HF_HOME:-}" ]; then
      CACHE_DIR="$HF_HOME/hub"
    elif [ -n "${XDG_CACHE_HOME:-}" ]; then
      CACHE_DIR="$XDG_CACHE_HOME/huggingface/hub"
    else
      CACHE_DIR="$HOME/.cache/huggingface/hub"
    fi
  fi
  repo_cache="$CACHE_DIR/$cache_prefix--${REPO_ID//\//--}"
  LOCAL_DIR="$repo_cache/snapshots/$commit_hash"
  mkdir -p "$LOCAL_DIR" "$repo_cache/refs"
  [ "$REVISION" = "$commit_hash" ] || printf "%s" "$commit_hash" > "$repo_cache/refs/$REVISION"
else
  mkdir -p "$LOCAL_DIR"
fi

total="$(wc -l < "$selected" | tr -d ' ')"
echo "repo_id=$REPO_ID"
echo "repo_type=$REPO_TYPE"
echo "revision=$REVISION"
echo "commit_hash=$commit_hash"
echo "endpoint=$endpoint"
echo "output=$LOCAL_DIR"
echo "files_selected=$total"

if [ "$total" = "0" ]; then
  echo "No files selected."
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  cat "$selected"
  exit 0
fi

download_file() {
  local file="$1" file_path url dest attempt rc bytes
  file_path="$(urlenc_path "$file")"
  url="$endpoint$download_prefix/$repo_path/resolve/$revision_path/$file_path"
  dest="$LOCAL_DIR/$file"
  mkdir -p "$(dirname "$dest")"

  attempt=1
  while [ "$attempt" -le "$MAX_TRIES" ]; do
    echo "[$file] attempt $attempt/$MAX_TRIES"
    timeout --foreground "$TRY_TIMEOUT" wget "${proxy_args[@]}" "${headers[@]}" "${wget_download_log_args[@]}" \
      --continue --tries=1 --connect-timeout=30 --read-timeout=120 \
      --output-document="$dest" "$url"
    rc=$?
    if [ "$rc" -eq 130 ] || [ "$rc" -eq 143 ]; then
      interrupt
    fi
    if [ "$rc" -eq 0 ]; then
      bytes="$(stat -c '%s' "$dest" 2>/dev/null || printf 0)"
      echo "[$file] ok ($bytes bytes)"
      return 0
    fi
    echo "[$file] failed with code $rc"
    [ "$attempt" -lt "$MAX_TRIES" ] && sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
  return 1
}

failed=0
index=0
while IFS= read -r file; do
  index=$((index + 1))
  echo "[$index/$total] $file"
  download_file "$file" || failed=$((failed + 1))
done < "$selected"

[ "$failed" -eq 0 ] || die "$failed file(s) failed"
echo "Download complete: $LOCAL_DIR"
