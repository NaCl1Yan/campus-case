#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""离线预检：把"打开 IDE 才会暴露"的问题尽量提前查出来。

检查项：
  1. 配置语法     所有 .json / .json5（去注释后）能被解析
  2. HarmonyOS    module.json5 / app.json5 必填字段；srcEntry 文件存在
  3. 资源引用     $string: / $color: / $media: / $profile: 在对应模块内可解析
  4. 页面清单     main_pages.json 列出的页面文件存在
  5. 跨端符号     Kotlin / ArkTS 里调用的 Engine.* / CaseLoader.* 是否真的声明过
  6. 类型导入     ArkTS 从 ./Types 导入的名字是否真的导出
  7. Gradle 目录  libs.<alias> / libs.plugins.<alias> 是否在 libs.versions.toml 里
  8. Python 工具  可编译（py_compile）

用法：python tools/preflight.py [-v]
退出码：0 全通过；1 有 FAIL（WARN 不影响退出码）
"""

from __future__ import annotations

import json
import py_compile
import subprocess
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent

# 第三方/构建产物目录：这些目录里的源码不参与本仓库的静态检查
VENDORED = {'.hvigor', 'oh_modules', '.ohpm', 'build', 'node_modules', '.tools'}


def is_vendored(path: Path) -> bool:
    return any(part in VENDORED for part in path.parts)
VERBOSE = "-v" in sys.argv

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

results: list[tuple[str, str, str]] = []  # (level, check, message)


def ok(check: str, msg: str) -> None:
    results.append(("PASS", check, msg))


def warn(check: str, msg: str) -> None:
    results.append(("WARN", check, msg))


def fail(check: str, msg: str) -> None:
    results.append(("FAIL", check, msg))


# ---------------------------------------------------------------- 1. JSON / JSON5


def strip_json5(text: str) -> str:
    """去掉 // 与 /* */ 注释（跳过字符串内部），并去掉尾随逗号。"""
    out: list[str] = []
    i, n = 0, len(text)
    in_str = False
    quote = ""
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == quote:
                in_str = False
            i += 1
            continue
        if ch in "\"'":
            in_str = True
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    cleaned = "".join(out)
    cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return cleaned


