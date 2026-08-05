import { webSocket } from '@kit.NetworkKit';
import { DanmakuHost, DanmakuMessage } from '../../models/LiveModels';
import { Logger } from '../../common/utils/Logger';
import { util } from '@kit.ArkTS';

/** 弹幕协议常量（B站直播 WebSocket 协议） */
const PROTOCOL_VERSION: number = 1;
const OP_AUTH: number = 7;
const OP_HEARTBEAT: number = 2;
const OP_MESSAGE: number = 5;
const OP_AUTH_REPLY: number = 8;
const HEADER_LEN: number = 16;
const HEARTBEAT_INTERVAL_MS: number = 30000;

/**
 * 直播弹幕 WebSocket 客户端（P2 Task 15）
 *
 * 协议说明（参考 PiliPlus tcp/live.dart 的 API 行为，独立实现）：
 * - 建立 wss 连接后发送认证包（operation=7，body 携带 roomid/token）
 * - 每 30s 发送心跳（operation=2）
 * - 服务端消息（operation=5）为 JSON 文本（protover=1 不压缩）
 * - 二进制帧按 16 字节头解析：总长 / 头长 / 协议版本 / operation / 序号
 */
export class LiveDanmakuClient {
  private ws: webSocket.WebSocket | null = null;
  private roomId: number = 0;
  private token: string = '';
  private heartbeatTimer: number = -1;
  private connected: boolean = false;

  onMessage: (msg: DanmakuMessage) => void = () => {
  };
  onConnected: () => void = () => {
  };
  onDisconnected: () => void = () => {
  };
  onError: (message: string) => void = () => {
  };

  /** 连接直播间弹幕流 */
  connect(roomId: number, token: string, host: DanmakuHost): void {
    this.disconnect();
    this.roomId = roomId;
    this.token = token;
    if (host.host.length === 0) {
      this.onError('弹幕服务器地址为空');
      return;
    }
    const url = `wss://${host.host}:${host.wssPort}/sub`;
    this.ws = webSocket.createWebSocket();
    this.bindEvents();
    this.ws.connect(url, (err: BusinessErrorLike) => {
      if (err !== null && err !== undefined && err.code !== undefined) {
        this.onError(`弹幕连接失败（${err.code}）`);
      }
    });
  }

  private bindEvents(): void {
    if (this.ws === null) {
      return;
    }
    this.ws.on('open', () => {
      this.connected = true;
      this.sendAuth();
      this.startHeartbeat();
      this.onConnected();
    });
    this.ws.on('message', (_err: BusinessErrorLike, value: string | ArrayBuffer) => {
      this.handleIncoming(value);
    });
    this.ws.on('close', () => {
      this.connected = false;
      this.stopHeartbeat();
      this.onDisconnected();
    });
    this.ws.on('error', (err: BusinessErrorLike) => {
      this.onError(`弹幕连接错误：${JSON.stringify(err)}`);
    });
  }

  /** 认证包（protover=1 请求未压缩 JSON 弹幕） */
  private sendAuth(): void {
    const body = JSON.stringify({
      'uid': 0,
      'roomid': this.roomId,
      'protover': PROTOCOL_VERSION,
      'platform': 'web',
      'type': 2,
      'key': this.token
    });
    const packet = LiveDanmakuClient.buildPacket(body, OP_AUTH);
    this.send(packet);
  }

