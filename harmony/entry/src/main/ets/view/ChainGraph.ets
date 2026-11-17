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
 * 单独占一块区域，避免直线穿过线索卡导致视觉混乱。
 */
@Component
export struct ChainGraph {
  @Prop @Watch('onEdgesChange') edges: RuleEdge[] = [];
  @Prop chainBIds: string[] = [];
  @Prop chainAIds: string[] = [];
  @Prop fs: number = 1;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State widthVp: number = 320;
  @State heightVp: number = 150;

  private graphHeight(): number {
    return this.fs > 1.2 ? 118 : 150;
  }

  onEdgesChange(): void {
    this.draw();
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
    ctx.fillStyle = '#9CA3AF';
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
      ctx.strokeStyle = edge.done ? '#2E7D32' : '#D1D5DB';
      ctx.moveTo(pa[0], pa[1]);
      const midX = (pa[0] + pb[0]) / 2;
      ctx.quadraticCurveTo(midX, (pa[1] + pb[1]) / 2 - 14, pb[0], pb[1]);
      ctx.stroke();

      ctx.fillStyle = edge.done ? '#2E7D32' : '#9CA3AF';
      ctx.font = '10vp sans-serif';
      ctx.fillText(edge.label, midX - 6, (pa[1] + pb[1]) / 2 - 16);
    });

    // 节点
    pos.forEach((xy: number[], id: string) => {
      ctx.beginPath();
      ctx.arc(xy[0], xy[1], 13, 0, Math.PI * 2);
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = '#26324A';
      ctx.stroke();
      ctx.fillStyle = '#26324A';
      ctx.font = '11vp sans-serif';
      ctx.fillText(id, xy[0] - 7, xy[1] + 4);
    });
  }

  build() {
    Column({ space: 4 }) {
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
      Text('绿线=已成立的组合，灰线=还没连上的组合')
        .fontSize(10)
        .fontColor('#9CA3AF')
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FAFAFB')
    .borderRadius(10)
    .border({ width: 1, color: '#E5E7EB' })
  }
}
