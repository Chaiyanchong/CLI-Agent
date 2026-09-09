#!/usr/bin/env sh
# check-version-sync.sh — 只读版本一致性检查（方案 6.14 / 3.7）
#
# 借鉴 reolink-cli 的 version-sync（其人工同步曾失败 3 次，故用检查防漂移）。
# 自动检测两种上下文，任一不一致 -> exit 1；只读，从不写仓库。
#
#   A. 源码仓库（存在 pyproject.toml）：pyproject.toml /
#      deepagents_reolink/_version.py（回退 __init__.py）/ CHANGELOG.md 标题
#      三处版本必须一致。
#   B. 公开发布仓库（存在 checksums/）：最新 checksums/<tag>.sha256 的 tag
#      必须等于 GitHub 已发布 latest release 的 tag。
#
# 用法：sh scripts/check-version-sync.sh
set -eu

# ---- 模式 A：源码仓库（pyproject.toml 存在）----
if [ -f pyproject.toml ]; then
  py_ver="$(grep -m1 '^version' pyproject.toml | sed -E 's/.*"([^"]+)".*/\1/')"
  if [ -f deepagents_reolink/_version.py ]; then
    pkg_ver="$(grep -m1 '__version__' deepagents_reolink/_version.py | sed -E 's/.*"([^"]+)".*/\1/')"
  else
    pkg_ver="$(grep -m1 '__version__' deepagents_reolink/__init__.py | sed -E 's/.*"([^"]+)".*/\1/')"
  fi
  # CHANGELOG.md 第一个版本标题（"## 3.17.0" / "## v3.17.0" /
  # Keep a Changelog 的 "## [3.17.0] - 2026-09-09"）
  cl_ver="$(grep -m1 -E '^##[[:space:]]+\[?v?[0-9]' CHANGELOG.md 2>/dev/null \
    | sed -E 's/^##[[:space:]]+\[?v?([0-9][0-9.]*).*/\1/' || true)"
  echo "[version-sync] pyproject.toml=$py_ver  package=$pkg_ver  CHANGELOG=$cl_ver"
  if [ -z "$py_ver" ] || [ -z "$pkg_ver" ]; then
    echo "[version-sync] FAIL: 未能解析 pyproject.toml / 包版本" >&2
    exit 1
  fi
  if [ "$py_ver" != "$pkg_ver" ]; then
    echo "[version-sync] FAIL: pyproject.toml($py_ver) != package($pkg_ver)" >&2
    exit 1
  fi
  if [ -n "$cl_ver" ] && [ "$py_ver" != "$cl_ver" ]; then
    echo "[version-sync] FAIL: pyproject.toml($py_ver) != CHANGELOG($cl_ver)" >&2
    exit 1
  fi
  echo "[version-sync] OK（源码仓库版本一致）"
fi

# ---- 模式 B：公开发布仓库（checksums/ 存在）----
if [ -d checksums ]; then
  latest_tag="$(ls checksums/*.sha256 2>/dev/null | sed -E 's|.*/||; s|\.sha256$||' | sort -V | tail -1 || true)"
  if [ -z "$latest_tag" ]; then
    echo "[version-sync] WARN: checksums/ 无 .sha256（尚无发布），跳过 release 对照"
  else
    # GitHub 仓库名：CI 注入 GITHUB_REPOSITORY，否则从 git remote 推断
    repo="${GITHUB_REPOSITORY:-}"
    if [ -z "$repo" ]; then
      repo="$(git remote get-url origin 2>/dev/null | sed -E 's#^git@github.com:(.*?)(\.git)?$#\1#; s#^https?://github.com/(.*?)(\.git)?$#\1#' || true)"
    fi
    gh_tag="$(curl -fsSL -H 'User-Agent: cli-agent-version-sync' \
        "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -o '"tag_name"[^,]*' | head -1 | sed -E 's/.*: *"//; s/".*//' || true)"
    echo "[version-sync] 仓库最新 checksum tag=$latest_tag  GitHub latest release=${gh_tag:-（无）}"
    if [ -n "$gh_tag" ] && [ "$latest_tag" != "$gh_tag" ]; then
      echo "[version-sync] FAIL: 仓库 checksum($latest_tag) != 已发布 release($gh_tag)" >&2
      exit 1
    fi
    echo "[version-sync] OK（发布仓库 checksum 与 latest release 一致）"
  fi
fi
