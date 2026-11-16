#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 shared/fixtures 下的判定用例生成为带类型的 ArkTS 常量。

为什么要生成：ArkTS 侧解析动态 JSON 又啰嗦又容易踩类型限制；把用例转成
强类型对象后，Hypium 只需要遍历数组做断言，两端跑的是同一批用例（AC-18）。

生成物：harmony/entry/src/ohosTest/ets/test/Fixtures.generated.ets
  - 入库（这样打开 DevEco 就能直接跑测试）
  - 文件头有 @generated 标记；用 --check 模式校验是否与 fixtures 漂移

用法：
  python tools/gen_fixtures_ets.py            # 生成/覆盖
  python tools/gen_fixtures_ets.py --check    # 只校验，漂移则退出码 1
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
FIXTURE_DIR = ROOT / "shared" / "fixtures"
OUT = ROOT / "harmony" / "entry" / "src" / "ohosTest" / "ets" / "test" / "Fixtures.generated.ets"

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


def scalar(value: Any) -> str | None:
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return f"{value}"
    return None


def emit_value(value: Any, indent: int) -> str:
    simple = scalar(value)
    if simple is not None:
        return simple
    if isinstance(value, dict):
        return obj(value, indent)
    if isinstance(value, list):
        if not value:
            return "[]"
        if all(scalar(v) is not None for v in value):
            return "[" + ", ".join(scalar(v) or "null" for v in value) + "]"
        pad = " " * (indent + 2)
        close = " " * indent
        items = [pad + emit_value(v, indent + 2) for v in value]
        return "[\n" + ",\n".join(items) + "\n" + close + "]"
    raise TypeError(f"不支持的字面量类型: {type(value)}")


def flags_list(flags: dict[str, Any] | None) -> list[dict[str, Any]]:
    if not flags:
        return []
    return [{"key": k, "value": v} for k, v in flags.items()]


def state_patch(state: dict[str, Any] | None) -> dict[str, Any]:
    s = state or {}
    return {
        "stage": s.get("stage", "PROLOGUE"),
        "unlockedScenes": s.get("unlockedScenes", []),
        "ownedClues": s.get("ownedClues", []),
        "flags": flags_list(s.get("flags")),
        "closedNodes": s.get("closedNodes", []),
        "appliedNodes": s.get("appliedNodes", []),
        "seq": s.get("seq", 0),
        "finalChoice": s.get("finalChoice"),
        "endingId": s.get("endingId"),
    }


STATE_FIELDS = ("stage", "unlockedScenes", "ownedClues", "closedNodes", "appliedNodes", "seq", "finalChoice", "endingId")


def state_expect(state: dict[str, Any] | None) -> dict[str, Any]:
    """只保留期望里出现的字段（其余为 undefined，按部分匹配语义）。"""
    s = state or {}
    out: dict[str, Any] = {}
    for key in STATE_FIELDS:
        if key in s:
            out[key] = s[key]
    if "flags" in s:
        out["flags"] = flags_list(s["flags"])
    return out


def obj(data: dict[str, Any], indent: int) -> str:
    pad = " " * indent
    inner = " " * (indent + 2)
    lines = [
        f"{inner}{key}: {emit_value(value, indent + 2)},"
        for key, value in data.items()
    ]
    return "{\n" + "\n".join(lines) + f"\n{pad}}}"


