/** 直播模型（P2 Task 15） */

/** 直播分区 */
export class LiveArea {
  id: number = 0;
  parentId: number = 0;
  name: string = '';
}

/** 直播间卡片（列表项） */
@Observed
export class LiveRoom {
  roomId: number = 0;
  title: string = '';
  uname: string = '';
  uid: number = 0;
  face: string = '';
  cover: string = '';
  online: number = 0;
  areaName: string = '';
  /** 直播状态（1 直播中） */
  liveStatus: number = 0;
}

/** 直播间播放信息 */
export class LivePlayInfo {
  /** 播放地址 */
  playUrl: string = '';
  /** 直播状态（1 直播中） */
  liveStatus: number = 0;
  /** 房间标题 */
  title: string = '';
  /** 主播名 */
  uname: string = '';
  uid: number = 0;
  face: string = '';
  online: number = 0;
  /** 分区名 */
  areaName: string = '';
}

/** 弹幕 WebSocket host */
export class DanmakuHost {
  host: string = '';
  port: number = 443;
  wssPort: number = 443;
}

/** 弹幕密钥信息 */
export class DanmakuTokenInfo {
  token: string = '';
  hosts: DanmakuHost[] = [];
}

/** 弹幕消息 */
export class DanmakuMessage {
  uid: number = 0;
  uname: string = '';
  text: string = '';
  color: number = 16777215;
  /** 时间戳（秒） */
  ts: number = 0;
}
