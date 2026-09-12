import { PlayUrlInfo, QualityOption } from '../../models/PlayUrlInfo';
import { QualityUtil } from '../../models/Quality';
import { VideoCard } from '../../models/VideoCard';

/**
 * 取流解析（UGC 与番剧共用）
 *
 * 统一处理 B 站 playurl 的两种响应形态：
 * - `fnval=1`（MP4 单文件）：data.durl / result.video_info.durl，含音轨，AvPlayer 直接可播，
 *   但 B 站已下线 720P 以上档位（实测 accept_quality 只有 [64,16]）
 * - `fnval=4048`（DASH）：data.dash / result.video_info.dash，视频/音频轨分离，
 *   携带大会员 Cookie 时才会给出 1080P/1080P60/4K/HDR/8K 等完整档位
 *
 * 画质档位一律用 Quality 枚举/QualityUtil 表达，禁止在此写 qn 魔数。
 */

// ---------- 原始 JSON 形状 ----------

export interface RawSupportFormat {
  quality?: number;
  /** 完整描述（web 接口新字段） */
  new_description?: string;
  /** 完整描述（旧字段） */
  new_desc?: string;
  /** 短文案 */
  display_desc?: string;
  /** 角标（如「高码率」「大会员」） */
  superscript?: string;
}

export interface RawDurl {
  url?: string;
  backup_url?: string[];
  length?: number;
  size?: number;
  order?: number;
}

export interface RawDashStream {
  id?: number;
  base_url?: string;
  baseUrl?: string;
  backup_url?: string[];
  backupUrl?: string[];
  codecid?: number;
  codecs?: string;
  bandwidth?: number;
  width?: number;
  height?: number;
  frame_rate?: string;
  frameRate?: string;
}

export interface RawDash {
  video?: RawDashStream[];
  audio?: RawDashStream[];
  /** 杜比全景声 */
  dolby?: RawDashAudioWrap;
  /** 无损音频 */
  flac?: RawDashAudioWrap;
}

export interface RawDashAudioWrap {
  audio?: RawDashStream[] | null;
}

/** playurl 响应（UGC 平铺；番剧 v2 在 video_info 下，调用方负责取出） */
export interface RawPlayData {
  quality?: number;
  timelength?: number;
  durl?: RawDurl[];
  durls?: RawDurl[];
  accept_quality?: number[];
  accept_description?: string[];
  support_formats?: RawSupportFormat[];
  dash?: RawDash;
}

/** 选中的 DASH 流地址 */
export class DashStreamUrl {
  url: string = '';
  backupUrls: string[] = [];

  static of(stream: RawDashStream): DashStreamUrl {
    const s = new DashStreamUrl();
    const primary = stream.base_url ?? stream.baseUrl ?? '';
    s.url = VideoCard.fixUrl(primary);
    const backups = stream.backup_url ?? stream.backupUrl ?? [];
    s.backupUrls = backups.map((u: string) => VideoCard.fixUrl(u));
    return s;
  }
}

export class PlayUrlParser {
  /** 视频编码：H.264（兼容性最好，模拟器/低端设备硬件解码稳） */
  private static readonly CODEC_AVC: number = 7;
  /** 杜比音频 id（30250）/ 无损音频 id（30251），非通用，仅作优先级参考 */
  private static readonly AUDIO_HI_RES: number = 30250;
  /** 常规最高音质 id（192K） */
  private static readonly AUDIO_BEST: number = 30280;

