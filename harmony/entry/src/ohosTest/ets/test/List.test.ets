import domainTest from './Domain.test';
import fixtureTest from './FixtureRunner.test';

/**
 * Hypium 测试入口（DevEco 会扫描 ohosTest 下的 List.test.ets）。
 * 运行：DevEco 里右键 entry/src/ohosTest/ets/test → Run 'Tests in test'。
 *
 * 两条约束（踩过）：
 * - describe 名只能是字母/数字/下划线/点且以字母开头，中文或括号会被判非法；
 * - 用例必须跑在已启动的 TestAbility 里（ets/testability/TestAbility.ets），
 *   否则 delegator.print() 不 resolve，Run 窗口会一直停在「正在运行测试…」。
 *
 * 依赖：rawfile 里必须有 case/campus_001.json
 * （仓库根执行 powershell -File tools/sync-case.ps1）。
 */
export default function testsuite() {
  domainTest();
  fixtureTest();
}
