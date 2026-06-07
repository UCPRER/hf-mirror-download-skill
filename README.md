# HF Mirror Download Skill

Codex skill for downloading Hugging Face models, datasets, and spaces through `hf-mirror.com` with resumable `wget` downloads.

By default, downloads go into the Hugging Face cache layout so `from_pretrained("repo_id", local_files_only=True)` can find them.

## Install

This repo follows the Agent Skills layout:

```text
skills/hf-mirror-download/SKILL.md
```

Install for Codex:

```bash
npx skills add UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download
```

Install globally:

```bash
npx skills add UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download \
  --global
```

List available skills before installing:

```bash
npx skills add UCPRER/hf-mirror-download-skill --list
```

Install from the full GitHub URL:

```bash
npx skills add https://github.com/UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download
```

## Script Usage

Run directly from the skill directory:

```bash
cd skills/hf-mirror-download
bash scripts/hf_mirror_download.sh google/flan-t5-base
```

Common options:

```bash
# Save to a normal directory instead of HF cache
bash scripts/hf_mirror_download.sh google/flan-t5-base --local-dir ./flan-t5-base

# Download selected files only
bash scripts/hf_mirror_download.sh Qwen/Qwen2.5-0.5B \
  --include '*.json' \
  --include '*.safetensors'

# Use a proxy
bash scripts/hf_mirror_download.sh google/flan-t5-base --proxy http://127.0.0.1:9890

# Preview selected files
bash scripts/hf_mirror_download.sh google/flan-t5-base --dry-run
```

Useful environment switches:

```bash
WGET_PROGRESS=0  # hide progress bars
WGET_VERBOSE=1   # show verbose wget logs
HF_TOKEN=...     # token for gated/private repos
```

Interrupted downloads can be resumed by rerunning the same command.
