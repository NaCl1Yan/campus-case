# Android 版实现规格说明（与鸿蒙版同构）
## SRS-Base 的 Android 映射 · 双端一致性策略

| 项 | 内容 |
| --- | --- |
| 文档版本 | v1.0 / 2026-11-16 |
| 定位 | **功能与鸿蒙版完全相同**，本文只解决"同一套 FR 在 Android 上怎么落地、怎么保证两端不跑偏" |
| 规格来源 | 功能条目不新增、不删减：以 [01-基础功能需求规格说明](01-基础功能需求规格说明.md) 的 FR-01～FR-17 与 AC-01～AC-17 为准 |
| 内容来源 | 与鸿蒙版**共用同一份内容 JSON**（见 §8），不重写剧情 |
| 平台基线 | Android 8.0+（minSdk 26）、targetSdk 35、Kotlin 2.x、Jetpack Compose（BOM 用建工程时最新稳定版）、AGP 8.x、JDK 17 |
| 包名 | `com.nacl1yan.campuscase` |

---

## 1. 三条硬原则

| # | 原则 | 含义 | 违反的代价 |
| --- | --- | --- | --- |
| P1 | **规格单源** | FR 编号、判定规则、阈值、错误码两端共用 01 文档，Android 侧不另立标准 | 两端行为分叉，验收要跑两套口径 |
| P2 | **内容单源** | `shared/case/` 下同一份 JSON 同时被两端打包；只有平台代码是两份 | 改剧情改两遍，必然漏改 |
| P3 | **判定单出口** | 门控/效果/连线/结局/进度在两端各有一份实现，但**输入输出逐位一致**，用同一批 fixture 用例双向校验 | 同一份存档在两端得出不同结局 |

> 结论：Android 版不是"再做一遍 App"，是"把 01 文档的 17 条 FR 用 Kotlin/Compose 重写一遍解释器 + UI"，逻辑量约等于鸿蒙版的 0.7 倍（无需重新设计内容与判定）。

---

## 2. 技术栈选型

| 层 | 鸿蒙版 | Android 版 | 说明 |
| --- | --- | --- | --- |
| 语言 | ArkTS | Kotlin（严格模式，显式类型） | 都不允许动态类型逃逸 |
| UI | ArkUI 声明式 | Jetpack Compose + Material 3 | 声明式范式一致，状态驱动 |
| 导航 | `Navigation` + `NavPathStack` | `navigation-compose`（type-safe `@Serializable` 路由） | 单 Activity + 多 Composable |
| 状态 | `@State/@Observed/@ObjectLink/@Provide` | `mutableStateOf` + `StateFlow<UiState>` + `CompositionLocal` | 见 §4 对照表 |
| KV 存储 | Preferences | **DataStore(Preferences)** | 同为小体量 KV，但 API 为异步 |
| 关系存储 | RDB（relationalStore） | **Room**（SQLite） | 表结构同构，见 §5 |
| JSON | 手写映射（无 `any`） | **kotlinx.serialization**（`@Serializable` + 默认值） | 快照 schema 与字段名必须完全一致 |
| 并发 | TaskPool/Promise | Coroutines + Flow | 落盘写入用单线程串行队列 |
| 测试 | Hypium | JUnit5 + `kotlinx-coroutines-test` + Robolectric（Room/DataStore） | 用例编号 TC-01～TC-28 复用 |
| 依赖注入 | 手写单例 | 手写 Application 容器（不引 Hilt，减少构建成本与概念负担） | 可后期换 Hilt |
| 覆盖率 | DevEco 覆盖率工具 | Kover / JaCoCo | 门槛同 01 文档 §10.3 |
| 构建 | hvigor | Gradle Kotlin DSL + version catalog | 签名材料不入库（已在 `.gitignore`） |

**依赖基线**（建工程时按 Android Studio 推荐升到最新 patch）

```kotlin
// gradle/libs.versions.toml 摘要
[versions]
kotlin = "2.1.x"
agp = "8.7.x"
composeBom = "2024.12.x"      // 以建工程时稳定版为准
room = "2.6.x"
datastore = "1.1.x"
serialization = "1.7.x"
coroutines = "1.9.x"
junit = "5.11.x"
robolectric = "4.14"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version = "2.8.x" }
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }
```

