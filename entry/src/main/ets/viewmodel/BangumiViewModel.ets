import { DataState } from '../common/state/DataState';
import { AppError } from '../common/result/AppError';
import {
  BangumiConditionGroup,
  BangumiConditionValue,
  BangumiIndexCondition,
  BangumiItem,
  BangumiOrderItem,
  BangumiSelection
} from '../models/BangumiModels';
import { BangumiRepository } from '../data/repository/BangumiRepository';

/** 排序分组在筛选行中的合成 field（真实查询参数名为 order） */
export const BANGUMI_ORDER_KEY: string = '__order__';
/** 超过该行数时折叠并显示「更多筛选」（对齐 PiliPlus：count > 5 时折半展示） */
const COLLAPSE_THRESHOLD: number = 5;

/**
 * 索引筛选行：把「排序项」与各「筛选分组」统一成同一行模型，
 * 左侧为当前选中项胶囊，右侧为该行全部候选项。
 */
export class BangumiFilterRow {
  /** 查询参数字段名；排序行为 BANGUMI_ORDER_KEY */
  field: string = '';
  /** 左侧胶囊文案（当前选中项显示名） */
  pill: string = '';
  /** 当前选中值 */
  current: string = '';
  /** ForEach 键：field + 选中值，保证选中变化时该行内容重建 */
  key: string = '';
  values: BangumiConditionValue[] = [];
}

/**
 * 番剧索引/排行 ViewModel（P2 Task 20）。
 *
 * 索引部分对齐 PiliPlus PgcIndexController：
 * - 先取筛选条件，默认选中排序首项与各筛选分组首项，再拉取列表
 * - 查询参数 = season_type / type + order + 各筛选分组当前值
 * - 分页依据接口 has_next
 */
@Observed
export class BangumiViewModel {
  // ---------------- 排行榜（保留） ----------------
  rankState: DataState<BangumiItem[]> = DataState.idle<BangumiItem[]>();
  rankItems: BangumiItem[] = [];

  // ---------------- 索引 ----------------
  conditionState: DataState<BangumiIndexCondition> = DataState.idle<BangumiIndexCondition>();
  /** 索引筛选行（排序 + 各筛选分组） */
  rows: BangumiFilterRow[] = [];
  /** 是否展开全部筛选行 */
  expanded: boolean = false;

  indexState: DataState<BangumiItem[]> = DataState.idle<BangumiItem[]>();
  indexItems: BangumiItem[] = [];
  isLoadingMore: boolean = false;
  hasMore: boolean = true;

  private repo: BangumiRepository = new BangumiRepository();
  private orders: BangumiOrderItem[] = [];
  private groups: BangumiConditionGroup[] = [];
  private selections: BangumiSelection[] = [];
  private page: number = 1;
  private seasonType: number = 1;
  private indexType: number = 0;
  private conditionLoaded: boolean = false;

  // ==================== 排行榜 ====================

  async loadRank(seasonType: number = 1, day: number = 3): Promise<void> {
    this.rankState = DataState.loading<BangumiItem[]>();
    const r = await this.repo.getRank(seasonType, day);
    if (r.isOk) {
      this.rankItems = r.value;
      this.rankState = this.rankItems.length > 0
        ? DataState.data<BangumiItem[]>(this.rankItems)
        : DataState.empty<BangumiItem[]>();
    } else {
      this.rankState = DataState.error<BangumiItem[]>(r.error);
    }
  }

  // ==================== 索引 ====================

  /** 加载索引条件并完成首屏列表（幂等：重复进入不重复请求条件） */
  async loadCondition(): Promise<void> {
    if (this.conditionLoaded) {
      if (this.indexItems.length === 0) {
        await this.loadIndexFirst();
      }
      return;
    }
    this.conditionLoaded = true;
    this.conditionState = DataState.loading<BangumiIndexCondition>();
    const r = await this.repo.getIndexCondition(this.seasonType);
    if (!r.isOk) {
      this.conditionLoaded = false;
      this.conditionState = DataState.error<BangumiIndexCondition>(r.error);
      this.indexState = DataState.error<BangumiItem[]>(r.error);
      return;
    }
    const cond = r.value;
    this.orders = cond.orders;
    this.groups = cond.filters;

    // 默认选中：排序首项 + 各筛选分组首项（对齐 PiliPlus getPgcIndexCondition）
    const sel: BangumiSelection[] = [];
    if (this.orders.length > 0) {
      const o = this.orders[0];
      sel.push(BangumiViewModel.mkSelection(BANGUMI_ORDER_KEY, o.field, o.name));
    }
    for (let i = 0; i < this.groups.length; i++) {
      const g = this.groups[i];
      if (g.values.length > 0) {
        const v = g.values[0];
        sel.push(BangumiViewModel.mkSelection(g.field, v.keyword, v.name));
      }
    }
    this.selections = sel;
    this.conditionState = DataState.data<BangumiIndexCondition>(cond);
    this.rebuildRows();
    await this.loadIndexFirst();
  }

  /** 重试：条件与列表一并重载 */
  async retry(): Promise<void> {
    if (this.rows.length === 0) {
      this.conditionLoaded = false;
      await this.loadCondition();
      return;
    }
    await this.loadIndexFirst();
  }

