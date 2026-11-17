import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { CaseFile, ClueDef, NodeState, PlayerState, Stage } from '../domain/Types';
import { Engine } from '../domain/Engine';
import { GameController } from '../store/GameController';
import { SlotInfo } from '../store/CaseDb';
import { HudBar } from '../view/HudBar';
import { BriefView } from '../view/BriefView';
import { HubView, SceneCard } from '../view/HubView';
import { HotspotItem, SceneView } from '../view/SceneView';
import { ClueBoardView, ClueCardData } from '../view/ClueBoardView';
import { RuleEdge } from '../view/ChainGraph';
import { DeduceView, ProveCard } from '../view/DeduceView';
import { JudgeOption, JudgeView } from '../view/JudgeView';
import { EndingView } from '../view/EndingView';
import { SlotRow, SlotsView } from '../view/SlotsView';
import { GalleryRow, GalleryView } from '../view/GalleryView';
import { SettingsView } from '../view/SettingsView';
import { EndingRow } from '../store/CaseDb';
import { Prefs } from '../store/Prefs';
import { ThemeState } from '../store/ThemeState';

/**
 * 单页应用 + 视图切换（01 §8.1 页面清单的落地）。
 * 约定：所有业务判定走 GameController → Engine；页面只做展示与事件转发。
 */
