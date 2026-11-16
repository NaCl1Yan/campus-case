import domainTest from './Domain.test';

/**
 * Hypium 测试入口（DevEco 会扫描 ohosTest 下的 List.test.ets）。
 * 运行：hvigorw test，或在 DevEco 里右键 ohosTest → Run。
 */
export default function testsuite() {
  domainTest();
}