---

## 3. FR → Android 实现映射

**每条 FR 的行为要求不变**，下表只给落点（Composable / 数据类 / 仓库）。

| FR | Android 落点 | 备注 |
| --- | --- | --- |
| FR-01 启动/继续/新局 | `LaunchScreen` + `LaunchViewModel`；`MainActivity` 单 Activity | 用 `SplashScreen API` 承载内容加载与恢复，避免白屏 |
| FR-02 简报接案 | `BriefScreen`；`case.brief` 直读内容 | 重复进入不重复触发（同 effect 幂等） |
| FR-03 场景热点 | `HubScreen` / `SceneScreen` + `HotspotLayer`（Canvas/Box 覆盖） | 归一化坐标 `x,y ∈ 0..1000` → `Modifier.offset` 按容器尺寸换算 |
| FR-04 节点引擎 | `domain/`：`Gate.kt` `ApplyNode.kt` | 纯 Kotlin，无 Android 依赖，JVM 单测直跑 |
| FR-05 对话 | `DialogOverlay` + `TypewriterText`（`LaunchedEffect` 驱动） | 逐字用 `withFrameNanos` 或 `delay(25)`；离开时协程自动取消 |
| FR-06 线索 | `ClueRepository` + `ClueCard` | 只能由 `Effect.grantClues` 写入，DAO 不对外暴露 insert |
| FR-07 线索板 | `ClueBoardScreen` + `LinkCanvas`（`Path` + `PathMeasure` 生长动画） | 已成立连线按 flag 重绘 |
| FR-08 推理验证 | `DeductionScreen` + `ProveStageViewModel` | 槽位数不写死 2 |
| FR-09 最终判断 | `JudgeScreen` + `Ending.kt::resolveEnding` | 选项灰显可见 + 二次确认 `AlertDialog` |
| FR-10 结局 | `EndingScreen`（`AnimatedVisibility` 三段）+ `CollectionScreen` | `BackHandler` 拦截返回 |
| FR-11 HUD | `HudBar`（8 元素），由 `derivedStateOf` 从 `GameUiState` 推导 | 避免每帧全量重组 |
| FR-12 阶段进度 | `ProgressRing`（`Canvas` + `animateFloatAsState`）+ `Progress.kt` | 进度只读计算，不写入库 |
| FR-13 存档 | `SaveRepository` + `SlotsScreen` | 自动槽 `slotId=0` + 手动 1..3，同上 |
| FR-14 进程恢复 | `RestoreCoordinator`（Application 启动时）+ `EventLogDao.replay()` | 见 §6 |
| FR-15 设置 | `SettingsScreen` + `SettingsRepository`（DataStore） | 应用内字号系数 × 系统 `fontScale`，防双重放大 |
| FR-16 内容校验 | `CaseLoader` + `CaseValidator`（跑在 `Dispatchers.Default`） | 与鸿蒙版同一校验清单（01 §FR-16 的 8 条） |
| FR-17 错误处理 | `sealed class CaseError` + `UserMessage` 映射 | 错误码字符串两端一致，便于对照日志 |

---

## 4. 状态管理映射（最容易出错的地方）

| 鸿蒙（ArkUI） | Android（Compose） | 注意 |
| --- | --- | --- |
| `@State x` | `var x by remember { mutableStateOf(...) }` | 值类型变化触发重组 |
| `@State` 对象整体替换 | `MutableStateFlow<UiState>` + `collectAsStateWithLifecycle()` | **单一 UiState 数据类**，不做 N 个分散 state |
| `@Prop`（单向传入） | 函数参数传不可变 `data class` | 子组件不持可变引用 |
| `@Link`（双向） | `state: T, onValueChange: (T) -> Unit`（状态提升） | Compose 不允许隐式双向绑定 |
| `@Provide/@Consume` | `CompositionLocalProvider` + `staticCompositionLocalOf` | 只放主题/字号/音效开关，不放进度 |
| `@Observed/@ObjectLink`（局部刷新） | `derivedStateOf` + 稳定 `key` + `items(key=)` | 用稳定 id 做 key，避免整表重组 |
| `AppStorage` + `PersistentStorage` | `DataStore` + `StateFlow`（仓库层暴露） | 进度**不进** DataStore 之外的隐式存储 |
| `animateTo` | `Animatable` / `animateFloatAsState` / `updateTransition` | 由 `LaunchedEffect` 驱动，随组合销毁自动停 |
| `Canvas` + `Path2D` | `Canvas { drawPath(...) }` + `PathMeasure` | 连线生长用 `PathMeasure.getSegment(0, len*t)` |