  private startHeartbeat(): void {
    if (this.heartbeatTimer >= 0) {
      return;
    }
    this.heartbeatTimer = setInterval(() => {
      const packet = LiveDanmakuClient.buildPacket('', OP_HEARTBEAT);
      this.send(packet);
    }, HEARTBEAT_INTERVAL_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer >= 0) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  private send(data: ArrayBuffer): void {
    if (this.ws === null || !this.connected) {
      return;
    }
    this.ws.send(data, (err: BusinessErrorLike) => {
      if (err !== null && err !== undefined && err.code !== undefined) {
        Logger.warn('LiveDm', `send fail code=${err.code}`);
      }
    });
  }

  private handleIncoming(value: string | ArrayBuffer): void {
    if (typeof value === 'string') {
      this.handleJsonBody(value);
      return;
    }
    this.handleBinary(value);
  }

  private handleBinary(buffer: ArrayBuffer): void {
    const view = new DataView(buffer);
    if (view.byteLength < HEADER_LEN) {
      return;
    }
    const totalLen = view.getUint32(0);
    const headerLen = view.getUint16(4);
    const protocolVersion = view.getUint16(6);
    const operation = view.getUint32(8);
    if (totalLen < headerLen || headerLen > view.byteLength) {
      return;
    }
    if (operation === OP_AUTH_REPLY) {
      Logger.info('LiveDm', 'auth reply ok');
      return;
    }
    if (operation === OP_MESSAGE && (protocolVersion === 0 || protocolVersion === 1)) {
      const bodyLen = totalLen - headerLen;
      if (bodyLen <= 0 || headerLen + bodyLen > view.byteLength) {
        return;
      }
      const bytes = new Uint8Array(buffer, headerLen, bodyLen);
      const decoder = new util.TextDecoder('utf-8');
      this.handleJsonBody(decoder.decodeToString(bytes));
    }
  }

  /** 解析一个/多个连续 JSON 消息 */
  private handleJsonBody(body: string): void {
    const messages: string[] = LiveDanmakuClient.splitJson(body);
    for (let i = 0; i < messages.length; i++) {
      this.handleCommand(messages[i]);
    }
  }

  private handleCommand(text: string): void {
    if (text.length === 0) {
      return;
    }
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      const cmd = obj['cmd'];
      if (typeof cmd !== 'string' || cmd !== 'DANMU_MSG') {
        return;
      }
      const infoRaw = obj['info'];
      if (infoRaw === undefined || !Array.isArray(infoRaw)) {
        return;
      }
      const info: Object[] = infoRaw;
      if (info.length < 3) {
        return;
      }
      const metaRaw = info[0];
      const textValue = info[1];
      const userRaw = info[2];
      if (typeof textValue !== 'string' || userRaw === undefined || !Array.isArray(userRaw)) {
        return;
      }
      const user: Object[] = userRaw;
      const msg = new DanmakuMessage();
      msg.text = textValue;
      if (metaRaw !== undefined && Array.isArray(metaRaw)) {
        const meta: Object[] = metaRaw;
        msg.color = LiveDanmakuClient.asNumber(meta[3], 16777215);
        msg.ts = Math.floor(Date.now() / 1000);
      }
      msg.uname = typeof user[0] === 'string' ? user[0] : '';
      msg.uid = LiveDanmakuClient.asNumber(user[1], 0);
      this.onMessage(msg);
    } catch (e) {
      Logger.warn('LiveDm', `parse cmd fail: ${JSON.stringify(e)}`);
    }
  }

  /** 连续 JSON 对象拆包（按 } 与 { 边界） */
  private static splitJson(body: string): string[] {
    const out: string[] = [];
    let depth = 0;
    let start = -1;
    let inString = false;
    for (let i = 0; i < body.length; i++) {
      const ch = body.charAt(i);
      if (ch === '"') {
        inString = !inString;
      }
      if (inString) {
        continue;
      }
      if (ch === '{') {
        if (depth === 0) {
          start = i;
        }
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0 && start >= 0) {
          out.push(body.substring(start, i + 1));
          start = -1;
        }
      }
    }
    return out;
  }

  /** 构造 B站弹幕二进制包 */
  private static buildPacket(body: string, operation: number): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const bodyBytes = encoder.encodeInto(body);
    const totalLen = HEADER_LEN + bodyBytes.byteLength;
    const buffer = new ArrayBuffer(totalLen);
    const view = new DataView(buffer);
    view.setUint32(0, totalLen);
    view.setUint16(4, HEADER_LEN);
    view.setUint16(6, PROTOCOL_VERSION);
    view.setUint32(8, operation);
    view.setUint32(12, 1);
    new Uint8Array(buffer, HEADER_LEN).set(bodyBytes);
    return buffer;
  }

  private static asNumber(value: Object | undefined, def: number): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const n = Number(value);
      return isNaN(n) ? def : n;
    }
    return def;
  }

  disconnect(): void {
    this.connected = false;
    this.stopHeartbeat();
    if (this.ws !== null) {
      try {
        this.ws.off('open');
        this.ws.off('message');
        this.ws.off('close');
        this.ws.off('error');
        this.ws.close({ code: 1000, reason: 'leave' }, () => {
        });
      } catch (e) {
        Logger.warn('LiveDm', `disconnect: ${JSON.stringify(e)}`);
      }
      this.ws = null;
    }
  }
}

interface BusinessErrorLike {
  code?: number;
  message?: string;
}
