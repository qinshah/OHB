@Observed
export class IndexViewModel {
  areaWidth: number = 360
  hidden = false
  idx = 0
  static readonly instance = new IndexViewModel()

  /**
   * 底部栏滚动动画注入点：仅 HDS 页加载时挂载（HdsTabsController），
   * 普通 Tabs 回退页无此能力，保持 undefined 即可。
   */
  private tabAnimator: ((show: boolean) => void) | undefined = undefined

  private constructor() {
  }

  setTabAnimator(animator: ((show: boolean) => void) | undefined): void {
    this.tabAnimator = animator
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
      this.tabAnimator?.(true)
      this.hidden = false
    } else if (offset > 2 && !this.hidden) {
      this.tabAnimator?.(false)
      this.hidden = true
    }
  }
}