**领域状态约定（两端一致）**

```kotlin
@Serializable
data class PlayerState(
    val caseId: String,
    val contentVersion: Int,
    val seq: Int,
    val stage: Stage,
    val unlockedScenes: List<String>,
    val ownedClues: List<String>,
    val flags: Map<String, Boolean>,
    val closedNodes: List<String>,
    val passedStages: List<String>,
    val finalChoice: String?,
    val endingId: String?,
    val playMs: Long,
    val savedAt: Long,
)
```

- 对外只暴露不可变 `PlayerState`；变更 = `copy()` 生成新实例 → 驱动 `StateFlow` 发射。
- `UiState = PlayerState + 派生展示数据（HUD 文案、进度、链计数）`，派生用 `map`/`derivedStateOf`，不落库。
- **禁止**在 Composable 里写业务判定（对应 01 §3.2 与 AC-15）。

---

## 5. 持久化映射

### 5.1 Preferences → DataStore

| 鸿蒙 Key | Android Key | 类型 | 说明 |
| --- | --- | --- | --- |
| `snapshot.v1` | `snapshot` | String(JSON) | 同一份快照 JSON |
| `snapshot.seq` | `snapshot_seq` | Int | 与 Room 对账 |
| `content.version` | `content_version` | Int | 内容版本 |
| `schema.version` | `schema_version` | Int | 结构版本（与 Room `user_version` 同步） |
| `settings.fontScale` | `font_scale` | Float | 1.0/1.2/1.5 |
| `settings.sfxOn` | `sfx_on` | Boolean | |
| `settings.reduceMotion` | `reduce_motion` | Boolean | |

```kotlin
val Context.caseStore by preferencesDataStore(name = "campus_case")
```

**关键约束**：DataStore 的 `edit {}` 是**异步且串行**的。落盘顺序必须是 `Room 事务 → DataStore.edit → 通知 UI`，且写入必须进入单一协程队列（`Mutex` 或 `Channel(UNLIMITED)` + 单 worker），否则并发 `edit` 会导致"快照 seq 落后于实际状态"。

### 5.2 RDB → Room（表结构同构）

| 鸿蒙表 | Room Entity | 主键 | 备注 |
| --- | --- | --- | --- |
| `t_case` | `CaseEntity` | `case_id` | `stage` 用 `StringConverter` 存枚举名 |
| `t_clue_owned` | `ClueOwnedEntity` | `(case_id, clue_id)` | `@Entity(primaryKeys = [...])` |
| `t_flag` | `FlagEntity` | `(case_id, fkey)` | `fvalue` 存 `"true"/"false"/字符串` |
| `t_event_log` | `EventLogEntity` | `seq`（`autoGenerate`） | `(case_id, seq)` 索引 |
| `t_save_slot` | `SaveSlotEntity` | `slot_id` | `payload` 存快照 JSON |

```kotlin
@Database(
  entities = [CaseEntity::class, ClueOwnedEntity::class, FlagEntity::class,
              EventLogEntity::class, SaveSlotEntity::class],
  version = 1, exportSchema = true
)
abstract class CaseDatabase : RoomDatabase() { /* DAOs */ }
```

- 迁移策略与鸿蒙版一致：只加列/加表，`MIGRATION_n_m` 显式声明，**禁止** `fallbackToDestructiveMigration()`（会丢档，直接违反 AC-10/AC-12）。
- 事务：`db.withTransaction { ... }`（Room KTX），内部只做 SQL，不做 JSON 解析与 UI 回调。
- 读档 = 整体替换：先 `DELETE` 三张进度表 + 流水，再按快照重写。