  /** 切换某个筛选行的选中项并重新拉取列表 */
  async selectValue(field: string, keyword: string, label: string): Promise<void> {
    if (this.isSelected(field, keyword)) {
      return;
    }
    const next: BangumiSelection[] = [];
    for (let i = 0; i < this.selections.length; i++) {
      next.push(this.selections[i]);
    }
    let found = false;
    for (let i = 0; i < next.length; i++) {
      if (next[i].field === field) {
        next[i] = BangumiViewModel.mkSelection(field, keyword, label);
        found = true;
        break;
      }
    }
    if (!found) {
      next.push(BangumiViewModel.mkSelection(field, keyword, label));
    }
    this.selections = next;
    this.rebuildRows();
    await this.loadIndexFirst();
  }

  toggleExpanded(): void {
    this.expanded = !this.expanded;
  }

  /** 当前应展示的筛选行数（折叠态最多 5 行） */
  visibleRowCount(): number {
    const n = this.rows.length;
    if (n <= COLLAPSE_THRESHOLD) {
      return n;
    }
    return this.expanded ? n : Math.floor(n / 2);
  }

  /** 是否需要「更多筛选」开关 */
  showToggle(): boolean {
    return this.rows.length > COLLAPSE_THRESHOLD;
  }

  /** 当前可见的筛选行（折叠态只取前 visibleRowCount() 行） */
  visibleRows(): BangumiFilterRow[] {
    return this.rows.slice(0, this.visibleRowCount());
  }

  isSelected(field: string, keyword: string): boolean {
    for (let i = 0; i < this.selections.length; i++) {
      const s = this.selections[i];
      if (s.field === field) {
        return s.value === keyword;
      }
    }
    return false;
  }

  async loadIndexFirst(): Promise<void> {
    this.page = 1;
    this.hasMore = true;
    this.indexState = DataState.loading<BangumiItem[]>();
    await this.fetchIndex(false);
  }

  async loadMoreIndex(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    this.page++;
    // 失败时 fetchIndex 内部回退页码，下次上拉可重试同一页
    await this.fetchIndex(true);
    this.isLoadingMore = false;
  }

  get errorMessage(): string {
    return this.indexState.error?.message
      ?? this.conditionState.error?.message
      ?? this.rankState.error?.message
      ?? AppError.unknown('').message;
  }

  // ==================== 内部实现 ====================

  private async fetchIndex(append: boolean): Promise<void> {
    const r = await this.repo.getIndexResult(this.buildQuery(), this.page);
    if (!r.isOk) {
      if (append) {
        this.page--; // 失败回退页码，避免漏页
      }
      this.indexState = DataState.error<BangumiItem[]>(r.error, this.indexItems.length > 0 ? this.indexItems : null);
      return;
    }
    const res = r.value;
    this.hasMore = res.hasNext;
    this.indexItems = append ? this.indexItems.concat(res.items) : res.items;
    this.indexState = this.indexItems.length > 0
      ? DataState.data<BangumiItem[]>(this.indexItems)
      : DataState.empty<BangumiItem[]>();
  }

  /** 组装索引查询参数：season_type / type + order + 各筛选分组当前值 */
  private buildQuery(): Record<string, string | number | boolean> {
    const q: Record<string, string | number | boolean> = {};
    q['season_type'] = this.seasonType;
    q['type'] = this.indexType;
    for (let i = 0; i < this.selections.length; i++) {
      const s = this.selections[i];
      if (s.value.length === 0) {
        continue;
      }
      q[s.field === BANGUMI_ORDER_KEY ? 'order' : s.field] = s.value;
    }
    return q;
  }

  private rebuildRows(): void {
    const rows: BangumiFilterRow[] = [];
    if (this.orders.length > 0) {
      const row = new BangumiFilterRow();
      row.field = BANGUMI_ORDER_KEY;
      row.values = this.orders.map((o: BangumiOrderItem) => {
        const v = new BangumiConditionValue();
        v.keyword = o.field;
        v.name = o.name;
        return v;
      });
      rows.push(row);
    }
    for (let i = 0; i < this.groups.length; i++) {
      const g = this.groups[i];
      const row = new BangumiFilterRow();
      row.field = g.field;
      row.values = g.values;
      rows.push(row);
    }
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      row.current = this.valueOf(row.field);
      row.pill = this.labelOf(row.field, row.values);
      row.key = `${row.field}_${row.current}`;
    }
    this.rows = rows;
  }

  private valueOf(field: string): string {
    for (let i = 0; i < this.selections.length; i++) {
      if (this.selections[i].field === field) {
        return this.selections[i].value;
      }
    }
    return '';
  }

  private labelOf(field: string, values: BangumiConditionValue[]): string {
    for (let i = 0; i < this.selections.length; i++) {
      if (this.selections[i].field === field) {
        return this.selections[i].label;
      }
    }
    return values.length > 0 ? values[0].name : '';
  }

  private static mkSelection(field: string, value: string, label: string): BangumiSelection {
    const s = new BangumiSelection();
    s.field = field;
    s.value = value;
    s.label = label;
    return s;
  }
}
