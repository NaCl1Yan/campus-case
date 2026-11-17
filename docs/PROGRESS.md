# 进度与明日待办
## 《钟楼七点》鸿蒙版 · 2026-11-16 收工快照

> 最近更新：2026-11-17 19:45（Asia/Shanghai）
> 分支：`main`；里程碑 tag：`v0.9.0-playable`（后续改动已在其后追加）
> 仓库位置：**`E:\campus-case`**（2026-11-17 从 `E:\校园推理galgame` 迁出，见 §3.6）

---

## 1. 今天做完了什么

| 模块 | 状态 | 证据 |
| --- | --- | --- |
| 真实剧情内容《钟楼七点》 | ✅ 4 场景 / 12 节点 / 6 线索 / 3 规则 / 2 关卡 / 2 结局 | `shared/case/campus_001.json`；`tools/validate.py` 42/42 |
| 判定引擎（ArkTS） | ✅ 门控/效果/连线/结局/进度/回放，纯函数 | `entry/src/main/ets/domain/`；编译通过 |
| 持久化 | ✅ Preferences（快照/设置）+ RDB 五表 + `t_ending_seen` | `entry/src/main/ets/store/` |
| 界面 | ✅ 简报 / 地图 / 场景 / 线索板 / 推理 / 判断 / 结局 / 存档 / 收集册 / 设置 | `entry/src/main/ets/view/` + `pages/Index.ets` |
| HUD 与动画 | ✅ 阶段、目标、线索、双链、进度环、6 类动画 | `view/HudBar.ets` 等 |
| 冷启动恢复 | ✅ 自动槽 → 快照 → 流水回放；杀进程实测停在「已完结 100%」 | `store/GameController.ets::restore` |
| 演示流水线 | ✅ 三条链路 24 项断言全部通过 | `tools/e2e.ps1`；截图 `docs/screenshots/e2e-*.jpeg` |
| 文档 | ✅ 需求 / 内容 / Android（冻结）/ 编译检查单 / 演示对照 / 测试报告 | `docs/` |

**最近的关键提交**

```
ffc2557 test(e2e): 三条演示链路脚本化并实测通过（24 项断言）
a0ee2d7 feat(tools): 演示流水线脚本 e2e.ps1
f6c3039 feat(harmony): 删除存档二次确认、场景氛围色、内容校验结果可见
9e9b42b feat(harmony): 结局收集册、设置页、返回键拦截、线索板结论区
669260f feat(harmony): 完整可玩版本（真实剧情 + 七页 UI + Preferences/RDB + 冷启动恢复）
```

---

## 2. 明天接着做（按优先级）

| # | 事项 | 为什么 | 预计 |
| --- | --- | --- | --- |
| 1 | **在 DevEco 里跑一次 Hypium**：右键 `entry/src/ohosTest/ets/test` → Run 'Tests in test' | 22 个用例是作业「单元测试」项的唯一缺口（命令行下 Hypium 不推进，原因见 `docs/04`）；路径已迁到 ASCII，IDE 现在能直接打开 `E:\campus-case\harmony` | 2 分钟 |
| 2 | 录一段 3 分钟演示或导出 GIF 放 `docs/` | 交作业/答辩时不用现场点 | 半小时 |
| 3 | 内容加料（可选）：第 5 个场景或第 3 个结局 | 分值上限更高，但要同步 02/05 与 fixtures | 半天 |
| 4 | 代码注释与类图（可选） | 交作业时"设计说明"更完整 | 1 小时 |

---

## 3. 明天开工只需要三条命令

```powershell
# 1) 看当前状态（应显示 working tree clean）
git status --short --branch

# 2) 确认环境没坏（模拟器在线时再跑 e2e）
python tools/preflight.py
python tools/validate.py

# 3) 编译（改代码后必跑）
powershell -File tools/build-harmony.ps1
```

模拟器如果又掉线：DevEco → **Device Manager** 启动 `Huawei_Phone`，然后

```powershell
& 'D:\huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' tconn 127.0.0.1:5555
```

装包与启动（未签名 HAP 可以直接装）：

```powershell
$hdc = 'D:\huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hap = 'E:\campus-case\harmony\entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc install -r $hap
& $hdc shell aa start -a EntryAbility -b com.nacl1yan.campuscase
```

---

## 3.5 已完成（2026-11-17 追加）

