# 无 IDE 构建鸿蒙工程（DevEco 自带 hvigor）
#
# 仓库现在位于纯 ASCII 路径 E:\campus-case，所以默认**原地构建**，产物直接落在
# harmony/entry/build（与 DevEco 图形界面构建出来的位置一致）。
# 只有仓库仍放在含非 ASCII 字符的路径下（旧位置 E:\校园推理galgame）时才需要镜像：
# hvigor 会直接抛 `Invalid project path`，脚本这时自动 robocopy 到
# %LOCALAPPDATA%\campus-case-build 再构建。
#
# 用法（仓库根）：
#   powershell -File tools/build-harmony.ps1              # 只编译 main + ohosTest
#   powershell -File tools/build-harmony.ps1 -Test        # 额外跑单元测试（需已连接设备/模拟器）
#   powershell -File tools/build-harmony.ps1 -Clean       # 先清产物（镜像模式下清镜像目录）
#   powershell -File tools/build-harmony.ps1 -Mirror      # 强制走镜像（路径合法时也可用，隔离仓库）
#
# 可用 $env:DEVECO_HOME 覆盖 DevEco 安装路径。

param(
    [switch]$Test,
    [switch]$Clean,
    [switch]$Mirror
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$devHome = if ($env:DEVECO_HOME) { $env:DEVECO_HOME } else { 'D:\huawei\DevEco Studio' }
$hvigor = Join-Path $devHome 'tools\hvigor\bin\hvigorw.bat'
$nodeDir = Join-Path $devHome 'tools\node'
$ohpmDir = Join-Path $devHome 'tools\ohpm\bin'
$sdk = Join-Path $devHome 'sdk'

foreach ($p in @($hvigor, $sdk, $nodeDir)) {
    if (-not (Test-Path $p)) {
        throw "找不到 DevEco 组件：$p`n请设置 `$env:DEVECO_HOME` 指向 DevEco Studio 安装目录"
    }
}

$source = Join-Path $root 'harmony'
$nonAscii = $root -match '[^\x00-\x7F]'
$useMirror = $Mirror -or $nonAscii
$mirrorRoot = Join-Path $env:LOCALAPPDATA 'campus-case-build'
$work = if ($useMirror) { Join-Path $mirrorRoot 'harmony' } else { $source }

if ($useMirror) {
    if ($Clean -and (Test-Path $mirrorRoot)) {
        Remove-Item $mirrorRoot -Recurse -Force
    }
    Write-Host "镜像 $source -> $work（非 ASCII 路径，hvigor 只认 ASCII）" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    # /MIR 让镜像与仓库一致；不排除 oh_modules，否则测试依赖会缺
    robocopy $source $work /MIR /XD build .hvigor .test /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy 失败（exit=$LASTEXITCODE）" }
} else {
    if ($Clean) {
        foreach ($d in @('build', 'entry\build', '.hvigor', '.test')) {
            $target = Join-Path $source $d
            if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        }
    }
    Write-Host "原地构建 $work（ASCII 路径，无需镜像）" -ForegroundColor Cyan
}

$env:DEVECO_SDK_HOME = $sdk
$env:PATH = "$nodeDir;$ohpmDir;$env:PATH"

Push-Location $work
try {
    $common = @('--mode', 'module', '--no-daemon', '-p', 'product=default')

    # PS 5.1 会把原生命令的 stderr 当异常抛出，这里降级为普通输出、只看退出码
    function Invoke-Hvigor {
        param([string[]]$HvigorArgs)
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $lines = & $hvigor @HvigorArgs 2>&1 | ForEach-Object { "$_" }
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevEap
        }
        return [pscustomobject]@{ Code = $code; Lines = $lines }
    }

    Write-Host "`n[1/2] 编译主模块 (entry@default)" -ForegroundColor Cyan
    $mainBuild = Invoke-Hvigor ($common + @('-p', 'module=entry@default', 'assembleHap'))
    $mainBuild.Lines | Select-String -Pattern 'ERROR|BUILD (SUCCESSFUL|FAILED)|CompileArkTS' | ForEach-Object { $_.Line }
    if ($mainBuild.Code -ne 0) { throw "主模块编译失败（exit=$($mainBuild.Code)）" }

    Write-Host "`n[2/2] 编译测试模块 (entry@ohosTest)" -ForegroundColor Cyan
    $testBuild = Invoke-Hvigor ($common + @('-p', 'module=entry@ohosTest', 'assembleHap'))
    $testBuild.Lines | Select-String -Pattern 'ERROR|BUILD (SUCCESSFUL|FAILED)|OhosTestCompileArkTS' | ForEach-Object { $_.Line }
    if ($testBuild.Code -ne 0) { throw "测试模块编译失败（exit=$($testBuild.Code)）" }

    if ($Test) {
        Write-Host "`n[3/3] 运行单元测试（需设备/模拟器 + 签名）" -ForegroundColor Cyan
        $testRun = Invoke-Hvigor ($common + @('-p', 'module=entry@ohosTest', 'test'))
        $testRun.Lines | Select-String -Pattern 'ERROR|BUILD (SUCCESSFUL|FAILED)|Tests|passed|failed' | ForEach-Object { $_.Line }
        if ($testRun.Code -ne 0) { throw "测试失败（exit=$($testRun.Code)）" }
    }

    $hap = Join-Path $work 'entry\build\default\outputs\default\entry-default-unsigned.hap'
    if (Test-Path $hap) { Write-Host "`nHAP: $hap" -ForegroundColor DarkGray }

    Write-Host "`nRESULT: PASS" -ForegroundColor Green
} finally {
    Pop-Location
}
