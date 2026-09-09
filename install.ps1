# install.ps1 — cli-agent 一行安装器（方案 3.5 / 6.12），Windows x64
#
# 流程：平台检测 -> 版本解析 -> 下载归档 -> 从【默认分支】取 sha256 ->
#       fail-closed 校验 -> 停同前缀运行实例 -> 装用户前缀（整目录替换，
#       不碰用户数据）-> 写启动器 -> PATH 缺则补 -> 打印 EULA 摘要 + 下一步。
#
# 一行命令（cmd 与 PowerShell 均可直接粘贴；测试期仓库 Chaiyanchong/CLI-Agent）：
#   powershell -NoProfile -Command "iwr https://raw.githubusercontent.com/Chaiyanchong/CLI-Agent/main/install.ps1 -UseBasicParsing | iex"
#
# -UseBasicParsing 必须保留：Windows PowerShell 5.1 默认 IE 引擎会卡住。
# iwr | iex 内存执行，不受 ExecutionPolicy 文件限制。
#
# 可覆盖的环境变量：
#   $env:CLI_AGENT_VERSION         钉死版本（如 3.17.0）；缺省查 GitHub API latest
#   $env:CLI_AGENT_REPO            归档下载源（缺省 Chaiyanchong/CLI-Agent，测试期）
#   $env:CLI_AGENT_CHECKSUM_REPO   校验和源（缺省同 CLI_AGENT_REPO；设计上钉死）
#   $env:CLI_AGENT_INSTALL_PREFIX  安装前缀（缺省 %LOCALAPPDATA%\cli-agent）

$ErrorActionPreference = "Stop"

function Fail([string]$msg) {
    Write-Error "[install] FAIL-CLOSED: $msg"
    exit 1
}

$REPO = if ($env:CLI_AGENT_REPO) { $env:CLI_AGENT_REPO } else { "Chaiyanchong/CLI-Agent" }
$CHECKSUM_REPO = if ($env:CLI_AGENT_CHECKSUM_REPO) { $env:CLI_AGENT_CHECKSUM_REPO } else { $REPO }
$PREFIX = if ($env:CLI_AGENT_INSTALL_PREFIX) { $env:CLI_AGENT_INSTALL_PREFIX } else { "$env:LOCALAPPDATA\cli-agent" }
$BIN_DIR = "$env:USERPROFILE\.local\bin"

# 1. 平台检测（v1 仅 Windows x64）
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($arch -ne "64Bit") { Fail "v1 仅支持 Windows x64（当前 $arch）" }
$PLATFORM = "windows-x86_64"
$ARCHIVE_EXT = "zip"
Write-Host "[install] 平台: $PLATFORM"

# 2. 版本解析（钉死 > GitHub API latest）
if ($env:CLI_AGENT_VERSION) {
    $VERSION = $env:CLI_AGENT_VERSION.TrimStart('v')
    Write-Host "[install] 版本（钉死）: $VERSION"
} else {
    Write-Host "[install] 查询 GitHub API 取 latest ..."
    try {
        $resp = Invoke-WebRequest -Uri "https://api.github.com/repos/$REPO/releases/latest" `
            -UseBasicParsing -Headers @{ "User-Agent" = "cli-agent-installer" }
        $TAG = ($resp.Content | ConvertFrom-Json).tag_name
    } catch {
        Fail "无法查询 latest release（网络？仓库 $REPO 尚无 release？）；请设 `$env:CLI_AGENT_VERSION 钉死版本"
    }
    if (-not $TAG) { Fail "GitHub API 未返回 tag_name；请设 `$env:CLI_AGENT_VERSION 钉死版本" }
    $VERSION = $TAG.TrimStart('v')
    Write-Host "[install] 版本（latest）: $VERSION (tag $TAG)"
}
$TAG = "v$VERSION"