- 线索板**证据链图**（`view/ChainGraph.ets`，Canvas）：R1/R2/R3 连线，成立变绿，实测截图 `07-chaingraph.jpeg`
- HUD 增加**简报**入口（随时复盘委托）
- **字号缩放三档**（1.0/1.2/1.5）：11 个视图统一 `@Prop fs`，Preferences 持久化，实测重启保持
- 设置/收集册补 HUD 返回键
- 修：`@Watch` 必须挂变量；`Set-Content -NoNewline` 会把数组拼成一行（踩了一次）

### 19:05 追加

- 大字号（1.5）实测暴露真实可用性问题：简报主按钮被挤出屏幕、线索板第二行卡片压到按钮下方
  → 简报与线索板都改为可滚动，按钮固定；ChainGraph 高度随字号自适应
- `e2e.ps1` 每个场景先固定字号 1.0，且点击失败会自动滚动重试；三段链路回归 24/24
- 新增截图：10-brief-1.5、11-board-1.5

### 3.6 迁移到纯 ASCII 路径（2026-11-17 19:30，解锁 DevEco）

DevEco 打开 `E:\校园推理galgame` 会直接弹 `Cannot Open Project: ... contain chinese characters`，
这是 hvigor 的硬限制，跟配置无关。

- 仓库整体 `Move-Item` 到 **`E:\campus-case`**：`.git` 一并搬走，remote / 分支 / 历史不变（搬之前 `git status` 是干净的）
- `tools/build-harmony.ps1` 改为**原地构建**，产物 `harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`；
  只有仓库又落在非 ASCII 路径时才自动 robocopy 到 `%LOCALAPPDATA%\campus-case-build`（`-Mirror` 可强制走镜像）
- 迁移后回归：`build-harmony.ps1` → 双模块 BUILD SUCCESSFUL / `RESULT: PASS`；HAP 重装模拟器 + `e2e.ps1 -Scenario all` → **24/24**
- IDE 入口：`File → Open → E:\campus-case\harmony`（选 `harmony` 子目录，不是仓库根）
- 文档里的旧路径已同步：`docs/04`（路径说明）、`README`（§5 提示 + §6.2 IDE 入口）、`TestReport`

### 3.7 Hypium 用例真跑通（2026-11-17 20:15）

昨天记的「CLI 下 Hypium 不推进」不是环境限制，是两个代码问题：

1. `describe('Fixtures(AC-18)')` 被框架判非法（只允许字母/数字/下划线/点，首字符须字母）→ 改 `Fixtures.AC18`
2. Hypium 报告链路 `delegator.print()` 需要**已启动的 UIAbility 作宿主**，没有时 Promise 永不 resolve
   → 新增 `ets/testability/TestAbility.ets` + `module.json5` 声明；runner 改为 `startAbility(TestAbility)`；
   runner 里的 `getAbilityDelegator()` 还必须放进 `onRun()`（模块顶层拿到 null）

结果：`aa test` 与 IDE Run 都是 **22/22**
（`Tests run: 22, Failure: 0, Error: 0, Pass: 22`，日志 `docs/evidence/hypium-aa-test.log`）。

## 4. 今天踩过的坑（明天不用重复踩）
| 坑 | 结论 |
| --- | --- |
| hvigor / DevEco 拒绝中文路径 | 仓库已迁到 `E:\campus-case`；`build-harmony.ps1` **原地构建**，只有非 ASCII 路径才自动镜像到 `%LOCALAPPDATA%\campus-case-build` |
| ArkUI `ForEach` 同 key 不重建 | key 里必须并入状态字段，否则列表状态不刷新 |
| API 12 的 `animateTo`/`AlertDialog` | 走 `this.getUIContext().animateTo / showAlertDialog` |
| 流水回放还原不了 JUDGE/ENDING | 恢复顺序：自动槽 → Preferences 快照 → 回放 |
| `uitest` 点击无反应 | 先确认 `hdc list targets` 非空；坐标要用 dumpLayout 的 bounds 中心 |
| 编辑 PS1 后中文乱码 | 脚本要存 UTF-8 **带 BOM**（5.1 按 GBK 解析会报错） |

---

## 5. 仓库速查

```
docs/            01 需求 / 02 内容 / 03 Android(冻结) / 04 编译检查单 / 05 演示对照 / TestReport
shared/case/     唯一内容源（两端共用）
shared/fixtures/ 42 条判定用例（Kotlin + ArkTS 各自跑）
harmony/         DevEco 工程（交付对象）
android/         Gradle 工程（冻结，仅保留）
tools/           preflight / validate / gen_fixtures_ets / sync-case / build-harmony /
                 run-kotlin-tests / ui-tap / e2e / make-icons
```
