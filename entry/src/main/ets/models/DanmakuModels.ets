/**
 * 弹幕数据模型（B 站 protobuf DanmakuElem 的业务子集）
 *
 * 参考 PiliPlus（Flutter）的 DanmakuElem 使用方式，仅保留渲染所需字段：
 * - id：弹幕 id（int64，double 承载存在 > 2^53 的精度损失，仅用于展示，可接受）
 * - progress：出现时间（毫秒，相对视频起点），按 0.1s 分桶存储
 * - mode：1/2/3/6 滚动、4 底部固定、5 顶部固定、7 高级（本版忽略不渲染）
 * - fontsize：B 站字号 18（小）/ 25（标准）/ 36（大）
 * - color：十进制 RGB（如 16777215 = 0xFFFFFF 白色）
 */
export class DanmakuItem {
  /** 弹幕 id */
  id: number = 0;
  /** 出现时间（毫秒） */
  progress: number = 0;
  /** 弹幕类型（见类注释） */
  mode: number = 1;
  /** B 站字号 */
  fontsize: number = 25;
  /** 十进制 RGB 颜色 */
  color: number = 0xFFFFFF;
  /** 发送者哈希（本版仅解析不使用） */
  midHash: string = '';
  /** 弹幕内容 */
  content: string = '';
  /** 权重（屏蔽等级过滤：weight < 设置值则不显示） */
  weight: number = 0;
  /** 弹幕池：0 普通池 */
  pool: number = 0;
  /** 合并后的重复条数（>1 时渲染 "×N"） */
  count: number = 1;
}
