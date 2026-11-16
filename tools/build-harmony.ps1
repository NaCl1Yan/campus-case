# 无 IDE 构建鸿蒙工程（ASCII 镜像 + DevEco 自带 hvigor）
# 为什么需要镜像：hvigor 拒绝中文工程路径（Invalid project path），
# 而本仓库位于 E:\校园推理galgame，所以镜像到 %LOCALAPPDATA%\campus-case-build 再构建。
#
# 用法（仓库根）：
#   powershell -File tools/build-harmony.ps1              # 只编译 main + ohosTest
#   powershell -File tools/build-harmony.ps1 -Test        # 额外跑单元测试（需已连接设备/模拟器）
#   powershell -File tools/build-harmony.ps1 -Clean       # 先清空镜像目录
#
# 可用 $env:DEVECO_HOME 覆盖 DevEco 安装路径。

param(
    [switch]$Test,
    [switch]$Clean
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
        throw "找不到 DevEco 组件：$p`n请设置 `$env:DEVECO_HOME 指向 DevEco Studio 安装目录"
    }
}

$source = Join-Path $root 'harmony'
$work = Join-Path $env:LOCALAPPDATA 'campus-case-build\harmony'

if ($Clean -and (Test-Path (Split-Path -Parent $work))) {
    Remove-Item (Split-Path -Parent $work) -Recurse -Force
}

Write-Host "镜像 $source -> $work" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $work | Out-Null
# /MIR 让镜像与仓库一致；不排除 oh_modules，否则测试依赖会缺
robocopy $source $work /MIR /XD build .hvigor .test /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 失败（exit=$LASTEXITCODE）" }

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

    Write-Host "`nRESULT: PASS" -ForegroundColor Green
} finally {
    Pop-Location
}
