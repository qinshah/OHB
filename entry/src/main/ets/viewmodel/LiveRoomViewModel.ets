import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import { DanmakuMessage, LivePlayInfo } from '../models/LiveModels';
import { LiveRepository } from '../data/repository/LiveRepository';
import { LiveDanmakuClient } from '../services/live/LiveDanmakuClient';
import { Logger } from '../common/utils/Logger';

/**
 * 直播间 ViewModel（P2 Task 15）：播放信息 + 弹幕收发 + 屏蔽词。
 */
@Observed
export class LiveRoomViewModel {
  playState: DataState<LivePlayInfo> = DataState.idle<LivePlayInfo>();
  playInfo: LivePlayInfo | null = null;
  /** 弹幕消息（最新在后） */
  danmaku: DanmakuMessage[] = [];
  isSending: boolean = false;
  sendTip: string = '';
  /** 屏蔽词（本地持久化之外的会话内列表） */
  shieldWords: string[] = [];
  /** 弹幕开关 */
  danmakuEnabled: boolean = true;

  private repo: LiveRepository = new LiveRepository();
  private client: LiveDanmakuClient = new LiveDanmakuClient();
  private roomId: number = 0;

  init(roomId: number): void {
    this.roomId = roomId;
    this.client.onMessage = (msg: DanmakuMessage) => {
      if (!this.danmakuEnabled || this.isBlocked(msg)) {
        return;
      }
      if (this.danmaku.length > 200) {
        this.danmaku.shift();
      }
      this.danmaku.push(msg);
    };
    this.client.onDisconnected = () => {
      Logger.info('LiveRoom', 'danmaku disconnected');
    };
  }

  async load(): Promise<void> {
    this.playState = DataState.loading<LivePlayInfo>();
    const r = await this.repo.getRoomPlayInfo(this.roomId);
    if (!r.isOk) {
      this.playState = DataState.error<LivePlayInfo>(r.error);
      return;
    }
    this.playInfo = r.value;
    this.playState = DataState.data<LivePlayInfo>(this.playInfo);
    this.startDanmaku();
    await this.loadHistoryDanmaku();
  }

  private async startDanmaku(): Promise<void> {
    const tokenR = await this.repo.getDanmakuToken(this.roomId);
    if (!tokenR.isOk) {
      return;
    }
    const token = tokenR.value;
    if (token.hosts.length === 0) {
      return;
    }
    this.client.connect(this.roomId, token.token, token.hosts[0]);
  }

  private async loadHistoryDanmaku(): Promise<void> {
    const r = await this.repo.getDanmakuHistory(this.roomId);
    if (r.isOk) {
      this.danmaku = r.value.slice(-50);
    }
  }

  async send(text: string): Promise<boolean> {
    if (text.trim().length === 0 || this.isSending) {
      return false;
    }
    this.isSending = true;
    this.sendTip = '';
    const r = await this.repo.sendDanmaku(this.roomId, text.trim());
    this.isSending = false;
    if (!r.isOk) {
      this.sendTip = r.error.message;
      return false;
    }
    const mine = new DanmakuMessage();
    mine.uname = '我';
    mine.text = text.trim();
    mine.ts = Math.floor(Date.now() / 1000);
    this.danmaku.push(mine);
    return true;
  }

  async addShieldWord(keyword: string): Promise<boolean> {
    if (keyword.trim().length === 0) {
      return false;
    }
    const r = await this.repo.addShieldWord(keyword.trim());
    if (r.isOk) {
      this.shieldWords.push(keyword.trim());
      return true;
    }
    this.sendTip = r.error.message;
    return false;
  }

  async removeShieldWord(keyword: string): Promise<void> {
    await this.repo.delShieldWord(keyword);
    const idx = this.shieldWords.indexOf(keyword);
    if (idx >= 0) {
      this.shieldWords.splice(idx, 1);
    }
  }

  private isBlocked(msg: DanmakuMessage): boolean {
    for (let i = 0; i < this.shieldWords.length; i++) {
      if (msg.text.indexOf(this.shieldWords[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  get errorMessage(): string {
    return this.playState.error?.message ?? AppError.unknown('').message;
  }

  release(): void {
    this.client.disconnect();
  }
}
