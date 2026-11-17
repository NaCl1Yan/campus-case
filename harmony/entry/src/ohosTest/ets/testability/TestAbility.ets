import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

/**
 * 测试宿主 Ability：Hypium 必须跑在一个已启动的 UIAbility 里，
 * 否则 `abilityDelegator.print()` 的 Promise 不会 resolve，
 * 表现为 Run 窗口一直停在「正在运行测试…」（OHOS_REPORT 一行都不出）。
 * DevEco 生成的脚手架同样使用 TestAbility 这个名称。
 */
export default class TestAbility extends UIAbility {
  private delegator: abilityDelegatorRegistry.AbilityDelegator =
    abilityDelegatorRegistry.getAbilityDelegator();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[campus-case-test] TestAbility onCreate');
    const args = abilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(this.delegator, args, testsuite);
  }

  onDestroy(): void {
    console.info('[campus-case-test] TestAbility onDestroy');
    this.delegator.finishTest('TestAbility onDestroy unexpectedly!', -2, () => {});
  }
}
