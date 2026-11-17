import { abilityDelegatorRegistry } from '@kit.TestKit';
import { TestRunner } from '@ohos.application.testRunner';
import { Want } from '@kit.AbilityKit';

/**
 * 单元测试运行入口（供 `aa test -s unittest OpenHarmonyTestRunner` 使用）。
 *
 * 两个坑都在这里：
 * 1) delegator 必须在 onRun 里取。模块顶层 `getAbilityDelegator()` 可能拿到 null
 *    （runner 模块比 delegator 初始化更早），会直接 TypeError。
 * 2) 不能在这里直接调 Hypium：Hypium 的报告走 delegator.print()，
 *    需要一个已启动的 UIAbility 作为宿主（见 ets/testability/TestAbility.ets），
 *    否则 Promise 不 resolve，Run 窗口一直停在「正在运行测试…」。
 */
export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
    console.info('[campus-case-test] onPrepare');
  }

  onRun(): void {
    console.info('[campus-case-test] onRun');
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    if (delegator === null || delegator === undefined) {
      console.error('[campus-case-test] abilityDelegator is null, abort');
      return;
    }
    const args = abilityDelegatorRegistry.getArguments();
    const moduleName: string = args.parameters['-m'];
    const want: Want = {
      bundleName: args.bundleName,
      abilityName: 'TestAbility',
      moduleName: moduleName
    };
    console.info('[campus-case-test] start TestAbility: ' + JSON.stringify(want));
    delegator.startAbility(want, (err, data) => {
      console.info('[campus-case-test] startAbility err=' + JSON.stringify(err) + ' data=' + JSON.stringify(data));
    });
  }
}
