// [API 23+] B 站分段弹幕 protobuf 解析器
import { util } from '@kit.ArkTS';
import { DanmakuItem } from '../models/DanmakuModels';

/**
 * 手写最小 protobuf 解析器（无需引入第三方 protobuf 库）
 *
 * 仅覆盖 seg.so 接口返回的 DmSegMobileReply / DanmakuElem 所需字段：
 * - DmSegMobileReply { repeated DanmakuElem elems = 1; }
 * - DanmakuElem：1 id(int64)、2 progress(int32)、3 mode、4 fontsize、
 *   5 color(uint32)、6 mid_hash(string)、7 content(string)、
 *   9 weight(int32)、11 pool
 *
 * 实现要点：
 * - varint 解码（含 10 字节负数补码：weight 等 int32 字段可能为负）
 * - wire type：0 varint / 2 length-delimited，其余按规则跳过
 * - 未知字段一律 skip，保证向前兼容
 */

/** protobuf wire type 常量 */
const WIRE_VARINT: number = 0;
const WIRE_64BIT: number = 1;
const WIRE_LEN: number = 2;
const WIRE_32BIT: number = 5;

/** 2^32（int32 符号扩展用） */
const TWO_POW_32: number = 4294967296;

/** 最小 protobuf 读取器（Uint8Array + 游标） */
class PbReader {
  private buf: Uint8Array;
  private pos: number = 0;
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  constructor(buf: Uint8Array) {
    this.buf = buf;
  }

  /** 是否还有数据可读 */
  hasNext(): boolean {
    return this.pos < this.buf.length;
  }

  /**
   * 读取 varint：
   * - 常规值（≤ 9 字节）直接累加返回（> 2^53 时有精度损失，仅 id 字段，可接受）
   * - 10 字节 varint = 64 位补码负值（protobuf int32/int64 负数字段），
   *   此时取低 32 位按符号位扩展，避免 double 精度损失
   */
  readVarint(): number {
    let result: number = 0;
    let low32: number = 0;
    let count: number = 0;
    while (this.pos < this.buf.length && count < 10) {
      const b: number = this.buf[this.pos];
      this.pos++;
      count++;
      const val: number = b & 0x7F;
      result += val * Math.pow(2, (count - 1) * 7);
      // 同步累加低 32 位（字节 1-4 共 28 位 + 字节 5 低 4 位）
      if (count < 5) {
        low32 += val * Math.pow(2, (count - 1) * 7);
      } else if (count === 5) {
        low32 += (val & 0x0F) * Math.pow(2, 28);
      }
      if ((b & 0x80) === 0) {
        return result;
      }
    }
    // 10 字节：负数补码，按 int32 符号扩展还原
    if (count === 10 && low32 >= 2147483648) {
      return low32 - TWO_POW_32;
    }
    return low32;
  }

  /** 读取 length-delimited 字段的长度 */
  readLength(): number {
    return this.readVarint();
  }

  /** 取指定长度字节生成子 reader（用于嵌套消息） */
  subReader(length: number): PbReader {
    const end: number = Math.min(this.pos + length, this.buf.length);
    const sub: Uint8Array = this.buf.subarray(this.pos, end);
    this.pos = end;
    return new PbReader(sub);
  }

  /** 取指定长度字节并按 utf-8 解码为字符串 */
  readString(length: number): string {
    const end: number = Math.min(this.pos + length, this.buf.length);
    const sub: Uint8Array = this.buf.subarray(this.pos, end);
    this.pos = end;
    return this.decoder.decodeToString(sub);
  }

  /** 跳过未知字段（按 wire type 决定长度） */
  skipField(wireType: number): void {
    if (wireType === WIRE_VARINT) {
      this.readVarint();
    } else if (wireType === WIRE_64BIT) {
      this.pos += 8;
    } else if (wireType === WIRE_LEN) {
      const len: number = this.readVarint();
      this.pos += len;
    } else if (wireType === WIRE_32BIT) {
      this.pos += 4;
    } else {
      // 未知 wire type（3/4 分组早已废弃）：无法确定长度，终止解析
      this.pos = this.buf.length;
    }
  }
}

/** 解析单条 DanmakuElem（未知字段跳过） */
function parseElem(r: PbReader): DanmakuItem | null {
  const item: DanmakuItem = new DanmakuItem();
  let hasContent: boolean = false;
  while (r.hasNext()) {
    const tag: number = r.readVarint();
    const field: number = tag >>> 3;
    const wt: number = tag & 7;
    if (field === 1 && wt === WIRE_VARINT) {
      item.id = r.readVarint();
    } else if (field === 2 && wt === WIRE_VARINT) {
      item.progress = r.readVarint();
    } else if (field === 3 && wt === WIRE_VARINT) {
      item.mode = r.readVarint();
    } else if (field === 4 && wt === WIRE_VARINT) {
      item.fontsize = r.readVarint();
    } else if (field === 5 && wt === WIRE_VARINT) {
      item.color = r.readVarint();
    } else if (field === 6 && wt === WIRE_LEN) {
      item.midHash = r.readString(r.readLength());
    } else if (field === 7 && wt === WIRE_LEN) {
      item.content = r.readString(r.readLength());
      hasContent = item.content.length > 0;
    } else if (field === 9 && wt === WIRE_VARINT) {
      item.weight = r.readVarint();
    } else if (field === 11 && wt === WIRE_VARINT) {
      item.pool = r.readVarint();
    } else {
      r.skipField(wt);
    }
  }
  if (!hasContent) {
    return null;
  }
  return item;
}

/**
 * 解析 seg.so 返回的 DmSegMobileReply 二进制
 * @return 弹幕列表（解析失败返回空数组，调用方静默降级）
 */
export function parseDmSegReply(buf: ArrayBuffer): DanmakuItem[] {
  const items: DanmakuItem[] = [];
  try {
    const reader: PbReader = new PbReader(new Uint8Array(buf));
    while (reader.hasNext()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wt: number = tag & 7;
      if (field === 1 && wt === WIRE_LEN) {
        const len: number = reader.readLength();
        const elemReader: PbReader = reader.subReader(len);
        const item: DanmakuItem | null = parseElem(elemReader);
        if (item !== null) {
          items.push(item);
        }
      } else {
        reader.skipField(wt);
      }
    }
  } catch (e) {
    // 二进制损坏：返回已解析部分（弹幕功能静默降级，不影响播放）
  }
  return items;
}