@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State view: string = 'hub';
  @State mirror: PlayerState = new PlayerState();
  @State sceneId: string = '';
  @State bodyTitle: string = '';
  @State bodyText: string = '';
  @State toast: string = '';
  @State progress: number = 0;
  @State stageText: string = '';
  @State objective: string = '';
  @State clueText: string = '0 / 6';
  @State chainBText: string = '0/3';
  @State chainAText: string = '0/3';
  @State readyChip: boolean = false;
  @State savedText: string = '';
  @State slotRows: SlotRow[] = [];
  @State galleryRows: GalleryRow[] = [];
  @State reduceMotion: boolean = false;
  @State contentVersion: number = 1;
  @State fontScale: number = 1;
  @State transitionFlag: boolean = false;
  @State themeMode: string = 'follow';
  @State themeKey: number = 0;

  private controller: GameController = GameController.I;
  private toastTimer: number = -1;

  aboutToAppear(): void {
    this.bootstrap();
  }

  aboutToDisappear(): void {
    if (this.toastTimer !== -1) {
      clearInterval(this.toastTimer);
      this.toastTimer = -1;
    }
  }

  private async bootstrap(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.controller.init(context);
      this.ready = true;
      this.reduceMotion = this.controller.reduceMotion;
      this.contentVersion = this.caseFile().contentVersion;
      this.fontScale = await Prefs.getNumber(Prefs.KEY_FONT_SCALE, 1);
      this.themeMode = await Prefs.getString(Prefs.KEY_THEME, 'follow');
      this.applyTheme(this.themeMode, false);
      this.refresh();
      if (this.mirror.stage === Stage.FINISHED) {
        this.view = 'ending';
      } else if (this.mirror.stage === Stage.PROLOGUE || this.mirror.stage === Stage.ACCEPT) {
        this.view = 'brief';
      } else {
        this.view = 'hub';
      }
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.transitionFlag = true;
      });
    } catch (e) {
      this.toast = `初始化失败：${e}`;
    }
  }

  private caseFile(): CaseFile {
    return this.controller.requireCase();
  }

  /** 统一刷新：把 controller 的状态镜像到 @State，驱动 HUD 与各页重渲染。 */
  private refresh(): void {
    this.mirror = this.controller.state;
    this.progress = this.controller.progress();
    this.stageText = this.controller.stageLabel();
    this.objective = this.controller.objective();
    this.clueText = `${this.controller.clueCount()} / ${this.controller.clueTotal()}`;
    const bChain = this.caseFile().chains.find((c) => c.id === 'CH-B');
    const aChain = this.caseFile().chains.find((c) => c.id === 'CH-A');
    this.chainBText = bChain === undefined ? '-' :
      `${this.controller.chainProgress('CH-B')}/${this.controller.chainSize('CH-B')}`;
    this.chainAText = aChain === undefined ? '-' :
      `${this.controller.chainProgress('CH-A')}/${this.controller.chainSize('CH-A')}`;
    this.readyChip = this.controller.anyChainReady();
    const stamp = new Date();
    this.savedText = `已保存 ${stamp.getHours().toString().padStart(2, '0')}:${stamp.getMinutes().toString().padStart(2, '0')}`;
  }

  private showToast(text: string): void {
    this.toast = text;
    if (this.toastTimer !== -1) {
      clearInterval(this.toastTimer);
    }
    this.toastTimer = setInterval(() => {
      this.toast = '';
      if (this.toastTimer !== -1) {
        clearInterval(this.toastTimer);
        this.toastTimer = -1;
      }
    }, 2200);
  }

  /** 外观：follow/light/dark。setColorMode 会触发配置变更重绘，themeKey 用于让 Canvas 重画。 */
  private applyTheme(mode: string, persist: boolean): void {
    this.themeMode = mode;
    this.themeKey = this.themeKey + 1;
    if (persist) {
      Prefs.putString(Prefs.KEY_THEME, mode);
    }
    // setColorMode 会触发 Ability 重建：只有「用户主动切换」或「本进程首次应用非跟随主题」时才调用。
    // - bootstrap 且 mode=follow：完全不动系统主题，避免无谓重建；
    // - bootstrap 且 mode=light/dark：本进程首次需要应用一次，之后不再重复（否则重建循环）。
    const needApply = persist || (!ThemeState.applied && mode !== 'follow');
    if (!needApply) {
      ThemeState.applied = true;
      ThemeState.current = mode;
      return;
    }
    ThemeState.applied = true;
    ThemeState.current = mode;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (mode === 'dark') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else if (mode === 'light') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      }
      context.getApplicationContext().setColorMode(colorMode);
    } catch (e) {
      console.error(`[campus] setColorMode failed: ${e}`);
    }
  }

  private nav(view: string): void {
    this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseIn }, () => {
      this.transitionFlag = false;
    });
    this.view = view;
    const dur = this.controller.reduceMotion ? 0 : 220;
    this.getUIContext().animateTo({ duration: dur, curve: Curve.EaseOut }, () => {
      this.transitionFlag = true;
    });
  }

  // ---------------------------------------------------------------- 数据组装

  private sceneCards(): SceneCard[] {
    const state = this.mirror;
    return this.caseFile().scenes.map((scene) => {
      const available = Engine.isSceneAvailable(state, scene);
      const total = scene.hotspots.length;
      let done = 0;
      scene.hotspots.forEach((h) => {
        if (state.appliedNodes.includes(h.nodeId)) {
          done += 1;
        }
      });
      return new SceneCard(scene.id, scene.name, scene.desc, !available, `已查 ${done}/${total}`);
    });
  }

  private hotspotItems(): HotspotItem[] {
    const state = this.mirror;
    const caseFile = this.caseFile();
    const scene = caseFile.scenes.find((s) => s.id === this.sceneId);
    if (scene === undefined) {
      return [];
    }
    return scene.hotspots.map((h) => {
      const node = caseFile.nodes.find((n) => n.id === h.nodeId);
      const title = node === undefined ? h.nodeId : node.title;
      const nodeState: string = Engine.nodeState(state, caseFile, h.nodeId);
      const done = nodeState === NodeState.DONE;
      const hint = node === undefined ? '' : (h.lockedHint ?? '还需要更多现场信息');
      return new HotspotItem(h.nodeId, title, nodeState, hint, done);
    });
  }

  private clueCards(): ClueCardData[] {
    const state = this.mirror;
    const caseFile = this.caseFile();
    const linkedFlags: string[] = [];
    caseFile.rules.forEach((rule) => {
      if (state.flags.get(rule.grantsFlag) === true) {
        linkedFlags.push(rule.grantsFlag);
      }
    });
    return caseFile.clues.map((clue: ClueDef) => {
      const owned = state.ownedClues.includes(clue.id);
      let linked = false;
      caseFile.rules.forEach((rule) => {
        if (rule.inputs.includes(clue.id) && linkedFlags.includes(rule.grantsFlag)) {
          linked = true;
        }
      });
      const typeLabel = clue.type === 'PHYSICAL' ? '物证' : (clue.type === 'TESTIMONY' ? '证言' : '时间线');
      return new ClueCardData(clue.id, clue.name, typeLabel, clue.desc,
        clue.hintWhenMissing ?? '还需要更多现场信息', owned, linked);
    });
  }

  private proveCards(): ProveCard[] {
    const state = this.mirror;
    const caseFile = this.caseFile();
    return caseFile.proveStages.map((p) => new ProveCard(
      p.id, p.question, Engine.canPublic(state) || Engine.canPrivate(state) ? '证据链已成立' : '还差一步',
      state.passedStages.includes(p.id), p.hints ?? [], state.ownedClues.slice().sort()
    ));
  }

  /** 规则连线状态（证据链图用）。 */
  private ruleEdges(): RuleEdge[] {
    const state = this.mirror;
    return this.caseFile().rules.map((rule) =>
      new RuleEdge(rule.inputs[0], rule.inputs[1], rule.id, state.flags.get(rule.grantsFlag) === true));
  }

  private chainIds(chainId: string): string[] {
    const chain = this.caseFile().chains.find((c) => c.id === chainId);
    return chain === undefined ? [] : chain.clueIds;
  }

  /** 已成立的规则结论（线索板用文字把推理链讲清楚）。 */
  private conclusions(): string[] {
    const state = this.mirror;
    const list: string[] = [];
    this.caseFile().rules.forEach((rule) => {
      if (state.flags.get(rule.grantsFlag) === true) {
        list.push(rule.conclusion);
      }
    });
    return list;
  }

  private async reloadGallery(): Promise<void> {
    const seen: EndingRow[] = await this.controller.collectibleEndings();
    const rows: GalleryRow[] = this.caseFile().endings.map((ending) => {
      const hit = seen.find((s) => s.endingId === ending.id);
      if (hit === undefined) {
        const need = this.caseFile().chains
          .filter((c) => ending.requires.allFlags !== undefined && ending.requires.allFlags.includes(c.passFlagId))
          .map((c) => c.name);
        return new GalleryRow(ending.id, ending.name, false,
          `需要证据链：${need.length > 0 ? need.join('、') : '未知'} → 查看结局条件`);
      }
      const when = new Date(hit.firstSeen);
      return new GalleryRow(ending.id, ending.name, true,
        `解锁于 ${when.getMonth() + 1}/${when.getDate()} ${when.getHours().toString().padStart(2, '0')}:${when.getMinutes().toString().padStart(2, '0')}`);
    });
    this.galleryRows = rows;
  }

  private clueIds(): string[] {
    return this.caseFile().clues.map((c) => c.id);
  }

  private clueNames(): string[] {
    return this.caseFile().clues.map((c) => c.name);
  }

  private judgeOptions(): JudgeOption[] {
    const state = this.mirror;
    const caseFile = this.caseFile();
    return caseFile.finalChoices.map((choice) => {
      const available = choice.requiresFlag === 'proofB' ? Engine.canPublic(state) : Engine.canPrivate(state);
      const need = caseFile.chains.find((c) => c.passFlagId === choice.requiresFlag);
      const have = need === undefined ? 0 : this.controller.chainProgress(need.id);
      const total = need === undefined ? 0 : need.clueIds.length;
      return new JudgeOption(choice.id, choice.label, available,
        available ? '' : `证据链不完整：${need?.name ?? '线索'} ${have}/${total}`);
    });
  }

  private endingName(): string {
    const state = this.mirror;
    const found = this.caseFile().endings.find((e) => e.id === state.endingId);
    return found === undefined ? '未知结局' : found.name;
  }

  private endingSegments(): string[] {
    const state = this.mirror;
    const found = this.caseFile().endings.find((e) => e.id === state.endingId);
    return found === undefined ? [] : found.segments;
  }

  private async reloadSlots(): Promise<void> {
    const slots: SlotInfo[] = await this.controller.listSlots();
    const rows: SlotRow[] = [];
    rows.push(new SlotRow(0, '自动存档',
      slots.find((s) => s.slotId === 0) === undefined ? '' :
        `${slots.find((s) => s.slotId === 0)?.stage ?? ''} · 线索 ${slots.find((s) => s.slotId === 0)?.clueCount ?? 0}`,
      slots.find((s) => s.slotId === 0) === undefined));
    for (let i = 1; i <= 3; i++) {
      const hit = slots.find((s) => s.slotId === i);
      rows.push(new SlotRow(i, `存档槽 ${i}`,
        hit === undefined ? '' : `${hit.stage} · 线索 ${hit.clueCount} · seq ${hit.seq}`, hit === undefined));
    }
    this.slotRows = rows;
  }

  // ---------------------------------------------------------------- 事件

  private async acceptCase(): Promise<void> {
    try {
      console.info('[campus] acceptCase start');
      const result = await this.controller.applyNode('N01');
      console.info(`[campus] acceptCase apply ok=${result.ok} err=${result.error ?? ''}`);
      if (!result.ok) {
        this.showToast(`接受委托失败：${result.error ?? '未知原因'}`);
        return;
      }
      this.refresh();
      this.nav('hub');
      try {
        await this.controller.autoSave();
      } catch (e) {
        console.error(`[campus] autoSave failed: ${e}`);
      }
    } catch (e) {
      console.error(`[campus] acceptCase threw: ${e}`);
      this.showToast(`异常：${e}`);
    }
  }

  private async enterScene(sceneId: string): Promise<void> {
    this.sceneId = sceneId;
    this.bodyTitle = '';
    this.bodyText = '';
    this.nav('scene');
  }

  private async tapHotspot(nodeId: string): Promise<void> {
    const caseFile = this.caseFile();
    const node = caseFile.nodes.find((n) => n.id === nodeId);
    const nodeState = Engine.nodeState(this.mirror, caseFile, nodeId);
    if (nodeState === NodeState.LOCKED) {
      this.showToast(node?.unlockCond === undefined ? '还不能调查这里' : `还差些条件：${this.describeCond(nodeId)}`);
      return;
    }
    if (nodeState === NodeState.CLOSED) {
      this.showToast('这里已经被你之前的选择封死了');
      return;
    }
    if (nodeState === NodeState.DONE) {
      this.bodyTitle = node?.title ?? '';
      this.bodyText = node?.body ?? '';
      return;
    }
    const beforeClues = this.mirror.ownedClues.length;
    const result = await this.controller.applyNode(nodeId);
    if (!result.ok) {
      this.showToast(`调查失败：${result.error ?? ''}`);
      return;
    }
    this.bodyTitle = node?.title ?? '';
    this.bodyText = node?.body ?? '';
    this.refresh();
    if (this.mirror.ownedClues.length > beforeClues) {
      this.showToast(`获得线索（${this.mirror.ownedClues.length}/${this.controller.clueTotal()}）`);
    }
    if (this.mirror.stage === Stage.DEDUCE) {
      this.showToast('进入验证阶段：去推理工坊');
    }
    await this.controller.autoSave();
  }

  private describeCond(nodeId: string): string {
    const node = this.caseFile().nodes.find((n) => n.id === nodeId);
    if (node === undefined) {
      return '条件未知';
    }
    const cond = node.unlockCond;
    const parts: string[] = [];
    (cond.allClues ?? []).forEach((id: string) => {
      const clue = this.caseFile().clues.find((c) => c.id === id);
      parts.push(clue === undefined ? id : clue.name);
    });
    (cond.allFlags ?? []).forEach((flag: string) => parts.push(flag));
    return parts.length === 0 ? '还不清楚' : parts.join('、');
  }

  private async linkClues(a: string, b: string): Promise<void> {
    const outcome = await this.controller.linkClues(a, b);
    this.refresh();
    if (!outcome.ok) {
      this.showToast(outcome.reason === 'SAME_CLUE' ? '不能和自己连线' :
        (outcome.reason === 'NOT_OWNED' ? '还没拿到这两条线索' : '这两条线索没有直接关系'));
      return;
    }
    this.showToast('线索连上了：一条结论成立');
    await this.controller.autoSave();
  }

  private async submitProof(stageId: string, picked: string[]): Promise<void> {
    const ok = await this.controller.submitProof(stageId, picked);
    this.refresh();
    this.showToast(ok ? '结论成立，证据链推进了' : '这个组合不成立，换个角度（提示不扣分）');
    if (ok) {
      await this.controller.autoSave();
    }
  }

  private async openJudge(): Promise<void> {
    const result = await this.controller.enterJudge();
    if (!result.ok) {
      this.showToast('证据还不足：先去线索板把链补全');
      return;
    }
    this.refresh();
    this.nav('judge');
  }

  private async chooseFinal(choiceId: string): Promise<void> {
    const result = await this.controller.chooseFinal(choiceId);
    if (!result.ok) {
      this.showToast('这个判断不被接受（证据链不完整）');
      return;
    }
    const finished = await this.controller.finish();
    if (finished.ok) {
      await this.controller.autoSave();
    }
    this.refresh();
    this.nav('ending');
  }

  private async restartGame(): Promise<void> {
    await this.controller.restart();
    this.refresh();
    this.nav('brief');
    this.showToast('已重开本局');
  }

  private askRestart(): void {
    this.getUIContext().showAlertDialog({
      title: '重开本局',
      message: '会清空当前进度（存档槽保留），确定吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        },
      },
      secondaryButton: {
        value: '重开',
        fontColor: $r('app.color.danger_text'),
        action: () => {
          this.restartGame();
        },
      },
    });
  }

  private async openGallery(): Promise<void> {
    await this.reloadGallery();
    this.nav('gallery');
  }

  private async openSlots(): Promise<void> {
    await this.reloadSlots();
    this.nav('slots');
  }

  private async saveSlot(slotId: number): Promise<void> {
    await this.controller.saveSlot(slotId, `存档槽 ${slotId}`);
    await this.reloadSlots();
    this.showToast(`已存入槽 ${slotId}`);
  }

  private async loadSlot(slotId: number): Promise<void> {
    const ok = await this.controller.loadSlot(slotId);
    await this.reloadSlots();
    this.refresh();
    if (ok) {
      this.showToast('已读档，回到存档时刻');
      this.view = this.mirror.stage === Stage.FINISHED ? 'ending' : 'hub';
    } else {
      this.showToast('读档失败：槽内数据不可用');
    }
  }

  private async deleteSlot(slotId: number): Promise<void> {
    await this.controller.deleteSlot(slotId);
    await this.reloadSlots();
    this.showToast('存档已删除');
  }

  // ---------------------------------------------------------------- UI

  /** 返回键：结局/设置/收集册/存档一律先回主页，避免误退出（01 §FR-10）。 */
  onBackPress(): boolean {
    if (this.view === 'hub' || this.view === 'brief') {
      return false;
    }
    this.nav(this.view === 'ending' ? 'hub' : 'hub');
    return true;
  }

  build() {
    Column() {
      if (!this.ready) {
        Column({ space: 10 }) {
          LoadingProgress().width(48).height(48)
          Text('正在读取案件与进度…').fontSize(13).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        HudBar({
          stageText: this.stageText,
          objective: this.objective,
          clueText: this.clueText,
          progress: this.progress,
          chainBText: this.chainBText,
          chainAText: this.chainAText,
          ready: this.readyChip && this.mirror.stage !== Stage.FINISHED,
          savedText: this.savedText,
          showBack: this.view === 'scene' || this.view === 'board' ||
            this.view === 'deduce' || this.view === 'slots' ||
            this.view === 'gallery' || this.view === 'settings',
          onBack: () => this.nav('hub'),
          onBoard: () => this.nav('board'),
          onSlots: () => {
            this.openSlots();
          },
          onGallery: () => {
            this.openGallery();
          },
          onBrief: () => this.nav('brief'),
          onSettings: () => this.nav('settings'),
          onRestart: () => this.askRestart(),
        })

        Column() {
          if (this.view === 'brief') {
            BriefView({
              fs: this.fontScale,
              title: this.caseFile().title,
              subtitle: this.caseFile().subtitle ?? '',
              client: this.caseFile().brief.client,
              summary: this.caseFile().brief.summary,
              objectives: this.caseFile().brief.objectives,
              timeline: (this.caseFile().brief.timeline ?? []).map((t) => `${t.time}  ${t.text}`),
              accepted: this.mirror.stage !== Stage.PROLOGUE && this.mirror.stage !== Stage.ACCEPT,
              onAccept: () => {
                this.acceptCase();
              },
              onEnter: () => this.nav('hub'),
            })
          } else if (this.view === 'hub') {
            HubView({
              fs: this.fontScale,
              cards: this.sceneCards(),
              onEnter: (sceneId: string) => {
                this.enterScene(sceneId);
              },
              onBoard: () => this.nav('board'),
            })
          } else if (this.view === 'scene') {
            SceneView({
              fs: this.fontScale,
              sceneName: this.caseFile().scenes.find((s) => s.id === this.sceneId)?.name ?? '',
              sceneDesc: this.caseFile().scenes.find((s) => s.id === this.sceneId)?.desc ?? '',
              sceneFx: this.caseFile().scenes.find((s) => s.id === this.sceneId)?.enterFx ?? 'warm',
              hotspots: this.hotspotItems(),
              bodyTitle: this.bodyTitle,
              bodyText: this.bodyText,
              onTap: (nodeId: string) => {
                this.tapHotspot(nodeId);
              },
            })
          } else if (this.view === 'board') {
            ClueBoardView({
              fs: this.fontScale,
              cards: this.clueCards(),
              chainBText: this.chainBText,
              chainAText: this.chainAText,
              canDeduce: this.mirror.stage === Stage.DEDUCE || this.readyChip,
              links: [],
              conclusions: this.conclusions(),
              edges: this.ruleEdges(),
              themeKey: this.themeKey,
              chainBIds: this.chainIds('CH-B'),
              chainAIds: this.chainIds('CH-A'),
              onLink: (a: string, b: string) => {
                this.linkClues(a, b);
              },
              onDeduce: () => this.nav('deduce'),
            })
          } else if (this.view === 'deduce') {
            DeduceView({
              fs: this.fontScale,
              cards: this.proveCards(),
              clueIds: this.clueIds(),
              clueNames: this.clueNames(),
              onSubmit: (stageId: string, picked: string[]) => {
                this.submitProof(stageId, picked);
              },
            })
          } else if (this.view === 'judge') {
            JudgeView({
              fs: this.fontScale,
              options: this.judgeOptions(),
              ready: this.readyChip && this.mirror.stage !== Stage.FINISHED,
              onChoose: (choiceId: string) => {
                this.chooseFinal(choiceId);
              },
            })
          } else if (this.view === 'ending') {
            EndingView({
              fs: this.fontScale,
              endingName: this.endingName(),
              segments: this.endingSegments(),
              onRestart: () => {
                this.restartGame();
              },
              onHome: () => {
                this.restartGame();
              },
            })
          } else if (this.view === 'gallery') {
            GalleryView({ fs: this.fontScale, rows: this.galleryRows })
          } else if (this.view === 'settings') {
            SettingsView({
              fs: this.fontScale,
              reduceMotion: this.reduceMotion,
              contentVersion: this.contentVersion,
              validationText: this.controller.validationErrors.length === 0 ? '通过' :
                `${this.controller.validationErrors.length} 个问题`,
              fontScale: this.fontScale,
              restoredFrom: this.controller.restoredFrom,
              themeMode: this.themeMode,
              onThemeMode: (mode: string) => {
                this.applyTheme(mode, true);
              },
              onToggleReduceMotion: (value: boolean) => {
                this.controller.setReduceMotion(value);
                this.reduceMotion = value;
              },
              onFontScale: (value: number) => {
                this.fontScale = value;
                Prefs.putNumber(Prefs.KEY_FONT_SCALE, value);
              },
              onClearProgress: () => this.askRestart(),
            })
          } else if (this.view === 'slots') {
            SlotsView({
              fs: this.fontScale,
              rows: this.slotRows,
              canSave: this.mirror.stage !== Stage.PROLOGUE,
              onSave: (slotId: number) => {
                this.saveSlot(slotId);
              },
              onLoad: (slotId: number) => {
                this.loadSlot(slotId);
              },
              onDelete: (slotId: number) => {
                this.deleteSlot(slotId);
              },
              onRestart: () => this.askRestart(),
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .opacity(this.transitionFlag ? 1 : 0.2)
        .animation({ duration: 220, curve: Curve.EaseOut })

        if (this.view !== 'ending') {
          Row({ space: 8 }) {
            Text('地图')
              .fontSize(13 * this.fontScale)
              .fontColor(this.view === 'hub' || this.view === 'brief' ? $r('app.color.on_brand') : $r('app.color.brand_text'))
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.view === 'hub' || this.view === 'brief' ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
              .borderRadius(13)
              .onClick(() => this.nav(this.mirror.stage === Stage.PROLOGUE || this.mirror.stage === Stage.ACCEPT ? 'brief' : 'hub'))
            Text('线索板')
              .fontSize(13 * this.fontScale)
              .fontColor(this.view === 'board' ? $r('app.color.on_brand') : $r('app.color.brand_text'))
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.view === 'board' ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
              .borderRadius(13)
              .onClick(() => this.nav('board'))
            Text('推理')
              .fontSize(13 * this.fontScale)
              .fontColor(this.view === 'deduce' ? $r('app.color.on_brand') : $r('app.color.brand_text'))
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.view === 'deduce' ? $r('app.color.brand_solid') : $r('app.color.chip_bg'))
              .borderRadius(13)
              .onClick(() => this.nav('deduce'))
            Text(this.readyChip && this.mirror.stage !== Stage.FINISHED ? '去判断' : '判断')
              .fontSize(13 * this.fontScale)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.readyChip && this.mirror.stage !== Stage.FINISHED
                ? $r('app.color.on_brand') : $r('app.color.text_secondary'))
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.readyChip && this.mirror.stage !== Stage.FINISHED
                ? $r('app.color.brand_solid') : $r('app.color.surface_muted'))
              .borderRadius(13)
              .onClick(() => {
                if (this.readyChip && this.mirror.stage !== Stage.FINISHED) {
                  this.openJudge();
                } else {
                  this.showToast('证据链还没成立，先去把线索连起来');
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 14 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: { top: 1 }, color: $r('app.color.border') })
        }
      }

      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(13)
          .fontColor($r('app.color.on_toast'))
          .backgroundColor($r('app.color.toast_bg'))
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .borderRadius(20)
          .margin({ bottom: 90 })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 200 }),
            TransitionEffect.OPACITY.animation({ duration: 200 })),
          )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