def build_cases() -> dict[str, list[dict[str, Any]]]:
    buckets: dict[str, list[dict[str, Any]]] = {
        "GATE_CASES": [],
        "SCENE_CASES": [],
        "APPLY_CASES": [],
        "COMBINE_CASES": [],
        "ENDING_CASES": [],
        "PROGRESS_CASES": [],
        "REPLAY_CASES": [],
    }

    for path in sorted(FIXTURE_DIR.glob("*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        kind = doc["kind"]
        for case in doc["cases"]:
            cid = case["id"]
            desc = case.get("desc", "")
            given = case.get("given", {})
            expect = case.get("expect", {})

            if kind == "gate":
                buckets["GATE_CASES"].append({
                    "id": cid, "desc": desc,
                    "nodeId": given["nodeId"],
                    "state": state_patch(given.get("state")),
                    "expectAvailable": expect["available"],
                })
            elif kind == "sceneGate":
                buckets["SCENE_CASES"].append({
                    "id": cid, "desc": desc,
                    "sceneId": given["sceneId"],
                    "state": state_patch(given.get("state")),
                    "expectAvailable": expect["available"],
                })
            elif kind == "apply":
                buckets["APPLY_CASES"].append({
                    "id": cid, "desc": desc,
                    "nodeId": given["nodeId"],
                    "state": state_patch(given.get("state")),
                    "expectOk": expect["ok"],
                    "expectError": expect.get("error"),
                    "expectNoop": expect.get("noop", False),
                    "expectState": state_expect(expect.get("state")) or None,
                })
            elif kind == "combine":
                buckets["COMBINE_CASES"].append({
                    "id": cid, "desc": desc,
                    "a": given["a"], "b": given["b"],
                    "state": state_patch(given.get("state")),
                    "expectOk": expect["ok"],
                    "expectRuleId": expect.get("ruleId"),
                    "expectGrantsFlag": expect.get("grantsFlag"),
                    "expectReason": expect.get("reason"),
                })
            elif kind == "ending":
                buckets["ENDING_CASES"].append({
                    "id": cid, "desc": desc,
                    "state": state_patch(given.get("state")),
                    "expectCanPublic": expect["canPublic"],
                    "expectCanPrivate": expect["canPrivate"],
                    "expectReady": expect["ready"],
                    "expectEndingId": expect.get("endingId"),
                })
            elif kind == "progress":
                buckets["PROGRESS_CASES"].append({
                    "id": cid, "desc": desc,
                    "state": state_patch(given.get("state")),
                    "expectProgress": expect["progress"],
                })
            elif kind == "replay":
                buckets["REPLAY_CASES"].append({
                    "id": cid, "desc": desc,
                    "log": given["log"],
                    "expectState": state_expect(expect.get("state")),
                })
            else:
                raise SystemExit(f"未知 fixtures 类型 {kind}（{path.name}）")

    return buckets


HEADER = """// @generated by tools/gen_fixtures_ets.py —— 请勿手改
// 源：shared/fixtures/*.json（唯一真源）；重新生成：python tools/gen_fixtures_ets.py
// 用途：鸿蒙侧 Hypium 跑同一批判定用例（AC-18 双端一致性）

export interface FlagPair {
  key: string;
  value: boolean;
}

/** 输入态：缺省字段由 stateFromPatch 填默认值 */
export interface StatePatch {
  stage: string;
  unlockedScenes: string[];
  ownedClues: string[];
  flags: FlagPair[];
  closedNodes: string[];
  appliedNodes: string[];
  seq: number;
  finalChoice: string | null;
  endingId: string | null;
}

/** 期望态：只比较出现过的字段（部分匹配） */
export interface StateExpect {
  stage?: string;
  unlockedScenes?: string[];
  ownedClues?: string[];
  flags?: FlagPair[];
  closedNodes?: string[];
  appliedNodes?: string[];
  seq?: number;
  finalChoice?: string | null;
  endingId?: string | null;
}

export interface GateCase {
  id: string;
  desc: string;
  nodeId: string;
  state: StatePatch;
  expectAvailable: boolean;
}

export interface SceneCase {
  id: string;
  desc: string;
  sceneId: string;
  state: StatePatch;
  expectAvailable: boolean;
}

export interface ApplyCase {
  id: string;
  desc: string;
  nodeId: string;
  state: StatePatch;
  expectOk: boolean;
  expectError: string | null;
  expectNoop: boolean;
  expectState: StateExpect | null;
}

export interface CombineCase {
  id: string;
  desc: string;
  a: string;
  b: string;
  state: StatePatch;
  expectOk: boolean;
  expectRuleId: string | null;
  expectGrantsFlag: string | null;
  expectReason: string | null;
}

export interface EndingCase {
  id: string;
  desc: string;
  state: StatePatch;
  expectCanPublic: boolean;
  expectCanPrivate: boolean;
  expectReady: boolean;
  expectEndingId: string | null;
}

export interface ProgressCase {
  id: string;
  desc: string;
  state: StatePatch;
  expectProgress: number;
}

export interface ReplayCase {
  id: string;
  desc: string;
  log: LogStep[];
  expectState: StateExpect;
}

export interface LogStep {
  seq: number;
  nodeId: string;
}
"""


def render() -> str:
    buckets = build_cases()
    parts = [HEADER]
    counts: list[str] = []

    def emit(name: str, type_name: str, items: list[dict[str, Any]]) -> None:
        parts.append(f"\nexport const {name}: {type_name}[] = [")
        for item in items:
            parts.append("  " + obj(item, 2) + ",")
        parts.append("];")
        counts.append(f"{name}={len(items)}")

    emit("GATE_CASES", "GateCase", buckets["GATE_CASES"])
    emit("SCENE_CASES", "SceneCase", buckets["SCENE_CASES"])
    emit("APPLY_CASES", "ApplyCase", buckets["APPLY_CASES"])
    emit("COMBINE_CASES", "CombineCase", buckets["COMBINE_CASES"])
    emit("ENDING_CASES", "EndingCase", buckets["ENDING_CASES"])
    emit("PROGRESS_CASES", "ProgressCase", buckets["PROGRESS_CASES"])
    emit("REPLAY_CASES", "ReplayCase", buckets["REPLAY_CASES"])

    total = sum(len(v) for v in buckets.values())
    parts.append(f"\nexport const FIXTURE_TOTAL: number = {total};")
    parts.append("")
    print("生成用例：" + ", ".join(counts) + f"，合计 {total}")
    return "\n".join(parts)


def main() -> int:
    check = "--check" in sys.argv
    text = render()

    if check:
        if not OUT.exists():
            print(f"✗ 缺少生成物：{OUT.relative_to(ROOT).as_posix()}")
            return 1
        current = OUT.read_text(encoding="utf-8")
        if current != text:
            print("✗ 生成物与 shared/fixtures 不一致，请重新运行 python tools/gen_fixtures_ets.py")
            return 1
        print("✓ 生成物与 fixtures 一致")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"写入 {OUT.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
