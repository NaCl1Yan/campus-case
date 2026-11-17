# E2E 演示流水线：一条命令跑完「主线 / 撬锁分支 / 存档」，逐步断言
# 用法（仓库根，需模拟器在线）：
#   powershell -File tools/e2e.ps1 -Scenario happy
#   powershell -File tools/e2e.ps1 -Scenario breach
#   powershell -File tools/e2e.ps1 -Scenario slots
#   powershell -File tools/e2e.ps1 -Scenario all
#
# 依赖：hdc（DevEco SDK 自带）、已安装 com.nacl1yan.campuscase
# 断言方式：每一步点击后 dump 布局，检查期望文本是否出现（出现=通过）

param(
    [ValidateSet('happy', 'breach', 'slots', 'all')]
    [string]$Scenario = 'happy',
    [string]$Hdc = 'D:\huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe',
    [int]$BootTimeoutSec = 120
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP 'campus-e2e'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root 'docs\screenshots') | Out-Null

$script:pass = 0
$script:fail = 0

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

function Ensure-Device {
    for ($i = 0; $i -le [Math]::Floor($BootTimeoutSec / 5); $i++) {
        $t = (& $Hdc list targets 2>&1 | Out-String).Trim()
        if ($t -and $t -notmatch 'Empty') { return }
        Start-Sleep -Seconds 5
    }
    throw "没有可用设备：请先在 DevEco 的 Device Manager 启动模拟器（hdc list targets 为空）"
}

