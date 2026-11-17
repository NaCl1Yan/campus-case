/**
 * 主题应用状态（进程内静态）。
 *
 * 为什么需要它：`ApplicationContext.setColorMode()` 会触发配置变更、Ability 重建；
 * 若每次 bootstrap 都调用一次，就会形成「重建 → 再设置 → 再重建」的循环，
 * 表现为界面停在旧帧、点击无响应。用一个进程级标记保证每次启动只应用一次。
 */
export class ThemeState {
  static applied: boolean = false;
  static current: string = 'follow';
}