def load_json_config(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    # JSON 严格；JSON5 需要去注释/尾逗号
    if path.suffix == ".json5":
        return json.loads(strip_json5(text))
    return json.loads(text)


def check_configs() -> dict[str, Any]:
    configs: dict[str, Any] = {}
    targets = sorted(ROOT.glob("harmony/**/*.json")) + sorted(ROOT.glob("harmony/**/*.json5"))
    targets += sorted(ROOT.glob("shared/**/*.json"))
    for path in targets:
        if is_vendored(path):
            continue
        rel = path.relative_to(ROOT).as_posix()
        try:
            data = load_json_config(path)
            configs[rel] = data
        except Exception as exc:  # noqa: BLE001
            fail("1 配置语法", f"{rel}: {exc}")
    if not any(level == "FAIL" and check == "1 配置语法" for level, check, _ in results):
        ok("1 配置语法", f"{len(configs)} 个 JSON/JSON5 文件全部可解析")
    return configs


# ---------------------------------------------------------------- 2/3/4 HarmonyOS 配置


def resource_index() -> dict[str, set[str]]:
    """按模块收集 $string / $color / $media / $profile 的可用名。"""
    index: dict[str, dict[str, set[str]]] = {}

    def bucket(scope: str) -> dict[str, set[str]]:
        return index.setdefault(scope, {"string": set(), "color": set(), "media": set(), "profile": set()})

    for elem in ROOT.glob("harmony/**/resources/base/element/*.json"):
        scope = elem.relative_to(ROOT).parts[1]  # AppScope 或 entry
        kind = elem.stem  # string / color
        try:
            data = json.loads(elem.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            continue
        for item in data.get(kind, []):
            bucket(scope)[kind].add(item["name"])

    for media in ROOT.glob("harmony/**/resources/base/media/*"):
        scope = media.relative_to(ROOT).parts[1]
        bucket(scope)["media"].add(media.stem)

    for profile in ROOT.glob("harmony/**/resources/base/profile/*.json"):
        scope = profile.relative_to(ROOT).parts[1]
        bucket(scope)["profile"].add(profile.stem)

    return index


REF = re.compile(r"\$(string|color|media|profile):([A-Za-z0-9_]+)")


def check_harmony(configs: dict[str, Any]) -> None:
    if "harmony/AppScope/app.json5" not in configs:
        fail("2 鸿蒙配置", "缺少 AppScope/app.json5")
        return
    if "harmony/entry/src/main/module.json5" not in configs:
        fail("2 鸿蒙配置", "缺少 entry/src/main/module.json5")
        return

    app = configs["harmony/AppScope/app.json5"]["app"]
    for key in ("bundleName", "vendor", "versionCode", "versionName", "icon", "label"):
        if key not in app:
            fail("2 鸿蒙配置", f"app.json5 缺字段 {key}")
    if not app.get("bundleName", "").count(".") >= 2:
        fail("2 鸿蒙配置", f"bundleName 不合法: {app.get('bundleName')}")

    module = configs["harmony/entry/src/main/module.json5"]["module"]
    for key in ("name", "type", "deviceTypes", "pages", "abilities"):
        if key not in module:
            fail("2 鸿蒙配置", f"module.json5 缺字段 {key}")
    if module.get("requestPermissions"):
        warn("2 鸿蒙配置", "module.json5 声明了权限——本项目要求零权限（01 §2.6）")

    for ability in module.get("abilities", []):
        src = ability.get("srcEntry", "")
        path = (ROOT / "harmony/entry/src/main" / src.lstrip("./")).resolve()
        if not path.exists():
            fail("2 鸿蒙配置", f"ability {ability.get('name')} 的 srcEntry 不存在: {src}")
    ok("2 鸿蒙配置", "app.json5 / module.json5 必填字段与 srcEntry 齐全")

    # 3. 资源引用
    index = resource_index()
    unresolved = 0
    for rel, data in configs.items():
        if not rel.startswith("harmony/"):
            continue
        if "/src/" not in rel and "AppScope" not in rel:
            continue
        scope = rel.split("/")[1]
        available = index.get(scope) or index.get("entry", {"string": set(), "color": set(), "media": set(), "profile": set()})
        text = json.dumps(data, ensure_ascii=False)
        for kind, name in REF.findall(text):
            if name not in available.get(kind, set()):
                fail("3 资源引用", f"{rel}: ${kind}:{name} 在 {scope} 资源里不存在")
                unresolved += 1
    if unresolved == 0:
        ok("3 资源引用", "全部 $string/$color/$media/$profile 均可解析")

    # 4. 页面清单
    pages_profile = ROOT / "harmony/entry/src/main/resources/base/profile/main_pages.json"
    if pages_profile.exists():
        pages = json.loads(pages_profile.read_text(encoding="utf-8")).get("src", [])
        missing = 0
        for page in pages:
            candidate = ROOT / "harmony/entry/src/main/ets" / f"{page}.ets"
            if not candidate.exists():
                fail("4 页面清单", f"main_pages 里的 {page} 缺少对应文件 {candidate.name}")
                missing += 1
        if missing == 0:
            ok("4 页面清单", f"{len(pages)} 个页面文件均存在")
    else:
        fail("4 页面清单", "缺少 main_pages.json")


# ---------------------------------------------------------------- 5/6 跨端符号


def declared_members(path: Path, keywords: tuple[str, ...]) -> set[str]:
    """从源码里抽取 `keyword name(` 形式的声明名。"""
    text = path.read_text(encoding="utf-8")
    names: set[str] = set()
    for kw in keywords:
        names |= set(re.findall(rf"\b{kw}\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text))
    return names


def called_members(path: Path, holder: str) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(rf"\b{holder}\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", text))


def check_kotlin_symbols() -> None:
    engine_path = ROOT / "android/domain/src/main/kotlin/com/nacl1yan/campuscase/domain/Engine.kt"
    loader_path = ROOT / "android/domain/src/main/kotlin/com/nacl1yan/campuscase/domain/CaseLoader.kt"
    if not engine_path.exists() or not loader_path.exists():
        fail("5 跨端符号", "Kotlin 引擎文件缺失")
        return

    engine_fns = declared_members(engine_path, ("fun",))
    loader_fns = declared_members(loader_path, ("fun",))

    # 属性（如 canPublic）用的是 val/fun；这里把 fun 已覆盖
    bad = 0
    for src in ROOT.glob("android/**/*.kt"):
        for holder, declared in (("Engine", engine_fns), ("CaseLoader", loader_fns)):
            for name in called_members(src, holder):
                if name not in declared:
                    fail("5 跨端符号", f"{src.relative_to(ROOT).as_posix()}: {holder}.{name} 未在 {holder} 中声明")
                    bad += 1
    if bad == 0:
        ok("5 跨端符号", f"Kotlin 调用点全部命中（Engine {len(engine_fns)} 个函数，CaseLoader {len(loader_fns)} 个）")


EXPORT_RE = re.compile(
    r"export\s+(?:interface|class|enum|function|type|const|let)\s+([A-Za-z_][A-Za-z0-9_]*)"
)


def exports_of(path: Path) -> set[str]:
    return set(EXPORT_RE.findall(path.read_text(encoding="utf-8")))


def check_arkts_imports() -> None:
    """ArkTS 的相对导入必须指向真实文件，且导入的名字确实是对方的导出。"""
    bad = 0
    for src in [p for p in ROOT.glob("harmony/**/*.ets") if not is_vendored(p)]:
        text = src.read_text(encoding="utf-8")
        for block, target in re.findall(r"import\s*\{([^}]*)\}\s*from\s*'(\.[^']*)'", text):
            rel = src.relative_to(ROOT).as_posix()
            if target.endswith(".ets"):
                cand = (src.parent / target).resolve()
            else:
                cand = (src.parent / (target + ".ets")).resolve()
            if not cand.exists():
                fail("6 ArkTS 导入", f"{rel}: 导入的文件不存在 {target}")
                bad += 1
                continue
            declared = exports_of(cand)
            for raw in block.split(","):
                name = raw.strip().split(" as ")[0].strip()
                if not name or name in {"type"}:
                    continue
                if name not in declared:
                    fail("6 ArkTS 导入", f"{rel}: 从 {target} 导入了未导出的 {name}")
                    bad += 1
    if bad == 0:
        ok("6 ArkTS 导入", "相对导入的文件与符号均存在")


def check_generated_fixtures() -> None:
    """鸿蒙侧 fixtures 常量是生成物：必须存在且与 shared/fixtures 一致。"""
    generator = ROOT / "tools/gen_fixtures_ets.py"
    output = ROOT / "harmony/entry/src/ohosTest/ets/test/Fixtures.generated.ets"
    if not generator.exists():
        fail("9 Fixtures 生成物", "缺少 tools/gen_fixtures_ets.py")
        return
    if not output.exists():
        fail("9 Fixtures 生成物", "缺少 Fixtures.generated.ets，请运行 python tools/gen_fixtures_ets.py")
        return
    proc = subprocess.run(
        [sys.executable, str(generator), "--check"],
        cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8",
    )
    if proc.returncode != 0:
        detail = (proc.stdout or proc.stderr or "").strip().splitlines()
        fail("9 Fixtures 生成物", detail[-1] if detail else "生成物漂移")
        return
    size_kb = round(output.stat().st_size / 1024, 1)
    ok("9 Fixtures 生成物", f"与 shared/fixtures 一致（{size_kb} KB）")


def check_arkts_symbols() -> None:
    engine_path = ROOT / "harmony/entry/src/main/ets/domain/Engine.ets"
    loader_path = ROOT / "harmony/entry/src/main/ets/domain/CaseLoader.ets"
    if not all(p.exists() for p in (engine_path, loader_path)):
        fail("5 跨端符号", "ArkTS 引擎文件缺失")
        return

    engine_fns = declared_members(engine_path, ("static",))
    loader_fns = declared_members(loader_path, ("static",))
    bad = 0
    for src in [p for p in ROOT.glob("harmony/**/*.ets") if not is_vendored(p)]:
        for holder, declared in (("Engine", engine_fns), ("CaseLoader", loader_fns)):
            for name in called_members(src, holder):
                if name not in declared:
                    fail("5 跨端符号", f"{src.relative_to(ROOT).as_posix()}: {holder}.{name} 未在 {holder} 中声明")
                    bad += 1
    if bad == 0:
        ok("5 跨端符号", f"ArkTS 调用点全部命中（Engine {len(engine_fns)} 个，CaseLoader {len(loader_fns)} 个）")


# ---------------------------------------------------------------- 7 Gradle 目录


def check_gradle_catalog() -> None:
    catalog = ROOT / "android/gradle/libs.versions.toml"
    if not catalog.exists():
        fail("7 Gradle 目录", "缺少 libs.versions.toml")
        return
    text = catalog.read_text(encoding="utf-8")
    section = ""
    raw_aliases: dict[str, set[str]] = {"libraries": set(), "plugins": set()}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section in raw_aliases:
            match = re.match(r"([A-Za-z0-9_.-]+)\s*=", line)
            if match:
                raw_aliases[section].add(match.group(1))

    # 版本目录访问器规则：`-` 与 `_` 都映射成 `.`
    def accessor(alias: str) -> str:
        return alias.replace("-", ".").replace("_", ".")

    aliases = {kind: {accessor(a) for a in names} for kind, names in raw_aliases.items()}

    bad = 0
    for build_file in ROOT.glob("android/**/build.gradle.kts"):
        source = build_file.read_text(encoding="utf-8")
        for ref in re.findall(r"libs\.plugins\.([a-zA-Z0-9_.]+)", source):
            if ref not in aliases["plugins"]:
                fail("7 Gradle 目录", f"{build_file.relative_to(ROOT).as_posix()}: libs.plugins.{ref} 未定义")
                bad += 1
        for ref in re.findall(r"libs\.((?!plugins\.)[a-zA-Z0-9_.]+)", source):
            if ref not in aliases["libraries"]:
                fail("7 Gradle 目录", f"{build_file.relative_to(ROOT).as_posix()}: libs.{ref} 未定义")
                bad += 1
    if bad == 0:
        ok("7 Gradle 目录", "构建脚本引用的插件与依赖别名均已定义")


# ---------------------------------------------------------------- 8 Python 工具


def check_python_tools() -> None:
    bad = 0
    for tool in [ROOT / "tools/validate.py", ROOT / "tools/preflight.py"]:
        if not tool.exists():
            continue
        try:
            py_compile.compile(str(tool), doraise=True)
        except py_compile.PyCompileError as exc:
            fail("8 Python 工具", f"{tool.name}: {exc}")
            bad += 1
    if bad == 0:
        ok("8 Python 工具", "tools/*.py 均可编译")


# ---------------------------------------------------------------- main


def main() -> int:
    if not (ROOT / "harmony").exists() or not (ROOT / "android").exists():
        print("请在仓库根目录运行（需要同时存在 harmony/ 与 android/）")
        return 1

    configs = check_configs()
    check_harmony(configs)
    check_kotlin_symbols()
    check_arkts_symbols()
    check_arkts_imports()
    check_gradle_catalog()
    check_python_tools()
    check_generated_fixtures()

    fails = [r for r in results if r[0] == "FAIL"]
    warns = [r for r in results if r[0] == "WARN"]

    for level, check, msg in results:
        if level == "PASS":
            if VERBOSE:
                print(f"✓ {check}: {msg}")
        else:
            print(f"{'✗' if level == 'FAIL' else '!'} {check}: {msg}")

    print()
    print(f"PASS {sum(1 for r in results if r[0] == 'PASS')} / WARN {len(warns)} / FAIL {len(fails)}")
    print("RESULT: " + ("PASS" if not fails else "FAIL"))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
