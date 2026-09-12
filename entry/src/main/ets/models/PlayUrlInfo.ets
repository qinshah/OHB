/** 画质选项（playurl 响应 accept_quality + support_formats 组装，qn 与 B 站清晰度代码一致） */
export class QualityOption {
  /** 清晰度代码（qn），取值见统一枚举 `Quality`，如 80=1080P、120=4K */
  qn: number = 0;
  /** 完整描述（列表项显示，来自 support_formats.new_description，如「1080P 高清」） */
  desc: string = '';
  /** 短文案（控制栏按钮显示，来自 support_formats.display_desc，如「1080P」） */
  shortDesc: string = '';
  /** 角标文案（如「高码率」「大会员」，普通画质为空） */
  superscript: string = '';
  /** 是否仅大会员可用（本地枚举补充，接口未给角标时用于提示） */
  vip: boolean = false;
  /**
   * 是否仅 DASH 双流可用（B 站已下线 720P 以上的单文件 MP4，
   * 该档位必须走 DASH 视频轨 + 音频轨，见 PlaySource.isDash）
   */
  dashOnly: boolean = false;
}

/** 播放地址模型 */
export class PlayUrlInfo {
  /** 视频地址（单文件模式为含音轨的 MP4；DASH 模式为视频轨） */
  url: string = '';
  /** 清晰度代码（qn），取值见统一枚举 `Quality` */
  quality: number = 0;
  /** 清晰度文案 */
  qualityDesc: string = '';
  /** 时长（毫秒） */
  timelength: number = 0;
  /** 视频备用链接 */
  backupUrls: string[] = [];
  /** 可用画质列表（画质切换入口数据源，按清晰度从高到低） */
  qualityOptions: QualityOption[] = [];
  /** DASH 音频轨地址（空表示单文件模式，音轨已在 url 内） */
  audioUrl: string = '';
  /** DASH 音频轨备用地址 */
  audioBackupUrls: string[] = [];
  /** 是否为 DASH 双流（视频/音频分离，需内核起两路播放器） */
  isDash: boolean = false;

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
