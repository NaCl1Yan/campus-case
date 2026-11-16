import { abilityDelegatorRegistry } from '@kit.TestKit';
import { TestRunner } from '@ohos.application.testRunner';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

/**
 * 单元测试运行入口（供 `aa test -s unittest OpenHarmonyTestRunner` 使用）。
 * DevEco GUI 会自动生成同名文件；命令行 / CI 需要仓库里自带一份，
 * 否则 aa test 会报 "Cannot find module .../OpenHarmonyTestRunner"。
 */
const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
    console.info('[campus-case-test] onPrepare');
  }

  onRun(): void {
    console.info('[campus-case-test] onRun');
    const args = abilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(abilityDelegator, args, testsuite);
  }
}