# 3. 下载归档（来源 = CLI_AGENT_REPO，可变）
$ARCHIVE_NAME = "cli-agent-$VERSION-$PLATFORM.$ARCHIVE_EXT"
$ARCHIVE_URL = "https://github.com/$REPO/releases/download/$TAG/$ARCHIVE_NAME"
$TMP = Join-Path ([System.IO.Path]::GetTempPath()) ("cli-agent-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TMP | Out-Null
try {
    Write-Host "[install] 下载归档: $ARCHIVE_URL"
    Invoke-WebRequest -Uri $ARCHIVE_URL -OutFile (Join-Path $TMP $ARCHIVE_NAME) -UseBasicParsing
} catch { Fail "归档下载失败: $ARCHIVE_URL ($_)" }

# 4. 从【默认分支】取 sha256（钉死，不随归档源变）
$CHECKSUM_URL = "https://raw.githubusercontent.com/$CHECKSUM_REPO/main/checksums/$TAG.sha256"
Write-Host "[install] 取校验和: $CHECKSUM_URL"
try {
    $checksumText = (Invoke-WebRequest -Uri $CHECKSUM_URL -UseBasicParsing).Content
} catch { Fail "无法从默认分支取校验和: $CHECKSUM_URL（该版本尚未发布？）($_)" }

# 5. sha256 校验（fail-closed：缺失 / 不匹配 -> 中止，无跳过开关）
$expected = $null
foreach ($line in ($checksumText -split "`r?`n")) {
    $parts = @($line -split '\s+')
    if ($parts.Count -ge 2 -and $parts[1].TrimStart('*') -eq $ARCHIVE_NAME) {
        $expected = $parts[0].ToLower()
        break
    }
}
if (-not $expected) { Fail "校验和文件中无 $ARCHIVE_NAME 的行" }
$actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $TMP $ARCHIVE_NAME)).Hash.ToLower()
if ($actual -ne $expected) {
    Fail "sha256 不匹配 ${ARCHIVE_NAME}: 期望 $expected 实得 $actual（中止，无跳过开关）"
}
Write-Host "[install] OK sha256=$actual"

# 6. 停同前缀运行实例（Windows 运行中 exe 不能原地替换；只停同前缀，绝不动其它安装）
$prefixSep = $PREFIX.TrimEnd('\') + "\"
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path.StartsWith($prefixSep, [System.StringComparison]::OrdinalIgnoreCase) }
    catch { $false }
} | ForEach-Object {
    Write-Host "[install] 停止同前缀运行实例: $($_.Id) $($_.ProcessName)"
    Stop-Process -Id $_.Id -Force
}
Start-Sleep -Milliseconds 500

# 7. 解压到临时目录，整目录替换安装前缀（不触碰用户数据目录 ~/reolink-agent）
Write-Host "[install] 解压 ..."
$extract = Join-Path $TMP "extract"
New-Item -ItemType Directory -Force -Path $extract | Out-Null
Expand-Archive -Path (Join-Path $TMP $ARCHIVE_NAME) -DestinationPath $extract -Force
$srcDir = Join-Path $extract "cli-agent"
if (-not (Test-Path $srcDir)) { Fail "归档内无 cli-agent\ 顶层目录（归档损坏？）" }
if (Test-Path $PREFIX) { Remove-Item -Recurse -Force $PREFIX }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $PREFIX) | Out-Null
Move-Item -Path $srcDir -Destination $PREFIX
Write-Host "[install] 安装前缀: $PREFIX"

# 8. 写启动器（指向真实入口 cli-agent.exe）
$ENTRY = Join-Path $PREFIX "cli-agent.exe"
if (-not (Test-Path $ENTRY)) { Fail "入口不存在: $ENTRY" }
New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null
$LAUNCHER = Join-Path $BIN_DIR "cli-agent.cmd"
Set-Content -Path $LAUNCHER -Value "@echo off`r`n`"$ENTRY`" %*" -Encoding ASCII
Write-Host "[install] 启动器: $LAUNCHER"

# 9. PATH 缺则补（用户级）
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
if (($userPath -split ';') -notcontains $BIN_DIR) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$BIN_DIR", "User")
    Write-Host "[install] 已把 $BIN_DIR 加入用户 PATH（新终端生效）"
}

# 10. EULA 摘要 + 下一步
Write-Host ""
Write-Host "=========================================="
Write-Host " cli-agent $VERSION 已安装"
Write-Host "=========================================="
Write-Host " 安装即表示你接受 EULA（详见 $PREFIX\EULA.txt 与公开仓库 EULA.txt）。"
Write-Host " 下一步："
Write-Host "   1. 复制配置: copy $PREFIX\config\bot_config.example.json $PREFIX\config\bot_config.json"
Write-Host "   2. 设置环境变量: DISCORD_BOT_TOKEN（及所选模型的 API key，见 .env.example）"
Write-Host "   3. 启动: cli-agent"
Write-Host " 归档校验: sha256=$actual"
Write-Host "=========================================="

Remove-Item -Recurse -Force $TMP -ErrorAction SilentlyContinue
