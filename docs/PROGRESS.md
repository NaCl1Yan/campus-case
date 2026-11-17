# 进度与明日待办
## 《钟楼七点》鸿蒙版 · 2026-11-16 收工快照

> 最近更新：2026-11-17 22:45（Asia/Shanghai）
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
| 文档 | ✅ 需求 / 内容 / 编译与单测检查单 / 演示验收对照 / 测试报告（索引 `docs/README.md`） | `docs/` |

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
| 1 | ~~在 DevEco 里跑一次 Hypium~~ ✅ **2026-11-17 20:17 已完成：22/22，154 ms** | 见 §3.7；截图 `docs/screenshots/hypium-run-22.png` | — |
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
（`Tests run: 22, Failure: 0, Error: 0, Pass: 22`，日志 `docs/evidence/hypium-aa-test.log`，
IDE 截图 `docs/screenshots/hypium-run-22.png`，154 ms）。

### 3.8 仓库规范化：Android 移除 + 文档重排（2026-11-17 20:45）

需求方确认只交鸿蒙版，于是把「冻结但还占地方」的东西清出 `main`：

| 处理 | 内容 |
| --- | --- |
| 归档后再移除 | `android/`（20 个文件）+ `docs/03-Android版实现规格说明.md` + `tools/run-kotlin-tests.ps1`，归档 tag `archive/android-v1`、分支 `archive/android`（都已推送） |
| 文档重排 | 04→`03-编译与单测检查单`、05→`04-演示与验收对照`，编号连续；新增 `docs/README.md` 作索引、`docs/evidence/` 存原始日志 |
| 工具收敛 | `preflight.py` 从 10 项降到 8 项（去掉 Kotlin 符号、Gradle 目录检查）；`sync-case.ps1` 只同步鸿蒙两处 rawfile，输出改为「鸿蒙侧内容一致」 |
| 口径修正 | `01` 目标平台改为 HarmonyOS 单端（v1.6），AC-18 降级为历史说明；`02`/README/TestReport/PROGRESS 里「双端」措辞一并改掉 |

回归：`preflight` PASS 8、`validate` 42/42、`sync-case -Check` ACK、`build-harmony.ps1` PASS、Hypium 22/22 不受影响。

### 3.9 录屏 + 作业要求自查（2026-11-17 21:10）

作业要求「README 含功能/环境/截图/运行方法 + 真实录屏，≥6 条自动化测试覆盖正常边界异常」，逐条补齐：

| 做的东西 | 结果 |
| --- | --- |
| 录屏工具链 | `tools/device-capture.sh`（设备端 `snapshot_display` 连续抓帧）+ `tools/make-demo-gif.py`（去黑帧/去重复帧 → 调色板 GIF） |
| 录屏内容 | 882 帧原始 → 去黑 54、去重复 728、去壁纸段 → **82 帧 / 24 秒 / 5.6 MB**，覆盖启动→接案→取证→连线→验证→判断→结局→收集册 |
| README | 先写成“快速开始 + 功能 + 环境 + 运行 + 截图录屏 + 测试 + 索引”，后按要求精简为 8 节（详细内容移到实验报告 Word，不入库） |
| 需求书补章 | `docs/01` 增 §2.3 模块划分与接口契约（模块表 + Engine/GameController/Prefs/CaseDb 接口签名 + 三条解耦硬规则）、§2.4 分工（独立完成声明 + 组队模板），版本升 v1.7 |
| 测试归类 | `TestReport` 增 §1.1：22 条 Hypium 按 **正常 6 / 边界 8 / 异常 8** 逐条列，另记 24 条 UI 流水线断言 |

> 录屏细节：设备没有 `screenrecord`，改用 `snapshot_display` 逐帧抓（约 2.5 fps），
> 抓帧期间跑一遍 `e2e.ps1 -Scenario happy`，所以录到的就是脚本化的真实操作，不是摆拍。

### 3.10 界面重设计 + 深色模式（2026-11-17 22:45）

功能稳定后重做视觉与布局，并把颜色从组件里抽出来：

| 做的事 | 细节 |
| --- | --- |
| 语义色板 | `resources/base|dark/element/color.json` 各 31 个 token：页面/卡片/次表面/边框、四级文本、品牌（文本/实底/反白）、chip、危险/成功/氛围色、进度轨道、toast、阴影 |
| 去硬编码 | 13 个视图 + Index 里的 ~200 处 hex 全部换成 `$r('app.color.*')`；Canvas 用 `resourceManager.getColorSync` 解析同一份资源 |
| HUD 重构 | 四行：返回+阶段胶囊+进度环+存档 / 当前目标 / 状态胶囊（线索·行动线·动机线·可推理·保存时间）/ 工具条（简报·收集册·设置·重来） |
| 页面外壳 | 统一 padding（16/12/8）、卡片 16px 圆角 + 1px 边框、胶囊 chip、底部操作栏 pill 按钮（主行动用 brand 实底） |
| 页面改造 | 简报（委托卡+目标编号+时间线卡）、地图（序号徽标+可去计数）、场景（氛围色带+热点状态胶囊）、线索板（证据链图卡+计数胶囊+选中态按钮）、推理/判断/结局/收集册/存档全部统一 |
| 设置新增外观 | 跟随系统 / 浅色 / 深色三档：`setColorMode` + `Prefs.KEY_THEME` 持久化，`themeKey` 触发 Canvas 重绘 |
| 回归 | 编译 PASS；`e2e -Scenario all` 24/24（过程中修了两处自动化标签：保留「‹ 返回」文案、把计数胶囊并回单个文本节点「线索 5 / 6」） |

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
docs/            00 索引 / 01 需求 / 02 内容 / 03 编译与单测 / 04 演示验收 / TestReport
                 screenshots/ 运行截图   evidence/ 原始日志   drafts/ 早期草案
shared/case/     唯一内容源
shared/fixtures/ 42 条判定用例（Hypium 遍历执行）
harmony/         DevEco 工程（交付对象）
tools/           preflight / validate / gen_fixtures_ets / sync-case / build-harmony /
                 ui-tap / e2e / make-icons
```

> Android 版（Kotlin + Compose）已于 2026-11-17 冻结并从 `main` 移除，
> 归档在 tag `archive/android-v1` / 分支 `archive/android`；需要时 `git checkout archive/android-v1 -- android/` 取回。
