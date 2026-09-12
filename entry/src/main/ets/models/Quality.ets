/**
 * 画质清晰度统一枚举（全应用唯一来源）
 *
 * 约定（对齐 PiliPlus `lib/models/common/video/video_quality.dart`）：
 * - 枚举值即 B 站清晰度代码 qn，所有取流/展示/偏好持久化一律使用本枚举，禁止再写魔数
 * - 元数据（文案/是否大会员/是否仅 DASH）集中在 QualityMeta 表，设置中心与播放器画质列表共用
 *
 * ⚠️ 重要事实（curl 实测 2026-09）：
 * B 站已下线 720P 以上的「单文件 MP4（durl）」通道——`fnval=1` 即使携带大会员 Cookie，
 * 也只返回 accept_quality=[64,16]（720P/360P）；1080P 及以上只有 `fnval=4048` 的
 * DASH 响应（dash.video 视频流 + dash.audio 音频流分开）才提供。
 * 因此 >720P 的画质必须走「DASH 双流」播放（视频轨 + 音频轨），见 Player/AvPlayerEngine。
 */

/** 画质清晰度（值 = B 站 qn 代码） */
export enum Quality {
  /** 240P 极速 */
  Speed240 = 6,
  /** 360P 流畅 */
  Fluent360 = 16,
  /** 480P 标清 */
  Clear480 = 32,
  /** 720P 准高清 */
  High720 = 64,
  /** 720P 60帧（大会员） */
  High720_60 = 74,
  /** 1080P 高清 */
  High1080 = 80,
  /** 1080P 高码率（大会员） */
  High1080Plus = 112,
  /** 1080P 60帧（大会员） */
  High1080_60 = 116,
  /** 4K 超高清（大会员） */
  Super4K = 120,
  /** HDR 真彩（大会员） */
  Hdr = 125,
  /** 杜比视界（大会员） */
  DolbyVision = 126,
  /** 8K 超高清（大会员） */
  Super8K = 127,
  /** HDR Vivid（大会员） */
  HdrVivid = 129
}

/** 画质元数据（文案走资源，中英文同步） */
export class QualityMeta {
  /** B 站清晰度代码 */
  readonly code: number;
  /** 完整描述（列表项显示，如「1080P 高清」） */
  readonly desc: ResourceStr;
  /** 短文案（控制栏按钮显示，如「1080P」） */
  readonly shortDesc: string;
  /** 是否仅大会员可用 */
  readonly vip: boolean;
  /** 是否仅 DASH 双流可用（单文件 MP4 通道已不提供） */
  readonly dashOnly: boolean;

  constructor(code: number, desc: ResourceStr, shortDesc: string, vip: boolean, dashOnly: boolean) {
    this.code = code;
    this.desc = desc;
    this.shortDesc = shortDesc;
    this.vip = vip;
    this.dashOnly = dashOnly;
  }
}

/** 画质工具：枚举查询、可用档位选择、fnval 常量 */
export class QualityUtil {
  /** 单文件（MP4/durl）通道支持的最高画质；B 站已下线更高画质的 MP4 */
  static readonly MAX_SINGLE_FILE: number = Quality.High720;
  /** fnval：MP4 单文件（AvPlayer 直接可播，含音轨） */
  static readonly FNVAL_MP4: number = 1;
  /** fnval：DASH|HDR|4K|杜比音频|杜比视界|8K（对齐 PiliPlus 的 4048） */
  static readonly FNVAL_DASH: number = 4048;
  /** 请求画质列表时的探针档位：取最高档可让服务端返回账号真实可用的全部档位（PiliPlus 同款做法） */
  static readonly PROBE_QUALITY: number = Quality.HdrVivid;