  /**
   * 组装可用画质列表（画质切换入口数据源，高 → 低）。
   * 以 accept_quality 为准（账号真实可见范围），描述取自 support_formats，
   * 兜底链：new_description → new_desc → display_desc → 本地枚举文案。
   *
   * @param dashCodes `dash.video` 实际存在的 qn 列表（见 dashVideoCodes）。
   *   传入时会剔除「声明可用但取不到流」的 DASH 专属档位——实测未登录时
   *   accept_quality 仍列出 112/80，而 dash.video 只有 32/16，若不剔除，
   *   画质列表会给出点不到的选项（选中即被降级）。
   */
  static parseQualityOptions(d: RawPlayData, dashCodes: number[] = []): QualityOption[] {
    const qns: number[] = d.accept_quality ?? [];
    if (qns.length === 0) {
      return [];
    }
    const formats: RawSupportFormat[] = d.support_formats ?? [];
    const list: QualityOption[] = [];
    for (let i = 0; i < qns.length; i++) {
      const q = qns[i];
      // >720P 只能走 DASH：dash 流里没有该 id 说明当前账号/通道取不到
      if (dashCodes.length > 0 && QualityUtil.needsDash(q) && dashCodes.indexOf(q) < 0) {
        continue;
      }
      const o = new QualityOption();
      o.qn = q;
      let matched: RawSupportFormat | null = null;
      for (let j = 0; j < formats.length; j++) {
        if (formats[j].quality === q) {
          matched = formats[j];
          break;
        }
      }
      if (matched !== null) {
        o.desc = matched.new_description ?? matched.new_desc ?? '';
        o.shortDesc = matched.display_desc ?? '';
        o.superscript = matched.superscript ?? '';
      }
      // desc 兜底链：接口描述 → 短文案 → 本地枚举文案
      if (o.desc.length === 0) {
        o.desc = o.shortDesc.length > 0 ? o.shortDesc : QualityUtil.shortDesc(q);
      }
      if (o.shortDesc.length === 0) {
        o.shortDesc = QualityUtil.shortDesc(q);
      }
      o.vip = QualityUtil.needsVip(q);
      o.dashOnly = QualityUtil.needsDash(q);
      list.push(o);
    }
    return list;
  }

  /** 取 accept_quality 原始 qn 列表（用于目标画质选择） */
  static acceptCodes(d: RawPlayData): number[] {
    return d.accept_quality ?? [];
  }

  /**
   * 取 `dash.video` 实际存在的 qn 列表（去重，高 → 低）。
   * 这是「当前账号/通道真的能取到哪些档位」的唯一可靠依据：
   * accept_quality 只表示视频自身拥有哪些档位（未登录也会列出 112/80）。
   */
  static dashVideoCodes(d: RawPlayData): number[] {
    const videos: RawDashStream[] = d.dash?.video ?? [];
    const codes: number[] = [];
    for (let i = 0; i < videos.length; i++) {
      const id: number = videos[i].id ?? 0;
      if (id > 0 && codes.indexOf(id) < 0) {
        codes.push(id);
      }
    }
    codes.sort((a: number, b: number) => b - a);
    return codes;
  }

  /**
   * 把「期望画质」折算为「实际可播画质」。
   *
   * 两次折算的原因：accept_quality 会虚报（实测未登录时仍列出 112/80，但 dash.video
   * 只有 32/16），若只按它选档，会出现「请求 1080P → 响应里没有对应流 → 被降级到 720P」，
   * 这正是「切换高画质总被回退」的直接原因。故对只能走 DASH 的高画质，再用
   * dash.video 的真实 id 折算一次，取「真正取得到」的最高档。
   */
  static resolveTarget(d: RawPlayData, preferredQn: number): number {
    const target: number = QualityUtil.findAvailable(PlayUrlParser.acceptCodes(d), preferredQn);
    if (!QualityUtil.needsDash(target)) {
      return target;
    }
    const dashCodes: number[] = PlayUrlParser.dashVideoCodes(d);
    if (dashCodes.length === 0) {
      return target;
    }
    return QualityUtil.findAvailable(dashCodes, target);
  }

  /** 单文件（durl）首个可用地址 */
  static pickDurl(d: RawPlayData): RawDurl | null {
    const list: RawDurl[] = d.durl ?? d.durls ?? [];
    for (let i = 0; i < list.length; i++) {
      const u = list[i].url;
      if (u !== undefined && u.length > 0) {
        return list[i];
      }
    }
    return null;
  }

