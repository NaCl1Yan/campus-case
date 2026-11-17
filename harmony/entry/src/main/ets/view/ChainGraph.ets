import { common } from '@kit.AbilityKit';

/** 一条规则在证据链图上的表现（a/b 为线索 id，done 表示已成立）。 */
export class RuleEdge {
  a: string;
  b: string;
  label: string;
  done: boolean;

  constructor(a: string, b: string, label: string, done: boolean) {
    this.a = a;
    this.b = b;
    this.label = label;
    this.done = done;
  }
}

/**
 * 证据链图（Canvas）：两条链各三个节点，规则画成连线。
 * 已成立=绿色实线 + 圆点；未成立=灰色细线。
 *
 * Canvas 的 fillStyle 只接受字符串，拿不到 $r 资源，因此用 resourceManager.getColorSync
 * 在绘制时把颜色资源解析成 #RRGGBB —— 这样深色模式切换后重绘也能拿到对应颜色。
 */
@Component
export struct ChainGraph {
  @Prop @Watch('onEdgesChange') edges: RuleEdge[] = [];
  @Prop chainBIds: string[] = [];
  @Prop chainAIds: string[] = [];
  @Prop fs: number = 1;
  @Prop @Watch('onEdgesChange') themeKey: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State widthVp: number = 320;
  @State heightVp: number = 150;

  private graphHeight(): number {
    return this.fs > 1.2 ? 104 : 126;
  }

  onEdgesChange(): void {
    this.draw();
  }

  /** 把颜色资源解析成 Canvas 可用的 #RRGGBB。 */
  private colorOf(res: Resource): string {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const value: number = ctx.resourceManager.getColorSync(res.id as number);
      const argb: number = value >>> 0;
      const r: number = (argb >> 16) & 0xFF;
      const g: number = (argb >> 8) & 0xFF;
      const b: number = argb & 0xFF;
      const hex = (n: number): string => n.toString(16).padStart(2, '0');
      return `#${hex(r)}${hex(g)}${hex(b)}`;
    } catch (e) {
      return '#9CA3AF';
    }
  }

  private nodeX(index: number, total: number): number {
    const ratio = total <= 1 ? 0.5 : 0.16 + (index * (0.68 / (total - 1)));
    return this.widthVp * ratio;
  }

  private draw(): void {
    const w = this.widthVp;
    if (w <= 0) {
      return;
    }
    const ctx = this.ctx;
    ctx.clearRect(0, 0, w, this.heightVp);

    const cTer = this.colorOf($r('app.color.text_tertiary'));
    const cSuccess = this.colorOf($r('app.color.success_text'));
    const cBorderStrong = this.colorOf($r('app.color.border_strong'));
    const cSurface = this.colorOf($r('app.color.surface'));
    const cBrand = this.colorOf($r('app.color.brand_text'));

    const yB = 46;
    const yA = 112;
    const pos = new Map<string, number[]>();
    this.chainBIds.forEach((id: string, i: number) => {
      pos.set(id, [this.nodeX(i, this.chainBIds.length), yB]);
    });
    this.chainAIds.forEach((id: string, i: number) => {
      pos.set(id, [this.nodeX(i, this.chainAIds.length), yA]);
    });

    // 链标题
    ctx.fillStyle = cTer;
    ctx.font = '11vp sans-serif';
    ctx.fillText('行动线', 6, yB - 22);
    ctx.fillText('动机线', 6, yA - 22);

    // 规则连线
    this.edges.forEach((edge: RuleEdge) => {
      const pa = pos.get(edge.a);
      const pb = pos.get(edge.b);
      if (pa === undefined || pb === undefined) {
        return;
      }
      ctx.beginPath();
      ctx.lineWidth = edge.done ? 2.5 : 1;
      ctx.strokeStyle = edge.done ? cSuccess : cBorderStrong;
      ctx.moveTo(pa[0], pa[1]);
      const midX = (pa[0] + pb[0]) / 2;
      ctx.quadraticCurveTo(midX, (pa[1] + pb[1]) / 2 - 14, pb[0], pb[1]);
      ctx.stroke();

      ctx.fillStyle = edge.done ? cSuccess : cTer;
      ctx.font = '10vp sans-serif';
      ctx.fillText(edge.label, midX - 6, (pa[1] + pb[1]) / 2 - 16);
    });

    // 节点
    pos.forEach((xy: number[], id: string) => {
      ctx.beginPath();
      ctx.arc(xy[0], xy[1], 13, 0, Math.PI * 2);
      ctx.fillStyle = cSurface;
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = cBrand;
      ctx.stroke();
      ctx.fillStyle = cBrand;
      ctx.font = '11vp sans-serif';
      ctx.fillText(id, xy[0] - 7, xy[1] + 4);
    });
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text('证据链图')
          .fontSize(12 * this.fs)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('绿线＝已成立')
          .fontSize(10 * this.fs)
          .fontColor($r('app.color.success_text'))
      }
      .width('100%')

      Canvas(this.ctx)
        .width('100%')
        .height(this.graphHeight())
        .onReady(() => this.draw())
        .onAreaChange((_old: Area, now: Area) => {
          this.widthVp = Number(now.width);
          this.heightVp = Number(now.height);
          this.draw();
        })
        .hitTestBehavior(HitTestMode.None)

      Text('灰线＝还没连上的组合；连线顺序不影响结果')
        .fontSize(10 * this.fs)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.border') })
  }
}