---

## 6. 恢复时序（Android 特化）

Android 的进程死亡比鸿蒙更常见（Doze、低内存、用户划卡），所以**策略更严格，逻辑不变**。

```
MainActivity.onCreate / Application.onCreate
 1. Splash 起，协程读 DataStore（异步，不阻塞主线程）
 2. Room 打开（迁移 + user_version 校验），跑在 Dispatchers.IO
 3. 加载并校验内容（assets/case/*.json），失败 → 降级内置最小案件（01 §FR-16）
 4. 对账：
      snapSeq = dataStore.snapshot_seq
      dbSeq   = eventLogDao.maxSeq(caseId)
      snapSeq == dbSeq → 用快照；否则 → eventLogDao.replay(dbSeq) 重建
 5. sanitize（与 01 §FR-14 同一套规则）
 6. 回写 Room 与 DataStore，使两侧一致
 7. 按 stage 落到对应 Composable（NavController 直达）
```

**要点**

| 项 | 处理 |
| --- | --- |
| `onDestroy` 不可靠 | 完全不依赖它；每个节点落盘即时完成（01 §3.3） |
| DataStore 异步 | 冷启动期间显示 Splash + 进度，读到第一个值后再进页面；目标 ≤300ms |
| 配置变更（旋转） | `ViewModel` + `rememberSaveable` 保住 UI 态；领域态在仓库层，不受影响 |
| 系统"预测性返回" | 结局页/判断确认用 `BackHandler(enabled = true)` 拦截，符合 FR-10 |
| Doze 后恢复 | 无网络、无定时任务，无需处理；只需保证落盘已完成 |
| `allowBackup` | 设 `false`（避免系统云备份把进度快照带到另一台设备导致 `seq` 错乱） |
| 数据库加密 | 不做（无敏感数据），保持依赖最小 |

---

## 7. 动画映射（对应 01 §8.3 的 6 类）

| 动画 | Compose 实现 | 参数 |
| --- | --- | --- |
| 页面转场 | `AnimatedContent` / `SharedTransitionLayout`（线索卡→线索板） | 300ms `FastOutSlowInEasing` |
| 线索获得 | `Animatable` 位移 + `animateFloatAsState` 计数 | 450ms `spring(dampingRatio=0.7)` |
| 连线生长 | `Canvas` + `PathMeasure`，`t` 由 `animateFloatAsState` 驱动 | 320ms |
| 进度环 | `animateFloatAsState` + `Canvas.drawArc` | 400ms |
| 失败抖动 | `keyframes { 0f at 0; 6f at 60; -6f at 120; ... }` | 240ms |
| 阶段推进 | `AnimatedVisibility` + 遮罩 alpha 溶解 | 500ms，只播一次（记 flag） |
| 打字机 | `LaunchedEffect(lineId) { for (c in text) { append(c); delay(25) } }` | 点击跳过用 `SharedFlow` 中断 |

- `reduce_motion = true` 时：位移/抖动替换为淡入（`fadeIn`），与鸿蒙版同一开关语义。
- 所有动画由组合生命周期托管，`DisposableEffect` 里不需要手动清理（这是 Compose 相对 ArkUI 的省事处），但 `Canvas` 里创建的 `PathMeasure` 要 `remember` 复用。

---

## 8. 双端仓库结构（monorepo）

```
campus-case/
├─ README.md
├─ .gitignore
├─ docs/                        # 规格与设计（两端共用）
│   ├─ 01-基础功能需求规格说明.md      ← 平台无关，唯一判定标准
│   ├─ 02-内容与剧情设计规范.md
│   ├─ 03-Android版实现规格说明.md     ← 本文
│   └─ drafts/
├─ shared/                      # 两端共用，禁止平台代码
│   ├─ case/                    # 内容 JSON（剧情、场景、节点、线索、结局）
│   │   ├─ case.schema.json      # JSON Schema
│   │   └─ campus_001.json       # 实际案件（当前为占位）
│   └─ fixtures/                # 一致性测试向量（输入 → 期望输出）
│       ├─ gate_cases.json
│       ├─ ending_cases.json
│       └─ snapshot_roundtrip.json
├─ harmony/                     # DevEco 工程（ArkTS）
│   └─ entry/src/main/{ets,resources/rawfile/case -> shared 副本}
└─ android/                     # Gradle 工程（Kotlin）
    └─ app/src/main/{java/com/nacl1yan/campuscase, assets/case -> shared 副本}
```

