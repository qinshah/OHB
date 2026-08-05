import { Result } from '../../common/result/Result';
import { AppError } from '../../common/result/AppError';
import { BiliApi } from '../../network/BiliApi';
import { CookieManager } from '../../network/CookieManager';
import { DanmakuHost, DanmakuMessage, DanmakuTokenInfo, LiveArea, LivePlayInfo, LiveRoom } from '../../models/LiveModels';
import { VideoCard } from '../../models/VideoCard';

/** 直播原始 JSON 形状 */
interface RawArea {
  id?: number;
  parent_id?: number;
  name?: string;
}

interface RawAreaData {
  list?: RawArea[];
}

interface RawRoom {
  roomid?: number;
  room_id?: number;
  title?: string;
  uname?: string;
  uid?: number;
  face?: string;
  user_cover?: string;
  cover?: string;
  online?: number;
  area_name?: string;
  live_status?: number;
}

interface RawSecondData {
  list?: RawRoom[];
  has_more?: boolean;
}

interface RawUrlInfo {
  host?: string;
  extra?: string;
}

interface RawCodec {
  codec_name?: string;
  base_url?: string;
  url_info?: RawUrlInfo[];
}

interface RawFormat {
  format_name?: string;
  codec?: RawCodec[];
}

interface RawStream {
  protocol_name?: string;
  format?: RawFormat[];
}

interface RawPlayUrl {
  stream?: RawStream[];
}

interface RawRoomPlayData {
  live_status?: number;
  title?: string;
  uname?: string;
  uid?: number;
  face?: string;
  online?: number;
  area_name?: string;
  playurl_info?: RawPlayUrl;
}

interface RawDmHost {
  host?: string;
  port?: number;
  wss_port?: number;
}

interface RawDmTokenData {
  token?: string;
  host_list?: RawDmHost[];
}

interface RawDmMsg {
  uid?: number;
  uname?: string;
  text?: string;
  color?: number;
  timeline?: string;
}

interface RawDmPrefetchData {
  room?: RawDmMsg[];
}

/**
 * 直播仓库（P2 Task 15）：分区、直播间列表、播放信息、弹幕密钥/历史、发弹幕、屏蔽词。
 */
export class LiveRepository {
  private api: BiliApi = new BiliApi();

  /** 直播分区 */
  async getAreas(): Promise<Result<LiveArea[]>> {
    const r = await this.api.liveAreaList();
    if (!r.isOk) {
      return Result.err<LiveArea[]>(r.error);
    }
    const data = r.value as RawAreaData;
    const areas = (data.list ?? []).map((raw: RawArea) => {
      const area = new LiveArea();
      area.id = raw.id ?? 0;
      area.parentId = raw.parent_id ?? 0;
      area.name = raw.name ?? '';
      return area;
    }).filter((a: LiveArea) => a.parentId === 0 && a.id > 0);
    return Result.ok<LiveArea[]>(areas);
  }

  /** 直播列表（按分区） */
  async getRooms(page: number, areaId: number, parentAreaId: number): Promise<Result<LiveRoom[]>> {
    const r = await this.api.liveSecondList(page, areaId, parentAreaId);
    if (!r.isOk) {
      return Result.err<LiveRoom[]>(r.error);
    }
    const data = r.value as RawSecondData;
    const rooms = (data.list ?? []).map((raw: RawRoom) => {
      const room = new LiveRoom();
      room.roomId = raw.roomid ?? raw.room_id ?? 0;
      room.title = raw.title ?? '';
      room.uname = raw.uname ?? '';
      room.uid = raw.uid ?? 0;
      room.face = VideoCard.fixUrl(raw.face ?? '');
      room.cover = VideoCard.fixUrl(raw.user_cover ?? raw.cover ?? '');
      room.online = raw.online ?? 0;
      room.areaName = raw.area_name ?? '';
      room.liveStatus = raw.live_status ?? 0;
      return room;
    }).filter((room: LiveRoom) => room.roomId > 0);
    return Result.ok<LiveRoom[]>(rooms);
  }

