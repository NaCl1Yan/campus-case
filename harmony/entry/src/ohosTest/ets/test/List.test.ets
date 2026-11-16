import domainTest from './Domain.test';
import fixtureTest from './FixtureRunner.test';

/**
 * Hypium 测试入口（DevEco 会扫描 ohosTest 下的 List.test.ets）。
 * 运行：hvigorw test，或在 DevEco 里右键 ohosTest → Run。
 *
 * 依赖：ohosTest 的 rawfile 里必须有 case/campus_001.json
 * （仓库根执行 powershell -File tools/sync-case.ps1 或 python tools/sync-case.ps1）。
 */
export default function testsuite() {
  domainTest();
  fixtureTest();
}
