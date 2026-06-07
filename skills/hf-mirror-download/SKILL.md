---
name: hf-mirror-download
description: "Always use this skill for any Hugging Face download task, including models, datasets, spaces, mirrors, cache population, resume/retry downloads, and download speed tests; do not use `hf download`, `huggingface-cli download`, raw `curl`, raw `wget`, or ad hoc download scripts unless the user explicitly asks to avoid this skill."
---

# HF Mirror Download

Use this skill for every Hugging Face download unless the user explicitly asks not to.

## Procedure

1. Locate this skill directory.
2. Run the bundled script:

```bash
bash "$SKILL_DIR/scripts/hf_mirror_download.sh" <repo_id>
```

Use script options as needed:

```text
--local-dir DIR        Save to a normal directory. If omitted, save to HF cache.
--cache-dir DIR        Hugging Face hub cache dir.
--revision REV         Branch, tag, or commit. Default: main.
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
```

When `--local-dir` is omitted, the script writes Hugging Face cache layout under `HF_HUB_CACHE`, `HF_HOME/hub`, or the default `~/.cache/huggingface/hub`, so `from_pretrained("repo_id", local_files_only=True)` can find files when Python uses the same cache environment.

Set `WGET_PROGRESS=0` to hide progress bars. Set `WGET_VERBOSE=1` to debug wget.

## Report Back

Summarize:

- the repo id and revision;
- whether files were saved to HF cache or a local directory;
- the final output path;
- whether the download completed, was interrupted, or failed after retries.
