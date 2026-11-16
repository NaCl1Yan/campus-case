# 无 IDE 跑 Kotlin 领域单测（下载编译器 -> 编译 -> JUnit5 执行）
# 用法（仓库根）：powershell -File tools/run-kotlin-tests.ps1
# 说明：这是 tools/validate.py 之外的第二道真实验证；不替代 Android Studio 的 gradlew，
#       但能在没有 Gradle / 没有 SDK 的机器上跑通同一批 16 个用例。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $toolDir = Join-Path $root '.tools\kotlin'
    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
    $outDir = Join-Path $toolDir 'out'

    $m = 'https://repo1.maven.org/maven2'
    $jars = @(
        @{ n = 'kotlin-compiler-embeddable-2.1.0.jar'; u = "$m/org/jetbrains/kotlin/kotlin-compiler-embeddable/2.1.0/kotlin-compiler-embeddable-2.1.0.jar"; min = 30000000 },
        @{ n = 'kotlin-stdlib-2.1.0.jar'; u = "$m/org/jetbrains/kotlin/kotlin-stdlib/2.1.0/kotlin-stdlib-2.1.0.jar"; min = 1000000 },
        @{ n = 'kotlin-serialization-compiler-plugin-embeddable-2.1.0.jar'; u = "$m/org/jetbrains/kotlin/kotlin-serialization-compiler-plugin-embeddable/2.1.0/kotlin-serialization-compiler-plugin-embeddable-2.1.0.jar"; min = 500000 },
        @{ n = 'kotlinx-serialization-core-jvm-1.7.3.jar'; u = "$m/org/jetbrains/kotlinx/kotlinx-serialization-core-jvm/1.7.3/kotlinx-serialization-core-jvm-1.7.3.jar"; min = 300000 },
        @{ n = 'kotlinx-serialization-json-jvm-1.7.3.jar'; u = "$m/org/jetbrains/kotlinx/kotlinx-serialization-json-jvm/1.7.3/kotlinx-serialization-json-jvm-1.7.3.jar"; min = 200000 },
        @{ n = 'kotlinx-coroutines-core-jvm-1.9.0.jar'; u = "$m/org/jetbrains/kotlinx/kotlinx-coroutines-core-jvm/1.9.0/kotlinx-coroutines-core-jvm-1.9.0.jar"; min = 1000000 },
        @{ n = 'annotations-13.0.jar'; u = "$m/org/jetbrains/annotations/13.0/annotations-13.0.jar"; min = 10000 },
        @{ n = 'trove4j-1.0.20200330.jar'; u = "$m/org/jetbrains/intellij/deps/trove4j/1.0.20200330/trove4j-1.0.20200330.jar"; min = 300000 },
        @{ n = 'junit-jupiter-api-5.11.3.jar'; u = "$m/org/junit/jupiter/junit-jupiter-api/5.11.3/junit-jupiter-api-5.11.3.jar"; min = 100000 },
        @{ n = 'junit-platform-console-standalone-1.11.3.jar'; u = "$m/org/junit/platform/junit-platform-console-standalone/1.11.3/junit-platform-console-standalone-1.11.3.jar"; min = 2000000 }
    )

    foreach ($jar in $jars) {
        $dest = Join-Path $toolDir $jar.n
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -ge $jar.min)) {
            continue
        }
        Write-Host "下载 $($jar.n) ..." -ForegroundColor DarkGray
        curl.exe -sL --max-time 300 -o $dest $jar.u
        if (-not (Test-Path $dest) -or (Get-Item $dest).Length -lt $jar.min) {
            throw "下载失败：$($jar.n)（检查网络/代理后重试）"
        }
    }

    $compilerCp = (@(
            (Join-Path $toolDir 'kotlin-compiler-embeddable-2.1.0.jar'),
            (Join-Path $toolDir 'kotlin-stdlib-2.1.0.jar'),
            (Join-Path $toolDir 'kotlinx-coroutines-core-jvm-1.9.0.jar'),
            (Join-Path $toolDir 'annotations-13.0.jar'),
            (Join-Path $toolDir 'trove4j-1.0.20200330.jar')
        ) -join ';')

    $compileCp = (@(
            (Join-Path $toolDir 'kotlin-stdlib-2.1.0.jar'),
            (Join-Path $toolDir 'kotlinx-serialization-core-jvm-1.7.3.jar'),
            (Join-Path $toolDir 'kotlinx-serialization-json-jvm-1.7.3.jar'),
            (Join-Path $toolDir 'junit-jupiter-api-5.11.3.jar')
        ) -join ';')

    $sources = Get-ChildItem -Recurse -Filter *.kt (Join-Path $root 'android\domain\src') |
        ForEach-Object { $_.FullName }
    Write-Host "编译 $($sources.Count) 个 Kotlin 文件 ..." -ForegroundColor Cyan

    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $pluginPath = Join-Path $toolDir 'kotlin-serialization-compiler-plugin-embeddable-2.1.0.jar'
    & java -cp $compilerCp org.jetbrains.kotlin.cli.jvm.K2JVMCompiler `
        -no-stdlib -no-reflect -jvm-target 17 `
        -classpath $compileCp `
        "-Xplugin=$pluginPath" `
        -d $outDir @sources
    if ($LASTEXITCODE -ne 0) {
        throw "编译失败（exit=$LASTEXITCODE）"
    }

    $runCp = (@(
            $outDir,
            (Join-Path $toolDir 'kotlin-stdlib-2.1.0.jar'),
            (Join-Path $toolDir 'kotlinx-serialization-core-jvm-1.7.3.jar'),
            (Join-Path $toolDir 'kotlinx-serialization-json-jvm-1.7.3.jar'),
            (Join-Path $root 'shared')
        ) -join ';')

    Write-Host '运行 JUnit5 ...' -ForegroundColor Cyan
    & java -jar (Join-Path $toolDir 'junit-platform-console-standalone-1.11.3.jar') `
        --class-path $runCp `
        --scan-class-path $outDir `
        --details=summary `
        --disable-ansi-colors
    $code = $LASTEXITCODE

    "`nRESULT: " + $(if ($code -eq 0) { 'PASS' } else { 'FAIL' })
    exit $code
} finally {
    Pop-Location
}
