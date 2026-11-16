import { CaseFile, ChainDef, ClueDef, Condition, CombineRuleDef, EndingDef, EventNodeDef, SceneDef } from './Types';

/**
 * 内容加载与校验（01 文档 FR-16）。
 * 解析失败 / 校验失败都收集全部错误后一次性返回，不 fail-fast、不崩溃。
 */
export class CaseLoader {

  static parse(text: string): CaseFile {
    return JSON.parse(text) as CaseFile;
  }

  /** 校验清单与 FR-16 的 8 条一一对应；返回空数组表示通过。 */
  static validate(caseFile: CaseFile): string[] {
    const errors: string[] = [];

    if (caseFile.scenes.length < 3) {
      errors.push(`规模下限不满足: scenes 需 ≥3，实际 ${caseFile.scenes.length}`);
    }
    if (caseFile.nodes.length < 12) {
      errors.push(`规模下限不满足: nodes 需 ≥12，实际 ${caseFile.nodes.length}`);
    }
    if (caseFile.clues.length < 6) {
      errors.push(`规模下限不满足: clues 需 ≥6，实际 ${caseFile.clues.length}`);
    }
    if (caseFile.rules.length < 3) {
      errors.push(`规模下限不满足: rules 需 ≥3，实际 ${caseFile.rules.length}`);
    }
    if (caseFile.chains.length < 2) {
      errors.push(`规模下限不满足: chains 需 ≥2，实际 ${caseFile.chains.length}`);
    }
    if (caseFile.endings.length < 2) {
      errors.push(`规模下限不满足: endings 需 ≥2，实际 ${caseFile.endings.length}`);
    }

    const sceneIds: Set<string> = new Set<string>();
    caseFile.scenes.forEach((s: SceneDef) => sceneIds.add(s.id));
    const nodeIds: Set<string> = new Set<string>();
    caseFile.nodes.forEach((n: EventNodeDef) => nodeIds.add(n.id));
    const clueIds: Set<string> = new Set<string>();
    caseFile.clues.forEach((c: ClueDef) => clueIds.add(c.id));
    const chainIds: Set<string> = new Set<string>();
    caseFile.chains.forEach((c: ChainDef) => chainIds.add(c.id));
    const choiceIds: Set<string> = new Set<string>();
    caseFile.finalChoices.forEach((c) => choiceIds.add(c.id));

    caseFile.scenes.forEach((scene: SceneDef) => {
      if (scene.hotspots.length === 0) {
        errors.push(`场景 ${scene.id} 没有热点`);
      }
      scene.hotspots.forEach((h) => {
        const node = CaseLoader.findNode(caseFile, h.nodeId);
        if (node === undefined) {
          errors.push(`热点 ${h.id} 指向不存在的节点 ${h.nodeId}`);
        } else if (node.sceneId !== scene.id) {
          errors.push(`热点 ${h.id} 所在场景 ${scene.id} 与节点场景 ${node.sceneId} 不一致`);
        }
      });
    });

    caseFile.nodes.forEach((node: EventNodeDef) => {
      if (!sceneIds.has(node.sceneId)) {
        errors.push(`节点 ${node.id} 指向不存在的场景 ${node.sceneId}`);
      }
      const effect = node.effect;
      const hasEffect = (effect.grantClues ?? []).length > 0 ||
        (effect.setFlags ?? []).length > 0 ||
        (effect.unlockScenes ?? []).length > 0 ||
        (effect.closeNodes ?? []).length > 0 ||
        effect.stage !== undefined;
      if (!hasEffect) {
        errors.push(`节点 ${node.id} 没有任何状态效果`);
      }
      (effect.grantClues ?? []).forEach((c: string) => {
        if (!clueIds.has(c)) {
          errors.push(`节点 ${node.id} 产出不存在的线索 ${c}`);
        }
      });
      (effect.unlockScenes ?? []).forEach((s: string) => {
        if (!sceneIds.has(s)) {
          errors.push(`节点 ${node.id} 解锁不存在的场景 ${s}`);
        }
      });
      const closed = (effect.closeNodes ?? []).concat(node.exclusiveWith ?? []);
      closed.forEach((n: string) => {
        if (!nodeIds.has(n)) {
          errors.push(`节点 ${node.id} 关闭不存在的节点 ${n}`);
        }
        if (n === node.id) {
          errors.push(`节点 ${node.id} 关闭了自己`);
        }
      });
    });

    caseFile.rules.forEach((rule: CombineRuleDef) => {
      rule.inputs.forEach((c: string) => {
        if (!clueIds.has(c)) {
          errors.push(`规则 ${rule.id} 引用不存在的线索 ${c}`);
        }
      });
      if (!chainIds.has(rule.chainId)) {
        errors.push(`规则 ${rule.id} 指向不存在的链 ${rule.chainId}`);
      }
      if (rule.inputs.length !== 2 || rule.inputs[0] === rule.inputs[1]) {
        errors.push(`规则 ${rule.id} 的输入非法`);
      }
    });

    caseFile.chains.forEach((chain: ChainDef) => {
      chain.clueIds.forEach((c: string) => {
        if (!clueIds.has(c)) {
          errors.push(`链 ${chain.id} 引用不存在的线索 ${c}`);
        }
      });
      if (chain.ruleFlagIds.length === 0) {
        errors.push(`链 ${chain.id} 没有规则 flag`);
      }
    });

    caseFile.proveStages.forEach((p) => {
      p.answer.forEach((c: string) => {
        if (!clueIds.has(c)) {
          errors.push(`关卡 ${p.id} 答案引用不存在的线索 ${c}`);
        }
      });
      if (p.answer.length !== p.slots) {
        errors.push(`关卡 ${p.id} 槽位与答案数量不一致`);
      }
    });

    caseFile.endings.forEach((ending: EndingDef) => {
      if (!choiceIds.has(ending.choiceId)) {
        errors.push(`结局 ${ending.id} 指向不存在的判断选项 ${ending.choiceId}`);
      }
      (ending.requires.allClues ?? []).forEach((c: string) => {
        if (!clueIds.has(c)) {
          errors.push(`结局 ${ending.id} 条件引用不存在的线索 ${c}`);
        }
      });
    });

    const produced: Set<string> = new Set<string>();
    caseFile.nodes.forEach((n: EventNodeDef) => {
      (n.effect.grantClues ?? []).forEach((c: string) => produced.add(c));
    });
    clueIds.forEach((c: string) => {
      if (!produced.has(c)) {
        errors.push(`线索 ${c} 没有任何节点产出`);
      }
    });

    let hasStartScene = false;
    caseFile.scenes.forEach((s: SceneDef) => {
      if (CaseLoader.isEmptyCondition(s.unlockCond)) {
        hasStartScene = true;
      }
    });
    if (!hasStartScene) {
      errors.push('没有任何场景在开局可用（缺少空 unlockCond 的起始场景）');
    }

    if (caseFile.endings.length >= 2) {
      const first = (caseFile.endings[0].requires.allFlags ?? []).sort().join(',');
      const second = (caseFile.endings[1].requires.allFlags ?? []).sort().join(',');
      if (first === second) {
        errors.push('两个结局的 requires 完全相同，无法互斥');
      }
    }

    return errors;
  }

  private static findNode(caseFile: CaseFile, nodeId: string): EventNodeDef | undefined {
    return caseFile.nodes.find((n: EventNodeDef) => n.id === nodeId);
  }

  private static isEmptyCondition(cond: Condition | undefined): boolean {
    if (cond === undefined) {
      return true;
    }
    return (cond.allClues ?? []).length === 0 &&
      (cond.anyClues ?? []).length === 0 &&
      (cond.allFlags ?? []).length === 0 &&
      (cond.anyFlags ?? []).length === 0 &&
      (cond.noneFlags ?? []).length === 0 &&
      cond.minStage === undefined &&
      (cond.closedNodes ?? []).length === 0;
  }
}
