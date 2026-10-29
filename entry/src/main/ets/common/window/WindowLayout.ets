/**
 * 窗口尺寸断点（单位 vp）
 *
 * 全应用唯一的一套宽度断点与网格列数映射：页面只读这里的结果，
 * 不再各自维护 600 / 840 / 1200 等阈值字面量。
 */
export enum SizeClass {
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

/** AppStorage 键：主窗口宽度（vp） */
export const KEY_WIN_WIDTH_VP = 'winWidthVp';
/** AppStorage 键：主窗口高度（vp） */
export const KEY_WIN_HEIGHT_VP = 'winHeightVp';

export class WindowLayout {
  /** 中屏起点（vp） */
  static readonly MD_MIN: number = 600;
  /** 宽屏起点（vp）：触发侧边导航与视频页左右分栏 */
  static readonly LG_MIN: number = 840;
  /** 超宽屏起点（vp） */
  static readonly XL_MIN: number = 1200;

  /** 网格列间距（vp） */
  static readonly CARD_GAP: number = 8;
  /** 单张视频卡片最大宽度（vp） */
  static readonly CARD_MAX_WIDTH: number = 240;
  /** 宽屏侧边导航宽度（vp） */
  static readonly RAIL_WIDTH: number = 96;
  /** 尺寸未知时的兜底宽度（vp），对齐手机竖屏 */
  static readonly DEFAULT_WIDTH_VP: number = 360;

  static sizeClassOf(widthVp: number): SizeClass {
    if (widthVp >= WindowLayout.XL_MIN) {
      return SizeClass.XL;
    }
    if (widthVp >= WindowLayout.LG_MIN) {
      return SizeClass.LG;
    }
    if (widthVp >= WindowLayout.MD_MIN) {
      return SizeClass.MD;
    }
    return SizeClass.SM;
  }

  /** 横向视频判定阈值：宽高比大于该值才锁横向 */
  static readonly LANDSCAPE_VIDEO_ASPECT: number = 1.2;

  /** 是否横向视频（仅它决定全屏时要不要锁横向，与设备形态无关） */
  static isLandscapeVideo(aspectRatio: number): boolean {
    return aspectRatio > WindowLayout.LANDSCAPE_VIDEO_ASPECT;
  }

  /** 是否宽屏（侧边导航 / 视频页分栏） */
  static isWide(widthVp: number): boolean {
    return widthVp >= WindowLayout.LG_MIN;
  }

  /** 视频流列数：2 / 3 / 4 / 6 */
  static gridColumns(widthVp: number): number {
    switch (WindowLayout.sizeClassOf(widthVp)) {
      case SizeClass.XL:
        return 6;
      case SizeClass.LG:
        return 4;
      case SizeClass.MD:
        return 3;
      default:
        return 2;
    }
  }

  /** 网格内容区最大宽度：保证单卡不超过 CARD_MAX_WIDTH，多余宽度作为居中留白 */
  static gridMaxWidth(columns: number): number {
    return columns * WindowLayout.CARD_MAX_WIDTH + (columns - 1) * WindowLayout.CARD_GAP;
  }
}