**共享方式的两条路（选一条，别混用）**

| 方案 | 做法 | 优点 | 缺点 |
| --- | --- | --- | --- |
| A 符号链接/构建期复制 | 构建脚本把 `shared/case` 复制进两端资源目录 | 一份源文件，改一次两端生效 | 需要 Gradle / hvigor 各写一个 copy task |
| B 子模块或打包脚本 | `shared` 作为独立产物，构建前 `sync` 到两端 | 结构干净 | 多一步构建 |

**推荐 A**：`shared/case` 只读，两端各写 5 行构建任务复制到 `assets/case` 与 `rawfile/case`，`shared/` 本身不入包。复制产物加入 `.gitignore`，避免两份副本在仓库里打架。

---

## 9. 一致性怎么保证（本项目最关键的验收）

| 手段 | 做法 | 拦得住什么 |
| --- | --- | --- |
| 规格单源 | 两端都对照 01 文档的 FR/AC 编号实现，不各写一份 | 需求漂移 |
| 内容单源 | `shared/case/*.json`，两端构建期复制 | 剧情改一处漏一处 |
| 测试向量共享 | `shared/fixtures/*.json` 描述"输入状态 + 动作 → 期望结果"，两端各自读取并断言 | 判定逻辑分叉（最致命） |
| 快照 schema 相同 | 字段名/大小写/枚举名完全一致，`v` 字段做版本 | 存档跨端不可读 |
| 错误码相同 | `E_*` 字符串两端一致 | 日志/排查无法对照 |
| 双端对照表 | 01 文档 AC 表旁加一列"Android 验收"（同一口径） | 只验一头 |

**fixture 格式示例**（两端必须得出相同结果）

```json
{
  "id": "ending-single-chain-B",
  "caseId": "campus_001",
  "state": {
    "stage": "JUDGE",
    "ownedClues": ["C1", "C2", "C3"],
    "flags": { "proofB": true, "proofA": false },
    "finalChoice": "PUBLIC"
  },
  "expect": { "reachableEndings": ["E-B"], "endingId": "E-B", "progress": 85 }
}
```

两端各写一个 `FixtureRunner`：鸿蒙侧跑在 Hypium 里，Android 侧跑在 JUnit5 里；同一批文件，同一批断言。**这一条跑通，"相同的安卓版本"才算成立**。

---

## 10. 平台差异清单（只列真正会不一样的地方）

| 差异 | 鸿蒙 | Android | 处理 |
| --- | --- | --- | --- |
| 返回行为 | 系统返回键 / 手势 | 系统返回 + 预测性返回手势 | 结局、判断确认页 `BackHandler` 拦截，其余放行 |
| 字号缩放 | 应用内系数（HUD 文本） | 系统 `fontScale` 已生效，应用内再乘会双重放大 | Android 侧系数改为"基准 1.0 对应系统默认"，只允许向下/有限向上调 |
| 后台存活 | 相对稳定 | 易被回收 | 落盘更严格（已按 01 §3.3 实现即时写入） |
| 存储异步性 | Preferences 同步可用 | DataStore 全异步 | Splash 等待首个值，仓库层对外暴露 `Flow<PlayerState>` |
| 包体 | HAP 体积可控 | Compose + Room 约 8–12MB（APK/AAB） | 关闭 R8 资源压缩风险项，保留 `keep` 规则给序列化类 |
| 权限 | 无 | 无（HTTP 权限也不申请） | `AndroidManifest` 里删除 `INTERNET` |
| 启动优化 | 首帧 ≤1.5s | 可加 Baseline Profile（P1） | 先按普通冷启动达标，再考虑 |

---

## 11. 验收（沿用 01，另加 Android 专属三项）

