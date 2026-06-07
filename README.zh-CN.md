# HF Mirror Download Skill

[English](README.md)

这是一个用于 Codex 的技能，可通过 `hf-mirror.com` 下载 Hugging Face 模型、数据集和 Spaces，并使用可续传的 `wget` 下载。

默认情况下，文件会下载到 Hugging Face 缓存布局中，因此 `from_pretrained("repo_id", local_files_only=True)` 可以找到它们。

## 安装

本仓库遵循 Agent Skills 布局：

```text
skills/hf-mirror-download/SKILL.md
```

为 Codex 安装：

```bash
npx skills add UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download
```

全局安装：

```bash
npx skills add UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download \
  --global
```

安装前列出可用技能：

```bash
npx skills add UCPRER/hf-mirror-download-skill --list
```

使用完整的 GitHub URL 安装：

```bash
npx skills add https://github.com/UCPRER/hf-mirror-download-skill \
  --agent codex \
  --skill hf-mirror-download
```

## 脚本用法

在技能目录中直接运行：

```bash
cd skills/hf-mirror-download
bash scripts/hf_mirror_download.sh google/flan-t5-base
```

常用选项：

```bash
# 保存到普通目录，而不是 HF 缓存
bash scripts/hf_mirror_download.sh google/flan-t5-base --local-dir ./flan-t5-base

# 仅下载选中的文件
bash scripts/hf_mirror_download.sh Qwen/Qwen2.5-0.5B \
  --include '*.json' \
  --include '*.safetensors'

# 使用代理
bash scripts/hf_mirror_download.sh google/flan-t5-base --proxy http://127.0.0.1:9890

# 预览将要下载的文件
bash scripts/hf_mirror_download.sh google/flan-t5-base --dry-run
```

实用的环境变量开关：

```bash
WGET_PROGRESS=0  # 隐藏进度条
WGET_VERBOSE=1   # 显示详细 wget 日志
HF_TOKEN=...     # 用于 gated/private 仓库的 token
```

下载中断后，重新运行相同命令即可继续。
