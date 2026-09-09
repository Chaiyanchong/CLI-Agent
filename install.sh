#!/bin/sh
# install.sh — cli-agent 一行安装器（方案 3.5 / 6.12），macOS / Linux
#
# 流程：平台检测 -> 版本解析 -> 下载归档 -> 从【默认分支】取 sha256 ->
#       fail-closed 校验 -> 装用户前缀（整目录替换，不碰用户数据）->
#       写启动器 -> PATH 缺则补 -> 打印 EULA 摘要 + 下一步。
#
# 一行命令（照搬 reolink-cli 模式；测试期仓库 Chaiyanchong/CLI-Agent）：
#   curl -fsSL https://raw.githubusercontent.com/Chaiyanchong/CLI-Agent/main/install.sh | sh
#
# 可覆盖的环境变量：
#   CLI_AGENT_VERSION         钉死版本（如 3.17.0）；缺省查 GitHub API latest
#   CLI_AGENT_REPO            归档下载源（缺省 Chaiyanchong/CLI-Agent，测试期）
#   CLI_AGENT_CHECKSUM_REPO   校验和源（缺省同 CLI_AGENT_REPO；设计上钉死、
#                             不随归档源变——借鉴 reolink-cli REOLINK_REPO 设计）
#   CLI_AGENT_INSTALL_PREFIX  安装前缀（缺省 ~/.local/share/cli-agent）
#
# 安装器是普通文本文件，客户可先下载阅读再运行（reolink-cli 的透明度承诺）。
set -eu

REPO="${CLI_AGENT_REPO:-Chaiyanchong/CLI-Agent}"
CHECKSUM_REPO="${CLI_AGENT_CHECKSUM_REPO:-$REPO}"
PREFIX="${CLI_AGENT_INSTALL_PREFIX:-$HOME/.local/share/cli-agent}"
BIN_DIR="$HOME/.local/bin"

fail() { echo "[install] FAIL-CLOSED: $1" >&2; exit 1; }

# 1. 平台检测
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  PLATFORM="macos-arm64";  ARCHIVE_EXT="tar.gz" ;;
  Linux-x86_64)  PLATFORM="linux-x86_64"; ARCHIVE_EXT="tar.gz" ;;
  Linux-aarch64) PLATFORM="linux-arm64";  ARCHIVE_EXT="tar.gz" ;;
  *) fail "不支持的平台: $(uname -s)-$(uname -m)（v1 支持 macos-arm64 / linux-x86_64）" ;;
esac
echo "[install] 平台: $PLATFORM"

# 2. 版本解析（钉死 > GitHub API latest）
if [ -n "${CLI_AGENT_VERSION:-}" ]; then
  VERSION="${CLI_AGENT_VERSION#v}"
  echo "[install] 版本（钉死）: $VERSION"
else
  echo "[install] 查询 GitHub API 取 latest ..."
  TAG="$(curl -fsSL -H 'User-Agent: cli-agent-installer' \
        "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -o '"tag_name"[^,]*' | head -1 | sed 's/.*: *"//; s/".*//')" \
    || fail "无法查询 latest release（网络？仓库 $REPO 尚无 release？）；请设 CLI_AGENT_VERSION 钉死版本"
  [ -n "$TAG" ] || fail "GitHub API 未返回 tag_name；请设 CLI_AGENT_VERSION 钉死版本"
  VERSION="${TAG#v}"
  echo "[install] 版本（latest）: $VERSION (tag $TAG)"
fi
TAG="v$VERSION"

# 3. 下载归档（来源 = CLI_AGENT_REPO，可变）
ARCHIVE_NAME="cli-agent-$VERSION-$PLATFORM.$ARCHIVE_EXT"
ARCHIVE_URL="https://github.com/$REPO/releases/download/$TAG/$ARCHIVE_NAME"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "[install] 下载归档: $ARCHIVE_URL"
curl -fL --progress-bar -o "$TMP/$ARCHIVE_NAME" "$ARCHIVE_URL" \
  || fail "归档下载失败: $ARCHIVE_URL"

# 4. 从【默认分支】取 sha256（钉死，不随归档源变）
CHECKSUM_URL="https://raw.githubusercontent.com/$CHECKSUM_REPO/main/checksums/$TAG.sha256"
echo "[install] 取校验和: $CHECKSUM_URL"
curl -fsSL -o "$TMP/checksums.txt" "$CHECKSUM_URL" \
  || fail "无法从默认分支取校验和: $CHECKSUM_URL（该版本尚未发布？）"

# 5. sha256 校验（fail-closed：缺失 / 不匹配 -> 中止，无跳过开关）
expected="$(grep -F "$ARCHIVE_NAME" "$TMP/checksums.txt" | awk '{print $1}' | head -1 | tr 'A-F' 'a-f')"
[ -n "$expected" ] || fail "校验和文件中无 $ARCHIVE_NAME 的行"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$TMP/$ARCHIVE_NAME" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$TMP/$ARCHIVE_NAME" | awk '{print $1}')"
fi
[ -n "$actual" ] || fail "无法计算本地 sha256"
if [ "$actual" != "$expected" ]; then
  fail "sha256 不匹配 $ARCHIVE_NAME: 期望 $expected 实得 $actual（中止，无跳过开关）"
fi
echo "[install] OK sha256=$actual"

# 6. 解压到临时目录，整目录替换安装前缀（不触碰用户数据目录 ~/reolink-agent）
echo "[install] 解压 ..."
mkdir -p "$TMP/extract"
tar -xzf "$TMP/$ARCHIVE_NAME" -C "$TMP/extract"
[ -d "$TMP/extract/cli-agent" ] || fail "归档内无 cli-agent/ 顶层目录（归档损坏？）"
mkdir -p "$(dirname "$PREFIX")"
rm -rf "$PREFIX"
mv "$TMP/extract/cli-agent" "$PREFIX"
echo "[install] 安装前缀: $PREFIX"

# 7. 写启动器（指向真实入口；macOS 入口在 .app 内）
ENTRY="$PREFIX/cli-agent"
if [ "$PLATFORM" = "macos-arm64" ]; then
  ENTRY="$PREFIX/cli-agent.app/Contents/MacOS/cli-agent"
fi
[ -f "$ENTRY" ] || fail "入口不存在: $ENTRY"
mkdir -p "$BIN_DIR"
LAUNCHER="$BIN_DIR/cli-agent"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$ENTRY" > "$LAUNCHER"
chmod +x "$LAUNCHER"
echo "[install] 启动器: $LAUNCHER"

# 8. PATH 缺则补（借鉴 reolink-cli）
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *)
    echo "[install] 提示: $BIN_DIR 不在 PATH。请加入（zsh）："
    echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    ;;
esac

# 9. EULA 摘要 + 下一步
echo ""
echo "=========================================="
echo " cli-agent $VERSION 已安装"
echo "=========================================="
echo " 安装即表示你接受 EULA（详见 $PREFIX/EULA.txt 与公开仓库 EULA.txt）。"
echo " 下一步："
echo "   1. 复制配置: cp $PREFIX/config/bot_config.example.json $PREFIX/config/bot_config.json"
echo "   2. 设置环境变量: DISCORD_BOT_TOKEN（及所选模型的 API key，见 .env.example）"
echo "   3. 启动: cli-agent"
echo " 归档校验: sha256=$actual"
echo "=========================================="