| AC | 口径 |
| --- | --- |
| AC-01 ～ AC-17 | **与鸿蒙版完全一致**，逐条按 01 §9 验收，不降低标准 |
| AC-18 双端判定一致 | `shared/fixtures` 全部用例在两端产出相同结果（含结局、进度、错误码） |
| AC-19 内容单源 | `shared/case` 改动后，两端构建产物内的内容文件哈希一致（脚本校验） |
| AC-20 存档互通 | 同一快照 JSON 在两端均可 `decode` 并恢复（`contentVersion` 一致时），字段无缺失/多余 |

---

## 12. 工作量与排期

| 阶段 | 鸿蒙 | Android | 说明 |
| --- | --- | --- | --- |
| M1 工程骨架 | 2d | 1.5d | Compose 脚手架比 DevEco 省事，但双端目录与复制任务要搭 |
| M2 引擎 + 单测 | 3d | 2.5d | 逻辑已定型（01 §5），Kotlin 侧复用同一套 TC 编号；测试框架比 Hypium 顺手 |
| M3 界面 + 动画 | 3d | 3d | 6 类动画两边工作量接近 |
| M4 持久化 + 恢复 | 2d | 2d | Room/DataStore 与 RDB/Preferences 复杂度相当（DataStore 异步要额外串行化） |
| M5 一致性 + 收尾 | 1d | 2d | Android 侧多做 fixture runner 与双端对照 |
| 合计 | 11d | 11d | 若先做完鸿蒙版，Android 版约 8d（内容与判定不用重新设计） |

**建议顺序**：先把鸿蒙版 M2 引擎跑通 → 用同一批 fixture 写 Android 版引擎（一次把双端一致性钉死）→ 再做两端 UI。反过来做会返工两次。

---

## 13. 风险

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| 两份判定逻辑悄悄分叉 | 同一存档两端结局不同 | fixture 共享 + AC-18；引擎只允许通过数据（Condition/Effect）表达规则，禁止硬编码分支 |
| DataStore 异步导致快照落后 | 恢复错状态 | Room 先写、DataStore 后写 + 单 worker 串行 + `seq` 对账 |
| `fallbackToDestructiveMigration` 图省事 | 升级即丢档 | 显式 `MIGRATION_n_m`，配测试验证数据保留 |
| Compose 重组范围过大 | 动画掉帧 | 单一 `UiState` + `derivedStateOf` + 稳定 `key`；热点层单独 `layout` 隔离 |
| 内容复制方案漂移 | 两端内容不一致 | 构建期复制 + 哈希校验（AC-19） |
| 双端并行开发导致规格跟不上 | 文档与实现脱节 | 按 01 文档 §13 的 R4：改规则必须同一次提交内更新文档 |

---

## 附录 A AndroidManifest 关键项

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!-- 不申请任何权限；尤其不要 INTERNET -->
  <application
      android:allowBackup="false"
      android:supportsRtl="true"
      android:theme="@style/Theme.CampusCase">
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:configChanges="orientation|screenSize|uiMode"
        android:windowSoftInputMode="adjustResize" />
  </application>
</manifest>
```

## 附录 B ProGuard/R8 规则要点

```proguard
# kotlinx.serialization：保留 @Serializable 类的生成器
-keepattributes *Annotation*, InnerClasses
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.nacl1yan.campuscase.**$$serializer { *; }
# Room 生成的实现类
-keep class * extends androidx.room.RoomDatabase
```

## 附录 C 与鸿蒙版的对照速查

| 概念 | 鸿蒙 | Android |
| --- | --- | --- |
| 页面 | `NavDestination` + `@Builder` | `@Composable` + `NavHost` |
| 状态容器 | `@Observed class` | `data class UiState` + `StateFlow` |
| 副效应 | `aboutToAppear` / `onDisappear` | `LaunchedEffect` / `DisposableEffect` |
| 轻量 KV | Preferences(`getSync`) | DataStore(`data.first()`) |
| 结构化存储 | `relationalStore` | Room |
| 单测 | Hypium `describe/it/expect` | JUnit5 `@Test` + `assertEquals` |
| 测试中伪造 Context | `AbilityDelegatorRegistry` | Robolectric `ApplicationProvider` |