  /**
   * 取指定画质的 DASH 视频轨：
   * 优先 H.264（codecid=7，设备解码兼容性最好），否则回退该档位首个可用流。
   */
  static pickVideoStream(dash: RawDash | undefined, qn: number): DashStreamUrl | null {
    if (dash === undefined || dash === null) {
      return null;
    }
    const videos: RawDashStream[] = dash.video ?? [];
    let fallback: RawDashStream | null = null;
    for (let i = 0; i < videos.length; i++) {
      const v = videos[i];
      if (v.id !== qn) {
        continue;
      }
      if (v.codecid === PlayUrlParser.CODEC_AVC) {
        return DashStreamUrl.of(v);
      }
      if (fallback === null) {
        fallback = v;
      }
    }
    return fallback !== null ? DashStreamUrl.of(fallback) : null;
  }

  /**
   * 取 DASH 音频轨：优先 192K(30280) → 无损/杜比 → 带宽最高者。
   * B 站音频轨与画质档位无关，全账号通用。
   */
  static pickAudioStream(dash: RawDash | undefined): DashStreamUrl | null {
    if (dash === undefined || dash === null) {
      return null;
    }
    const audios: RawDashStream[] = dash.audio ?? [];
    if (audios.length === 0) {
      const dolby: RawDashStream[] = dash.dolby?.audio ?? [];
      if (dolby.length > 0) {
        return DashStreamUrl.of(dolby[0]);
      }
      const flac: RawDashStream[] = dash.flac?.audio ?? [];
      if (flac.length > 0) {
        return DashStreamUrl.of(flac[0]);
      }
      return null;
    }
    let best: RawDashStream = audios[0];
    let bestScore = -1;
    for (let i = 0; i < audios.length; i++) {
      const a = audios[i];
      let score = a.bandwidth ?? 0;
      if (a.id === PlayUrlParser.AUDIO_BEST) {
        score += 100000000;
      } else if (a.id === PlayUrlParser.AUDIO_HI_RES) {
        score += 1000000;
      }
      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }
    return DashStreamUrl.of(best);
  }

  /** 用单文件 durl 填充 PlayUrlInfo */
  static fillSingleFile(info: PlayUrlInfo, d: RawPlayData, requestedQn: number): boolean {
    const durl = PlayUrlParser.pickDurl(d);
    if (durl === null) {
      return false;
    }
    info.url = VideoCard.fixUrl(durl.url ?? '');
    info.backupUrls = (durl.backup_url ?? []).map((u: string) => VideoCard.fixUrl(u));
    // 实际画质以接口返回为准（请求被服务端降级时以此为准，避免 UI 显示与实际不符）
    info.quality = d.quality !== undefined && d.quality > 0 ? d.quality : requestedQn;
    info.qualityDesc = QualityUtil.shortDesc(info.quality);
    info.timelength = d.timelength !== undefined && d.timelength > 0
      ? d.timelength : (durl.length ?? 0);
    info.isDash = false;
    return true;
  }

  /** 用 DASH 双流填充 PlayUrlInfo（视频轨 + 音频轨） */
  static fillDash(info: PlayUrlInfo, d: RawPlayData, targetQn: number): boolean {
    const video = PlayUrlParser.pickVideoStream(d.dash, targetQn);
    if (video === null) {
      return false;
    }
    const audio = PlayUrlParser.pickAudioStream(d.dash);
    info.url = video.url;
    info.backupUrls = video.backupUrls;
    info.audioUrl = audio !== null ? audio.url : '';
    info.audioBackupUrls = audio !== null ? audio.backupUrls : [];
    info.quality = targetQn;
    info.qualityDesc = QualityUtil.shortDesc(targetQn);
    info.timelength = d.timelength ?? 0;
    info.isDash = info.audioUrl.length > 0;
    return true;
  }
}
