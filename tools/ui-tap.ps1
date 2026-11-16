# 按文本定位的简易 UI 自动化（开发期用，模拟器上驱动真机点击）
# 用法：
#   powershell -File tools/ui-tap.ps1 -Text "接下这桩案子"
#   powershell -File tools/ui-tap.ps1 -Text "线索板" -Below 2400      # 只找 y 坐标大于 2400 的（底部栏）
#   powershell -File tools/ui-tap.ps1 -Shot shot.jpeg                 # 只截图
#   powershell -File tools/ui-tap.ps1 -Dump                            # 只打印当前界面文字

param(
    [string]$Text = '',
    [int]$Below = 0,
    [int]$Above = 999999,
    [switch]$Index2,
    [string]$Shot = '',
    [switch]$Dump,
    [string]$Hdc = 'D:\huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP 'campus-ui'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Get-Nodes {
    $jsonPath = Join-Path $tmp 'layout.json'
    & $Hdc shell uitest dumpLayout -p /data/local/tmp/campus_layout.json | Out-Null
    & $Hdc file recv /data/local/tmp/campus_layout.json $jsonPath | Out-Null
    $raw = Get-Content $jsonPath -Raw -Encoding utf8
    $acc = New-Object System.Collections.ArrayList
    # 不依赖严格 JSON：直接抓同一 attributes 对象里的 bounds 与 text
    $pattern = '"bounds":"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^{}]*?"text":"((?:[^"\\]|\\.)*)"'
    foreach ($m in [regex]::Matches($raw, $pattern)) {
        $text = $m.Groups[5].Value
        if ($text.Length -eq 0) { continue }
        $text = [regex]::Replace($text, '\\u([0-9a-fA-F]{4})', { param($x) [char][Convert]::ToInt32($x.Groups[1].Value, 16) })
        $text = $text.Replace('\"', '"').Replace('\\', '\').Replace('\n', ' ')
        $x1 = [int]$m.Groups[1].Value; $y1 = [int]$m.Groups[2].Value
        $x2 = [int]$m.Groups[3].Value; $y2 = [int]$m.Groups[4].Value
        $null = $acc.Add([pscustomobject]@{
            text = $text; x1 = $x1; y1 = $y1; x2 = $x2; y2 = $y2
            cx = [int](($x1 + $x2) / 2); cy = [int](($y1 + $y2) / 2)
        })
    }
    return $acc
}

if ($Dump) {
    Get-Nodes | ForEach-Object { "{0,-40} [{1},{2}][{3},{4}]" -f $_.text, $_.x1, $_.y1, $_.x2, $_.y2 }
    return
}

if ($Text.Length -gt 0) {
    $nodes = Get-Nodes | Where-Object { $_.text -eq $Text -and $_.cy -ge $Below -and $_.cy -le $Above }
    if ($nodes.Count -eq 0) {
        $nodes = Get-Nodes | Where-Object { $_.text -like "*$Text*" -and $_.cy -ge $Below -and $_.cy -le $Above }
    }
    if ($nodes.Count -eq 0) {
        Write-Host "找不到文本: $Text" -ForegroundColor Red
        exit 1
    }
    $node = if ($Index2 -and $nodes.Count -gt 1) { $nodes[1] } else { $nodes[0] }
    Write-Host ("点击 '{0}' @ ({1},{2})" -f $node.text, $node.cx, $node.cy) -ForegroundColor Cyan
    & $Hdc shell uitest uiInput click $node.cx $node.cy | Out-Null
}

if ($Shot.Length -gt 0) {
    $dest = Join-Path $root $Shot
    & $Hdc shell snapshot_display -f /data/local/tmp/campus_shot.jpeg | Out-Null
    & $Hdc file recv /data/local/tmp/campus_shot.jpeg $dest | Out-Null
    Write-Host "截图: $Shot" -ForegroundColor Green
}