function Get-Nodes {
    & $Hdc shell uitest dumpLayout -p /data/local/tmp/e2e_layout.json | Out-Null
    $jsonPath = Join-Path $tmp 'layout.json'
    & $Hdc file recv /data/local/tmp/e2e_layout.json $jsonPath | Out-Null
    $raw = Get-Content $jsonPath -Raw -Encoding utf8
    $acc = New-Object System.Collections.ArrayList
    $pattern = '"bounds":"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^{}]*?"text":"((?:[^"\\]|\\.)*)"'
    foreach ($m in [regex]::Matches($raw, $pattern)) {
        $text = $m.Groups[5].Value
        if ($text.Length -eq 0) { continue }
        $text = [regex]::Replace($text, '\\u([0-9a-fA-F]{4})', { param($x) [char][Convert]::ToInt32($x.Groups[1].Value, 16) })
        $text = $text.Replace('\"', '"').Replace('\\', '\')
        $x1 = [int]$m.Groups[1].Value; $y1 = [int]$m.Groups[2].Value
        $x2 = [int]$m.Groups[3].Value; $y2 = [int]$m.Groups[4].Value
        $null = $acc.Add([pscustomobject]@{
            text = $text; cx = [int](($x1 + $x2) / 2); cy = [int](($y1 + $y2) / 2)
        })
    }
    return $acc
}

function ScrollDown {
    & $Hdc shell uitest uiInput swipe 630 2100 630 900 300 | Out-Null
    Start-Sleep -Milliseconds 800
}

function ScrollUp {
    & $Hdc shell uitest uiInput swipe 630 900 630 2100 300 | Out-Null
    Start-Sleep -Milliseconds 800
}

function Find-Node($text, [int]$below) {
    $nodes = Get-Nodes | Where-Object { $_.text -eq $text -and $_.cy -ge $below }
    if (-not $nodes) { $nodes = Get-Nodes | Where-Object { $_.text -like "*$text*" -and $_.cy -ge $below } }
    return $nodes
}

function Tap($text, [int]$below = 0) {
    $nodes = Find-Node $text $below
    if (-not $nodes) {
        # 字号放大后可点项可能落在折叠线以下：滚一屏再找
        ScrollDown
        $nodes = Find-Node $text $below
    }
    if (-not $nodes) {
        ScrollUp; ScrollUp
        $nodes = Find-Node $text $below
    }
    if (-not $nodes) { throw "找不到可点击文本：$text（已尝试滚动）" }
    $n = $nodes[0]
    & $Hdc shell uitest uiInput click $n.cx $n.cy | Out-Null
    Say ("  点击 {0} @ ({1},{2})" -f $n.text, $n.cx, $n.cy) 'DarkGray'
    Start-Sleep -Milliseconds 1200
}

function Expect($text, $label) {
    $hit = Get-Nodes | Where-Object { $_.text -like "*$text*" } | Select-Object -First 1
    if ($hit) {
        $script:pass++
        Say ("  ✓ {0}（看到「{1}」）" -f $label, $text) 'Green'
    } else {
        $script:fail++
        Say ("  ✗ {0}（没找到「{1}」）" -f $label, $text) 'Red'
    }
}

function EnsureNot($text, $label) {
    $hit = Get-Nodes | Where-Object { $_.text -like "*$text*" } | Select-Object -First 1
    if (-not $hit) {
        $script:pass++
        Say ("  ✓ {0}（确认没有「{1}」）" -f $label, $text) 'Green'
    } else {
        $script:fail++
        Say ("  ✗ {0}（不该出现「{1}」却出现了）" -f $label, $text) 'Red'
    }
}

function Shot($name) {
    $dest = Join-Path $root ("docs\screenshots\" + $name)
    & $Hdc shell snapshot_display -f /data/local/tmp/e2e_shot.jpeg | Out-Null
    & $Hdc file recv /data/local/tmp/e2e_shot.jpeg $dest | Out-Null
    Say ("  截图 -> docs/screenshots/{0}" -f $name) 'Cyan'
}

function Restart-App {
    & $Hdc shell "aa force-stop com.nacl1yan.campuscase" | Out-Null
    Start-Sleep 2
    & $Hdc shell aa start -a EntryAbility -b com.nacl1yan.campuscase | Out-Null
    Start-Sleep 6
}

function Ensure-DefaultSettings {
    # 字号固定 1.0，避免大字号下卡片与固定按钮重叠导致误点
    Tap '⋯ 更多'
    Start-Sleep 1
    Tap '设置'
    Start-Sleep 1
    Tap '标准'
    Start-Sleep 1
    Tap '‹ 返回'
    Start-Sleep 1
}

function Reset-Progress {
    Tap '⋯ 更多'
    Start-Sleep 1
    Tap '重来本局'
    Start-Sleep 1
    Tap '重开'
    Start-Sleep 2
}

# ---------------------------------------------------------------- 场景

function Scenario-Happy {
    Say "`n=== 主线（行动线 + 动机线都成立 → E-A《七点钟声》）===" 'Cyan'
    Restart-App
    Ensure-DefaultSettings
    Reset-Progress
    Expect '第1阶段 · 简报' '回到简报页'

    Tap '接下这桩案子'
    Expect '第2阶段 · 勘探' '接案进入勘探'

    Tap '图书馆 · 旧报刊区'; Tap '值班表上的涂改'; Tap '‹ 返回'
    Expect '线索 1 / 6' '拿到 C2'

    Tap '实验楼 · 器材室走廊'; Tap '器材室的取用登记'; Tap '‹ 返回'
    Expect '线索 2 / 6' '拿到 C1'

    Tap '学生会办公室 · 广播站'
    Tap '内部群里的删除消息'
    Tap '被剪掉的录音'
    Tap '校庆节目单草稿'
    Tap '把线索摊开'
    Tap '‹ 返回'
    Expect '第3阶段 · 验证' '进入验证阶段'
    Expect '线索 5 / 6' '拿到 C4/C3/C6'

    Tap '图书馆 · 旧报刊区'; Tap '未寄出的道歉信'; Tap '‹ 返回'
    Tap '旧钟楼 · 老播音间'; Tap '老播音间的母带'; Tap '‹ 返回'
    Expect '线索 6 / 6' '线索全收集'
    Expect '动机线 3/3' '动机线就绪'

    Tap '线索板' 2400
    Tap '沾着白粉的钥匙卡'; Tap '值班表上的涂改'; Tap '连线'
    Tap '被剪掉的录音'; Tap '连线'
    Tap '未寄出的道歉信'; Tap '校庆节目单草稿'; Tap '连线'
    Expect '已成立的结论' '连线产出结论'

    Tap '去验证'
    Tap '开始这一问'
    Tap '沾着白粉的钥匙卡'; Tap '值班表上的涂改'; Tap '提交'
    Tap '开始这一问'
    Tap '未寄出的道歉信'; Tap '校庆节目单草稿'; Tap '提交'
    Expect '可推理' '两关通过'

    Tap '去判断'
    Tap '先私下对质，给对方一次开口的机会'
    Tap '确定'
    Expect '《七点钟声》' '进入结局 A'
    Shot 'e2e-happy-ending.jpeg'

    Tap '⋯ 更多'
    Start-Sleep 1
    Tap '收集册'
    Start-Sleep 1
    Expect '已解锁' '收集册点亮'
    Shot 'e2e-happy-gallery.jpeg'
}

function Scenario-Breach {
    Say "`n=== 撬锁分支（动机线断裂 → 私下对质应灰显）===" 'Cyan'
    Restart-App
    Ensure-DefaultSettings
    Reset-Progress
    Tap '接下这桩案子'
    Tap '图书馆 · 旧报刊区'; Tap '值班表上的涂改'; Tap '‹ 返回'
    Tap '实验楼 · 器材室走廊'; Tap '撬开器材室'; Expect '已调查' '撬锁成功'
    Tap '‹ 返回'
    Tap '学生会办公室 · 广播站'; Expect '已封锁' '群消息被永久关闭'
    Shot 'e2e-breach-closed.jpeg'

    Tap '被剪掉的录音'; Tap '校庆节目单草稿'; Tap '把线索摊开'; Tap '‹ 返回'
    Tap '图书馆 · 旧报刊区'; Expect '未解锁' '道歉信节点锁死'
    Tap '‹ 返回'
    Tap '旧钟楼 · 老播音间'; Expect '未解锁' '旧钟楼仍锁定'

    Tap '线索板' 2400
    Tap '沾着白粉的钥匙卡'; Tap '值班表上的涂改'; Tap '连线'
    Tap '被剪掉的录音'; Tap '连线'
    $null = Get-Nodes | Where-Object { $_.text -eq '去验证' }
    Tap '去验证'
    Tap '开始这一问'; Tap '沾着白粉的钥匙卡'; Tap '值班表上的涂改'; Tap '提交'
    Expect '可推理' '行动线成立'

    Tap '去判断'
    Expect '证据链不完整' '私下对质灰显并给出原因'
    Shot 'e2e-breach-judge.jpeg'
    Tap '把证据交给纪律组，走流程'
    Tap '确定'
    Expect '《留白》' '进入结局 B'
    Shot 'e2e-breach-ending.jpeg'
}

function Scenario-Slots {
    Say "`n=== 存档 / 读档 / 杀进程恢复 ===" 'Cyan'
    Restart-App
    Ensure-DefaultSettings
    Tap '存档'
    Expect '自动存档' '打开存档页'
    # 只操作「存档槽 1」那一行（纵向 1200–1450），避免点到自动槽
    Tap '存档' 1200
    Start-Sleep 1
    Expect '覆盖' '槽 1 已写入（按钮变覆盖）'
    Tap '读取' 1200
    Start-Sleep 1
    EnsureNot '自动存档在每次调查后更新' '读档后已离开存档页'

    Restart-App
    Expect '线索' '杀进程重启后仍能进游戏'
    Tap '⋯ 更多'
    Start-Sleep 1
    Tap '设置'
    Expect '动画减弱' '设置页可进'
    Tap '动画减弱'
    Start-Sleep 1
    Shot 'e2e-settings.jpeg'
}

# ---------------------------------------------------------------- 入口

Ensure-Device

switch ($Scenario) {
    'happy' { Scenario-Happy }
    'breach' { Scenario-Breach }
    'slots' { Scenario-Slots }
    'all' { Scenario-Happy; Scenario-Breach; Scenario-Slots }
}

Say "`n结果：通过 $script:pass 项，失败 $script:fail 项"
if ($script:fail -gt 0) {
    Say 'RESULT: FAIL' 'Red'
    exit 1
}
Say 'RESULT: PASS' 'Green'
