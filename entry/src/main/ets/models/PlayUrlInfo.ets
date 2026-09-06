/** 画质选项（playurl 响应 accept_quality + support_formats 组装，qn 与 B 站清晰度代码一致） */
export class QualityOption {
  /** 清晰度代码（qn），如 80=1080P、120=4K */
  qn: number = 0;
  /** 完整描述（列表项显示，来自 support_formats.new_desc，如「1080P 高清」） */
  desc: string = '';
  /** 短文案（控制栏按钮显示，来自 support_formats.display_desc，如「1080P」） */
  shortDesc: string = '';
  /** 角标文案（如「大会员」，非会员画质为空） */
  superscript: string = '';
}

/** 播放地址模型（V1：muxed MP4 durl） */
export class PlayUrlInfo {
  url: string = '';
  /** 清晰度代码（qn），如 80=1080P */
  quality: number = 0;
  /** 清晰度文案 */
  qualityDesc: string = '';
  /** 时长（毫秒） */
  timelength: number = 0;
  /** 备用链接 */
  backupUrls: string[] = [];
  /** 可用画质列表（画质切换入口数据源，按清晰度从高到低） */
  qualityOptions: QualityOption[] = [];

  /** 按 qn 查找画质选项（找不到返回 null） */
  findOption(qn: number): QualityOption | null {
    for (const o of this.qualityOptions) {
      if (o.qn === qn) {
        return o;
      }
    }
    return null;
  }
}
