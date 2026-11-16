#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
campus-case 内容校验 + 规格自检工具（开发期工具，不打包、不替代两端实现）

用途：
  1. 按 01 文档 FR-16 的校验清单检查 shared/case/*.json（引用完整性、规模下限、可达性）
  2. 用一份"规格参照实现"跑 shared/fixtures/*.json，确认用例与 01 文档 §5.3 的语义一致
     —— 两端引擎（ArkTS / Kotlin）必须对同一批用例给出同样结果（AC-18）

用法：
  python tools/validate.py                 # 校验内容 + 跑全部 fixtures
  python tools/validate.py --content       # 只校验内容
  python tools/validate.py --fixtures      # 只跑 fixtures
  python tools/validate.py -v              # 打印每条用例结果

退出码：0 全部通过；1 有失败。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
CASE_DIR = ROOT / "shared" / "case"
FIXTURE_DIR = ROOT / "shared" / "fixtures"

# Windows 控制台默认 GBK，统一改 UTF-8，避免 ✓/✗ 触发 UnicodeEncodeError
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

STAGES = ["PROLOGUE", "ACCEPT", "EXPLORE", "DEDUCE", "JUDGE", "ENDING", "FINISHED"]
RANK = {s: i for i, s in enumerate(STAGES)}
ALLOWED = {
    "PROLOGUE": {"ACCEPT"},
    "ACCEPT": {"EXPLORE"},
    "EXPLORE": {"EXPLORE", "DEDUCE"},
    "DEDUCE": {"EXPLORE", "JUDGE"},
    "JUDGE": {"DEDUCE", "ENDING"},
    "ENDING": {"FINISHED"},
    "FINISHED": set(),
}


# ---------------------------------------------------------------- 状态


def new_state(**patch: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "caseId": "campus_001",
        "contentVersion": 1,
        "seq": 0,
        "stage": "PROLOGUE",
        "unlockedScenes": [],
        "ownedClues": [],
        "flags": {},
        "closedNodes": [],
        "appliedNodes": [],
        "passedStages": [],
        "finalChoice": None,
        "endingId": None,
    }
    for k, v in patch.items():
        base[k] = v
    return base


def state_from(d: dict[str, Any] | None) -> dict[str, Any]:
    return new_state(**(d or {}))


def seed_default_scenes(case: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    """开局场景（unlockCond 为空）在冷启动/回放时自动可用，不需要流水记录。"""
    for s in case["scenes"]:
        if not s.get("unlockCond"):
            state["unlockedScenes"] = sorted(set(state["unlockedScenes"]) | {s["id"]})
    return state


# ---------------------------------------------------------------- 参照实现（对齐 01 §5.3）


def eval_cond(state: dict[str, Any], cond: dict[str, Any] | None) -> bool:
    if not cond:
        return True
    owned = set(state["ownedClues"])
    flags = state["flags"]
    if not all(c in owned for c in cond.get("allClues", [])):
        return False
    any_c = cond.get("anyClues", [])
    if any_c and not any(c in owned for c in any_c):
        return False
    if not all(flags.get(f) is True for f in cond.get("allFlags", [])):
        return False
    any_f = cond.get("anyFlags", [])
    if any_f and not any(flags.get(f) is True for f in any_f):
        return False
    if any(flags.get(f) is True for f in cond.get("noneFlags", [])):
        return False
    if "minStage" in cond and cond["minStage"]:
        if RANK[state["stage"]] < RANK[cond["minStage"]]:
            return False
    closed = set(state["closedNodes"])
    if any(n in closed for n in cond.get("closedNodes", [])):
        return False
    return True


def node_by_id(case: dict[str, Any], node_id: str) -> dict[str, Any]:
    for n in case["nodes"]:
        if n["id"] == node_id:
            return n
    raise KeyError(f"unknown node {node_id}")


def scene_by_id(case: dict[str, Any], scene_id: str) -> dict[str, Any]:
    for s in case["scenes"]:
        if s["id"] == scene_id:
            return s
    raise KeyError(f"unknown scene {scene_id}")


def is_scene_available(state: dict[str, Any], scene: dict[str, Any]) -> bool:
    if scene["id"] in state["unlockedScenes"]:
        return True
    return eval_cond(state, scene.get("unlockCond"))


def is_node_available(state: dict[str, Any], case: dict[str, Any], node_id: str) -> bool:
    node = node_by_id(case, node_id)
    if node_id in state["closedNodes"]:
        return False
    if node["sceneId"] not in state["unlockedScenes"]:
        return False
    return eval_cond(state, node.get("unlockCond"))


def transit_ok(src: str, dst: str) -> bool:
    if src == dst:
        return True
    return dst in ALLOWED[src]


def apply_node(state: dict[str, Any], case: dict[str, Any], node_id: str) -> dict[str, Any]:
    """返回 {ok, error?, noop?, state}；失败时 state 原样返回。"""
    node = node_by_id(case, node_id)
    if node_id in state["closedNodes"]:
        return {"ok": False, "error": "E_NODE_CLOSED", "state": state}
    if node["sceneId"] not in state["unlockedScenes"]:
        return {"ok": False, "error": "E_NODE_LOCKED", "state": state}
    if not eval_cond(state, node.get("unlockCond")):
        return {"ok": False, "error": "E_NODE_LOCKED", "state": state}
    if not node.get("repeatable", False) and node_id in state["appliedNodes"]:
        return {"ok": True, "noop": True, "state": state}

    effect = node.get("effect", {})
    target_stage = effect.get("stage")
    if target_stage and not transit_ok(state["stage"], target_stage):
        return {"ok": False, "error": "E_STATE_INVALID_TRANSITION", "state": state}

    nxt = new_state(**state)
    nxt["ownedClues"] = sorted(set(state["ownedClues"]) | set(effect.get("grantClues", [])))
    nxt["unlockedScenes"] = sorted(set(state["unlockedScenes"]) | set(effect.get("unlockScenes", [])))
    flags = dict(state["flags"])
    for pair in effect.get("setFlags", []):
        flags[pair[0]] = pair[1]
    nxt["flags"] = flags
    closed = set(state["closedNodes"]) | set(effect.get("closeNodes", [])) | set(node.get("exclusiveWith", []))
    closed.discard(node_id)
    nxt["closedNodes"] = sorted(closed)
    nxt["appliedNodes"] = sorted(set(state["appliedNodes"]) | {node_id})
    if target_stage:
        nxt["stage"] = target_stage
    nxt["seq"] = state["seq"] + 1
    return {"ok": True, "state": nxt}


def check_combine(state: dict[str, Any], case: dict[str, Any], a: str, b: str) -> dict[str, Any]:
    if a == b:
        return {"ok": False, "reason": "SAME_CLUE"}
    owned = set(state["ownedClues"])
    if a not in owned or b not in owned:
        return {"ok": False, "reason": "NOT_OWNED"}
    want = {a, b}
    for rule in case["rules"]:
        if set(rule["inputs"]) == want:
            return {"ok": True, "ruleId": rule["id"], "grantsFlag": rule["grantsFlag"]}
    return {"ok": False, "reason": "NO_RULE"}


def chain_ready(state: dict[str, Any], flag: str) -> bool:
    return state["flags"].get(flag) is True


def choice_allowed(state: dict[str, Any], case: dict[str, Any], choice_id: str) -> bool:
    for fc in case["finalChoices"]:
        if fc["id"] == choice_id:
            return chain_ready(state, fc["requiresFlag"])
    return False


def can_private(state: dict[str, Any]) -> bool:
    return state["flags"].get("proofA") is True and state["flags"].get("tapeFound") is True


def can_public(state: dict[str, Any]) -> bool:
    return state["flags"].get("proofB") is True


def resolve_ending(state: dict[str, Any], case: dict[str, Any]) -> dict[str, Any]:
    pub, pri = can_public(state), can_private(state)
    picked = state.get("finalChoice")
    ending_id = None
    if picked and choice_allowed(state, case, picked):
        for e in case["endings"]:
            if e["choiceId"] == picked:
                # requires 必须同时成立，防伪造
                if eval_cond(state, e.get("requires")):
                    ending_id = e["id"]
    return {
        "canPublic": pub,
        "canPrivate": pri,
        "ready": pub or pri,
        "endingId": ending_id,
    }


def compute_progress(state: dict[str, Any], case: dict[str, Any]) -> float:
    total = max(1, len(case["clues"]))
    ratio = min(1.0, len(set(state["ownedClues"])) / total)
    proofs = int(state["flags"].get("proofA") is True) + int(state["flags"].get("proofB") is True)
    stage = state["stage"]
    if stage == "PROLOGUE":
        return 0.0
    if stage == "ACCEPT":
        return 5.0
    if stage == "EXPLORE":
        return round(min(55.0, max(10.0, 10.0 + 45.0 * ratio)), 1)
    if stage == "DEDUCE":
        return round(min(85.0, max(55.0, 55.0 + 15.0 * proofs)), 1)
    if stage == "JUDGE":
        return 85.0
    if stage == "ENDING":
        return 95.0
    return 100.0


def replay(log: list[dict[str, Any]], case: dict[str, Any], base: dict[str, Any] | None = None) -> dict[str, Any]:
    state = seed_default_scenes(case, state_from(base))
    seen: set[int] = set()
    for entry in log:
        seq = int(entry["seq"])
        if seq in seen:
            continue
        seen.add(seq)
        node = node_by_id(case, entry["nodeId"])
        effect = node.get("effect", {})
        state = new_state(**state)
        state["ownedClues"] = sorted(set(state["ownedClues"]) | set(effect.get("grantClues", [])))
        state["unlockedScenes"] = sorted(set(state["unlockedScenes"]) | set(effect.get("unlockScenes", [])))
        flags = dict(state["flags"])
        for pair in effect.get("setFlags", []):
            flags[pair[0]] = pair[1]
        state["flags"] = flags
        closed = set(state["closedNodes"]) | set(effect.get("closeNodes", [])) | set(node.get("exclusiveWith", []))
        closed.discard(node["id"])
        state["closedNodes"] = sorted(closed)
        state["appliedNodes"] = sorted(set(state["appliedNodes"]) | {node["id"]})
        if effect.get("stage"):
            state["stage"] = effect["stage"]
        state["seq"] = seq
    return state


# ---------------------------------------------------------------- 内容校验（FR-16）


def validate_content(case: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    required = [
        "id", "title", "contentVersion", "brief", "scenes", "nodes", "clues",
        "rules", "chains", "proveStages", "endings", "finalChoices",
    ]
    for k in required:
        if k not in case:
            errors.append(f"缺少顶层字段: {k}")
    if errors:
        return errors

    # 规模下限
    mins = {"scenes": 3, "nodes": 12, "clues": 6, "rules": 3, "chains": 2, "proveStages": 2, "endings": 2}
    for k, n in mins.items():
        if len(case[k]) < n:
            errors.append(f"规模下限不满足: {k} 需 ≥{n}，实际 {len(case[k])}")

    # id 唯一
    for k in ["scenes", "nodes", "clues", "rules", "chains", "proveStages", "endings", "finalChoices"]:
        ids = [x["id"] for x in case[k]]
        if len(ids) != len(set(ids)):
            errors.append(f"{k} 存在重复 id: {ids}")

    scene_ids = {s["id"] for s in case["scenes"]}
    node_ids = {n["id"] for n in case["nodes"]}
    clue_ids = {c["id"] for c in case["clues"]}
    chain_ids = {c["id"] for c in case["chains"]}
    choice_ids = {c["id"] for c in case["finalChoices"]}

    # 场景 → 热点 → 节点
    for s in case["scenes"]:
        if not s.get("hotspots"):
            errors.append(f"场景 {s['id']} 没有热点")
        for h in s.get("hotspots", []):
            if h["nodeId"] not in node_ids:
                errors.append(f"热点 {h['id']} 指向不存在的节点 {h['nodeId']}")
            else:
                node = node_by_id(case, h["nodeId"])
                if node["sceneId"] != s["id"]:
                    errors.append(f"热点 {h['id']} 所在场景 {s['id']} 与节点场景 {node['sceneId']} 不一致")

    # 节点：场景、效果、阶段合法性
    for n in case["nodes"]:
        if n["sceneId"] not in scene_ids:
            errors.append(f"节点 {n['id']} 指向不存在的场景 {n['sceneId']}")
        eff = n.get("effect") or {}
        if not any([eff.get("grantClues"), eff.get("setFlags"), eff.get("unlockScenes"),
                    eff.get("closeNodes"), eff.get("stage")]):
            errors.append(f"节点 {n['id']} 没有任何状态效果（不计入有意义节点）")
        for c in eff.get("grantClues", []):
            if c not in clue_ids:
                errors.append(f"节点 {n['id']} 产出不存在的线索 {c}")
        for sc in eff.get("unlockScenes", []):
            if sc not in scene_ids:
                errors.append(f"节点 {n['id']} 解锁不存在的场景 {sc}")
        for cn in eff.get("closeNodes", []) + n.get("exclusiveWith", []):
            if cn not in node_ids:
                errors.append(f"节点 {n['id']} 关闭不存在的节点 {cn}")
            if cn == n["id"]:
                errors.append(f"节点 {n['id']} 关闭了自己")
        if eff.get("stage") and eff["stage"] not in STAGES:
            errors.append(f"节点 {n['id']} 的阶段 {eff['stage']} 非法")

    # 规则 / 链 / 关卡 / 结局
    for r in case["rules"]:
        for c in r["inputs"]:
            if c not in clue_ids:
                errors.append(f"规则 {r['id']} 引用不存在的线索 {c}")
        if r["chainId"] not in chain_ids:
            errors.append(f"规则 {r['id']} 指向不存在的证据链 {r['chainId']}")
        if len(set(r["inputs"])) != 2:
            errors.append(f"规则 {r['id']} 的两个输入相同")

    for ch in case["chains"]:
        for c in ch["clueIds"]:
            if c not in clue_ids:
                errors.append(f"证据链 {ch['id']} 引用不存在的线索 {c}")
        if not ch.get("ruleFlagIds"):
            errors.append(f"证据链 {ch['id']} 没有规则 flag")

    for p in case["proveStages"]:
        for c in p["answer"]:
            if c not in clue_ids:
                errors.append(f"关卡 {p['id']} 答案引用不存在的线索 {c}")
        if len(p["answer"]) != p["slots"]:
            errors.append(f"关卡 {p['id']} 槽位数 {p['slots']} 与答案数量 {len(p['answer'])} 不一致")

    for e in case["endings"]:
        if e["choiceId"] not in choice_ids:
            errors.append(f"结局 {e['id']} 指向不存在的判断选项 {e['choiceId']}")
        for c in (e.get("requires") or {}).get("allClues", []):
            if c not in clue_ids:
                errors.append(f"结局 {e['id']} 条件引用不存在的线索 {c}")

    # 线索必须可被获得
    produced = {c for n in case["nodes"] for c in (n.get("effect") or {}).get("grantClues", [])}
    for c in clue_ids - produced:
        errors.append(f"线索 {c} 没有任何节点产出（死线索）")

    # 至少一个开局场景
    if not any(not s.get("unlockCond") for s in case["scenes"]):
        errors.append("没有任何场景在开局可用（缺少空 unlockCond 的起始场景）")

    # 结局条件必须互斥（存在一条 flag 只属于其中一个）
    if len(case["endings"]) >= 2:
        sets = [set((e.get("requires") or {}).get("allFlags", [])) for e in case["endings"]]
        if sets[0] == sets[1]:
            errors.append("两个结局的 requires 完全相同，无法形成互斥")

    return errors


def check_reachable(case: dict[str, Any]) -> list[str]:
    """BFS 探索可达状态，检查每个结局都存在一条可达路径（01 §10.2 TC-26 的前置条件）。"""
    errors: list[str] = []

    def key(s: dict[str, Any]) -> tuple:
        return (
            s["stage"],
            tuple(sorted(s["ownedClues"])),
            tuple(sorted(f for f, v in s["flags"].items() if v is True)),
            tuple(sorted(s["closedNodes"])),
            tuple(sorted(s["appliedNodes"])),
        )

    start = seed_default_scenes(case, new_state(stage="ACCEPT"))

    frontier = [start]
    seen = {key(start)}
    states: list[dict[str, Any]] = [start]
    while frontier:
        cur = frontier.pop()
        moves: list[dict[str, Any]] = []
        for n in case["nodes"]:
            r = apply_node(cur, case, n["id"])
            if r.get("ok") and not r.get("noop"):
                moves.append(r["state"])
        for p in case["proveStages"]:
            if eval_cond(cur, p.get("poolCond")) and all(c in cur["ownedClues"] for c in p["answer"]):
                eff = p.get("onPass") or {}
                if not all(cur["flags"].get(f) is True for f in [x[0] for x in eff.get("setFlags", [])]):
                    nxt = new_state(**cur)
                    flags = dict(cur["flags"])
                    for pair in eff.get("setFlags", []):
                        flags[pair[0]] = pair[1]
                    nxt["flags"] = flags
                    nxt["passedStages"] = sorted(set(cur["passedStages"]) | {p["id"]})
                    moves.append(nxt)
        for mv in moves:
            k = key(mv)
            if k in seen:
                continue
            seen.add(k)
            states.append(mv)
            frontier.append(mv)

    for e in case["endings"]:
        ok = any(eval_cond(s, e.get("requires")) for s in states)
        if not ok:
            errors.append(f"结局 {e['id']} 在可达状态中不成立（无法达成）")

    # 分支真实性：存在"一条链成立、另一条不成立"的可达状态
    diverge = any(
        (can_public(s) and not can_private(s)) or (can_private(s) and not can_public(s))
        for s in states
    )
    if not diverge:
        errors.append("不存在『只有一条证据链成立』的可达状态，分支可能未真实生效")
    return errors


# ---------------------------------------------------------------- fixtures


def canon(value: Any) -> Any:
    if isinstance(value, list):
        return sorted(canon(v) for v in value)
    if isinstance(value, dict):
        return {k: canon(v) for k, v in value.items()}
    return value


def compare_partial(actual: dict[str, Any], expect: dict[str, Any], path: str, errors: list[str]) -> None:
    for k, want in expect.items():
        if k not in actual:
            errors.append(f"{path}: 结果缺少字段 {k}")
            continue
        got = actual[k]
        if isinstance(want, dict):
            if not isinstance(got, dict):
                errors.append(f"{path}.{k}: 期望对象，实际 {got!r}")
                continue
            compare_partial(got, want, f"{path}.{k}", errors)
        elif isinstance(want, list):
            if canon(got) != canon(want):
                errors.append(f"{path}.{k}: 期望 {canon(want)}，实际 {canon(got)}")
        elif isinstance(want, (int, float)) and not isinstance(want, bool):
            if abs(float(got) - float(want)) > 1e-6:
                errors.append(f"{path}.{k}: 期望 {want}，实际 {got}")
        else:
            if got != want:
                errors.append(f"{path}.{k}: 期望 {want!r}，实际 {got!r}")


def run_fixtures(case: dict[str, Any], verbose: bool) -> tuple[int, int, list[str]]:
    total = passed = 0
    failures: list[str] = []
    for path in sorted(FIXTURE_DIR.glob("*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        kind = doc["kind"]
        for c in doc["cases"]:
            total += 1
            errs: list[str] = []
            given = c["given"]
            expect = c["expect"]
            if kind == "gate":
                got = {"available": is_node_available(state_from(given["state"]), case, given["nodeId"])}
                compare_partial(got, expect, c["id"], errs)
            elif kind == "sceneGate":
                got = {"available": is_scene_available(state_from(given["state"]), scene_by_id(case, given["sceneId"]))}
                compare_partial(got, expect, c["id"], errs)
            elif kind == "apply":
                res = apply_node(state_from(given["state"]), case, given["nodeId"])
                got: dict[str, Any] = {"ok": res["ok"]}
                if res.get("error"):
                    got["error"] = res["error"]
                if res.get("noop"):
                    got["noop"] = True
                if "state" in expect:
                    got["state"] = res["state"]
                compare_partial(got, expect, c["id"], errs)
            elif kind == "combine":
                got = check_combine(state_from(given["state"]), case, given["a"], given["b"])
                compare_partial(got, expect, c["id"], errs)
            elif kind == "ending":
                got = resolve_ending(state_from(given["state"]), case)
                compare_partial(got, expect, c["id"], errs)
            elif kind == "progress":
                got = {"progress": compute_progress(state_from(given["state"]), case)}
                compare_partial(got, expect, c["id"], errs)
            elif kind == "replay":
                got = {"state": replay(given["log"], case)}
                compare_partial(got, expect, c["id"], errs)
            else:
                errs.append(f"未知 fixtures 类型 {kind}")

            if errs:
                failures.append(f"✗ {c['id']}（{path.name}）: " + "; ".join(errs))
            else:
                passed += 1
                if verbose:
                    print(f"✓ {c['id']}")
    return total, passed, failures


# ---------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--content", action="store_true", help="只校验内容")
    ap.add_argument("--fixtures", action="store_true", help="只跑 fixtures")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    do_content = args.content or not args.fixtures
    do_fixtures = args.fixtures or not args.content

    case_path = CASE_DIR / "campus_001.json"
    case = json.loads(case_path.read_text(encoding="utf-8"))
    failures: list[str] = []
    rc = 0

    if do_content:
        print(f"== 内容校验：{case_path.relative_to(ROOT)} ==")
        errs = validate_content(case) + check_reachable(case)
        if errs:
            rc = 1
            for e in errs:
                print(f"✗ {e}")
        else:
            print("✓ 引用完整性 / 规模下限 / 可达性 / 分支互斥 全部通过")

    if do_fixtures:
        print("== 规格自检：shared/fixtures/*.json ==")
        total, passed, fx_failures = run_fixtures(case, args.verbose)
        for f in fx_failures:
            print(f)
        print(f"{passed}/{total} 用例通过")
        if fx_failures:
            rc = 1

    print("RESULT: " + ("PASS" if rc == 0 else "FAIL"))
    return rc


if __name__ == "__main__":
    sys.exit(main())
