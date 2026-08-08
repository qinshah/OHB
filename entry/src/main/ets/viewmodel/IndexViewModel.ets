import { HdsAnimationMode, HdsTabsController } from "@kit.UIDesignKit";

@Observed
export class IndexViewModel {
  areaWidth: number = 360
  hidden = false
  idx = 0
  readonly cntlr = new HdsTabsController();
  static readonly instance = new IndexViewModel()

  private constructor() {
  }

  gridColumns = (): number => {
    if (this.areaWidth >= 840) {
      return 4;
    }
    if (this.areaWidth >= 600) {
      return 3;
    }
    return 2;
  }
  onScroll = (offset: number, state: ScrollState) => {
    if (offset < -2 && this.hidden) {
      this.cntlr.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      this.hidden = false
    } else if (offset > 2 && !this.hidden) {
      this.cntlr.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      this.hidden = true
    }
  }
}
