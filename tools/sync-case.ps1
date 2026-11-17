# 把 shared/case 同步到鸿蒙侧资源目录（唯一源在 shared/case，副本不入库）
# 用法（仓库根）：powershell -File tools/sync-case.ps1
#                powershell -File tools/sync-case.ps1 -Check   # 只比对不写入

param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'shared\case'
$targets = @(
    (Join-Path $root 'harmony\entry\src\main\resources\rawfile\case'),
    (Join-Path $root 'harmony\entry\src\ohosTest\resources\rawfile\case')
)

if (-not (Test-Path $src)) {
    throw "找不到内容源目录：$src"
}

$files = Get-ChildItem -Path $src -Filter '*.json' -File | Where-Object { $_.Name -ne 'case.schema.json' }
if ($files.Count -eq 0) {
    throw "内容源目录里没有案件 JSON：$src"
}

$drift = 0
foreach ($target in $targets) {
    if ($Check) {
        if (-not (Test-Path $target)) {
            Write-Host "MISSING  $target（未同步）" -ForegroundColor Yellow
            $drift++
            continue
        }
        foreach ($file in $files) {
            $copied = Join-Path $target $file.Name
            if (-not (Test-Path $copied)) {
                Write-Host "MISSING  $copied" -ForegroundColor Yellow
                $drift++
                continue
            }
            $a = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
            $b = (Get-FileHash $copied -Algorithm SHA256).Hash
            if ($a -ne $b) {
                Write-Host "DRIFT    $copied" -ForegroundColor Yellow
                $drift++
            }
        }
        Write-Host "已比对 $target"
        continue
    }

    New-Item -ItemType Directory -Force -Path $target | Out-Null
    foreach ($file in $files) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $target $file.Name) -Force
    }
    Write-Host "同步完成 -> $target（$($files.Count) 个文件）" -ForegroundColor Green
}

if ($Check) {
    if ($drift -eq 0) {
        Write-Host 'ACK：鸿蒙侧内容与 shared/case 一致' -ForegroundColor Green
        exit 0
    }
    Write-Host "发现 $drift 处不一致（AC-19 会失败）" -ForegroundColor Red
    exit 1
}