  /** 全部画质（高 → 低） */
  static readonly all: QualityMeta[] = [
    new QualityMeta(Quality.HdrVivid, $r('app.string.quality_hdr_vivid'), 'HDR Vivid', true, true),
    new QualityMeta(Quality.Super8K, $r('app.string.quality_8k'), '8K', true, true),
    new QualityMeta(Quality.DolbyVision, $r('app.string.quality_dolby_vision'), '杜比', true, true),
    new QualityMeta(Quality.Hdr, $r('app.string.quality_hdr'), 'HDR', true, true),
    new QualityMeta(Quality.Super4K, $r('app.string.quality_4k'), '4K', true, true),
    new QualityMeta(Quality.High1080_60, $r('app.string.quality_1080p60'), '1080P60', true, true),
    new QualityMeta(Quality.High1080Plus, $r('app.string.quality_1080p_plus'), '1080P+', true, true),
    new QualityMeta(Quality.High1080, $r('app.string.quality_1080p'), '1080P', false, true),
    new QualityMeta(Quality.High720_60, $r('app.string.quality_720p60'), '720P60', true, true),
    new QualityMeta(Quality.High720, $r('app.string.quality_720p'), '720P', false, false),
    new QualityMeta(Quality.Clear480, $r('app.string.quality_480p'), '480P', false, false),
    new QualityMeta(Quality.Fluent360, $r('app.string.quality_360p'), '360P', false, false),
    new QualityMeta(Quality.Speed240, $r('app.string.quality_240p'), '240P', false, false)
  ];

  /** 按 qn 取元数据（未收录返回 null） */
  static info(code: number): QualityMeta | null {
    for (let i = 0; i < QualityUtil.all.length; i++) {
      if (QualityUtil.all[i].code === code) {
        return QualityUtil.all[i];
      }
    }
    return null;
  }

  /** 短文案（列表/按钮显示；未收录时兜底为 `${qn}P`，与原 qualityName 行为一致） */
  static shortDesc(code: number): string {
    const meta = QualityUtil.info(code);
    if (meta !== null) {
      return meta.shortDesc;
    }
    if (code === 0) {
      return '';
    }
    if (code === 128) {
      // 128 = 1080P 杜比（历史档位，未进枚举，单独兜底）
      return '1080P';
    }
    return `${code}P`;
  }

  /** 完整描述（优先本地资源；资源缺失时回退短文案） */
  static desc(code: number): ResourceStr {
    const meta = QualityUtil.info(code);
    return meta !== null ? meta.desc : QualityUtil.shortDesc(code);
  }

  /** 该画质是否需要大会员 */
  static needsVip(code: number): boolean {
    const meta = QualityUtil.info(code);
    return meta !== null && meta.vip;
  }

  /** 该画质是否只能走 DASH 双流（单文件 MP4 通道不提供） */
  static needsDash(code: number): boolean {
    return code > QualityUtil.MAX_SINGLE_FILE;
  }

  /**
   * 从可用档位中选择目标画质（对齐 PiliPlus `PlayUrlModel.findAvailableVideoQuality`）：
   * - 期望档位 ≤ 当前可用最高档 → 取「不超过期望值」的最大可用档位（就近向下取整）
   * - 期望档位 > 当前可用最高档 → 取当前可用最高档（不做不可达的请求）
   * @param availableCodes 服务端返回的可用 qn 列表（accept_quality）
   * @param preferred 期望画质 qn（来自设置中心/用户选择）
   * @returns 实际可用画质 qn；列表为空时原样返回 preferred
   */
  static findAvailable(availableCodes: number[], preferred: number): number {
    if (availableCodes.length === 0) {
      return preferred;
    }
    let highest = availableCodes[0];
    let best = -1;
    for (let i = 0; i < availableCodes.length; i++) {
      const q = availableCodes[i];
      if (q > highest) {
        highest = q;
      }
      // 不超过期望值的最大可用档位（就近向下）
      if (q <= preferred && q > best) {
        best = q;
      }
    }
    if (preferred <= highest) {
      return best > 0 ? best : highest;
    }
    return highest;
  }
}