  /** 直播间播放信息（优先取 http_flv 流） */
  async getRoomPlayInfo(roomId: number): Promise<Result<LivePlayInfo>> {
    const r = await this.api.liveRoomPlayInfo(roomId);
    if (!r.isOk) {
      return Result.err<LivePlayInfo>(r.error);
    }
    const data = r.value as RawRoomPlayData;
    const info = new LivePlayInfo();
    info.liveStatus = data.live_status ?? 0;
    info.title = data.title ?? '';
    info.uname = data.uname ?? '';
    info.uid = data.uid ?? 0;
    info.face = VideoCard.fixUrl(data.face ?? '');
    info.online = data.online ?? 0;
    info.areaName = data.area_name ?? '';
    if (info.liveStatus !== 1) {
      return Result.err<LivePlayInfo>(AppError.business(-1, '主播未开播'));
    }
    const streams = data.playurl_info?.stream ?? [];
    for (let i = 0; i < streams.length; i++) {
      const stream = streams[i];
      if (stream.protocol_name !== 'http_stream' && stream.protocol_name !== 'http_hls') {
        continue;
      }
      const formats = stream.format ?? [];
      for (let j = 0; j < formats.length; j++) {
        const codecs = formats[j].codec ?? [];
        for (let k = 0; k < codecs.length; k++) {
            const urlInfos = codecs[k].url_info ?? [];
            for (let m = 0; m < urlInfos.length; m++) {
              const ui = urlInfos[m];
              if (ui.host !== undefined && ui.host !== null && (ui.extra ?? '') !== undefined) {
              const base = codecs[k].base_url ?? '';
              if (base.length > 0) {
                info.playUrl = `${ui.host}${base}${ui.extra ?? ''}`;
                return Result.ok<LivePlayInfo>(info);
              }
            }
          }
        }
      }
    }
    return Result.err<LivePlayInfo>(AppError.parse('no live playable url'));
  }

  /** 弹幕密钥 */
  async getDanmakuToken(roomId: number): Promise<Result<DanmakuTokenInfo>> {
    const r = await this.api.liveDmToken(roomId);
    if (!r.isOk) {
      return Result.err<DanmakuTokenInfo>(r.error);
    }
    const data = r.value as RawDmTokenData;
    const info = new DanmakuTokenInfo();
    info.token = data.token ?? '';
    info.hosts = (data.host_list ?? []).map((h: RawDmHost) => {
      const host = new DanmakuHost();
      host.host = h.host ?? '';
      host.port = h.port ?? 443;
      host.wssPort = h.wss_port ?? 443;
      return host;
    });
    return Result.ok<DanmakuTokenInfo>(info);
  }

  /** 弹幕历史（进房先展示） */
  async getDanmakuHistory(roomId: number): Promise<Result<DanmakuMessage[]>> {
    const r = await this.api.liveDmPrefetch(roomId);
    if (!r.isOk) {
      return Result.err<DanmakuMessage[]>(r.error);
    }
    const data = r.value as RawDmPrefetchData;
    const msgs = (data.room ?? []).map((raw: RawDmMsg) => {
      const msg = new DanmakuMessage();
      msg.uid = raw.uid ?? 0;
      msg.uname = raw.uname ?? '';
      msg.text = raw.text ?? '';
      msg.color = raw.color ?? 16777215;
      msg.ts = Math.floor(Date.now() / 1000);
      return msg;
    }).filter((m: DanmakuMessage) => m.text.length > 0);
    return Result.ok<DanmakuMessage[]>(msgs);
  }

  /** 发送弹幕 */
  async sendDanmaku(roomId: number, text: string): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized('请先登录后发送弹幕'));
    }
    const r = await this.api.liveSendMsg(roomId, text, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 添加屏蔽词 */
  async addShieldWord(keyword: string): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.liveShieldAdd(keyword, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }

  /** 删除屏蔽词 */
  async delShieldWord(keyword: string): Promise<Result<boolean>> {
    const csrf = CookieManager.getInstance().csrf;
    if (csrf.length === 0) {
      return Result.err<boolean>(AppError.unauthorized());
    }
    const r = await this.api.liveShieldDel(keyword, csrf);
    if (!r.isOk) {
      return Result.err<boolean>(r.error);
    }
    return Result.ok<boolean>(true);
  }
}
