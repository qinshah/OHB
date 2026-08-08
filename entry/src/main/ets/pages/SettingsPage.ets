import { NavService } from '../common/navigation/NavService';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import { AppColors } from '../theme/AppTheme';
import { picker, fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

/** 清晰度选项 */
const QUALITY_OPTIONS: QualityOption[] = [
  { label: '8K (127)', value: 127 },
  { label: '4K (120)', value: 120 },
  { label: '1080P60 (116)', value: 116 },
  { label: '1080P+ (112)', value: 112 },
  { label: '1080P (80)', value: 80 },
  { label: '720P (64)', value: 64 },
  { label: '480P (32)', value: 32 },
  { label: '360P (16)', value: 16 }
];

/** 倍速选项 */
const SPEED_OPTIONS: SpeedOption[] = [
  { label: '0.5x', value: 0.5 },
  { label: '0.75x', value: 0.75 },
  { label: '1.0x', value: 1.0 },
  { label: '1.25x', value: 1.25 },
  { label: '1.5x', value: 1.5 },
  { label: '2.0x', value: 2.0 }
];

/** 深色模式选项 */
const DARK_OPTIONS: DarkOption[] = [
  { label: '跟随系统', value: 'system' },
  { label: '浅色', value: 'light' },
  { label: '深色', value: 'dark' }
];

interface QualityOption {
  label: string;
  value: number;
}

interface SpeedOption {
  label: string;
  value: number;
}

interface DarkOption {
  label: string;
  value: string;
}

/**
 * 设置中心（P1 Task 11）：播放/外观/搜索/隐私/日志/关于 + 导入导出/重置。
 */
@Component
export struct SettingsPage {
  @State vm: SettingsViewModel = new SettingsViewModel();
  // 选择器/输入框本地镜像
  @State qualityIndex: number = 0;
  @State speedIndex: number = 0;
  @State darkIndex: number = 0;
  @State autoPlay: boolean = true;
  @State danmakuOn: boolean = true;
  @State searchHistoryOn: boolean = true;
  @State logOn: boolean = false;
  @State keywordsText: string = '';
  @State blackMidsText: string = '';
  @State minLikeRatio: number = 0;
  @State busy: boolean = false;
  private context: common.Context | undefined = undefined;

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext();
    if (this.context !== undefined) {
      this.vm.init(this.context);
    }
    this.syncFromVm();
  }

  private syncFromVm(): void {
    this.qualityIndex = this.indexOfQuality(this.vm.defaultQuality);
    this.speedIndex = this.indexOfSpeed(this.vm.defaultSpeed);
    this.darkIndex = this.indexOfDark(this.vm.darkMode);
    this.autoPlay = this.vm.autoPlayNext;
    this.danmakuOn = this.vm.danmakuEnabled;
    this.searchHistoryOn = this.vm.searchHistoryEnabled;
    this.logOn = this.vm.logEnabled;
    this.keywordsText = this.vm.filterKeywords;
    this.blackMidsText = this.vm.filterBlackMids;
    this.minLikeRatio = this.vm.filterMinLikeRatio;
  }

  private indexOfQuality(qn: number): number {
    for (let i = 0; i < QUALITY_OPTIONS.length; i++) {
      if (QUALITY_OPTIONS[i].value === qn) {
        return i;
      }
    }
    return 4;
  }

  private indexOfSpeed(speed: number): number {
    for (let i = 0; i < SPEED_OPTIONS.length; i++) {
      if (SPEED_OPTIONS[i].value === speed) {
        return i;
      }
    }
    return 2;
  }

  private indexOfDark(mode: string): number {
    for (let i = 0; i < DARK_OPTIONS.length; i++) {
      if (DARK_OPTIONS[i].value === mode) {
        return i;
      }
    }
    return 0;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            NavService.pop();
          })
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: 8,
        right: 12,
        top: 8,
        bottom: 4
      })

      Scroll() {
        Column({ space: 10 }) {
          // 数据管理
          this.SectionTitle('数据管理')
          Row({ space: 8 }) {
            this.ActionButton('导出设置', () => {
              this.doExport();
            })
            this.ActionButton('导入设置', () => {
              this.doImport();
            })
            this.ActionButton('重置全部', () => {
              this.confirmReset();
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          // 播放
          this.SectionTitle('播放')
          this.SelectRow('默认清晰度', SettingsPage.toSelectOptions(QUALITY_OPTIONS.map((o: QualityOption) => o.label)),
            this.qualityIndex, (idx: number) => {
              this.qualityIndex = idx;
              this.vm.setDefaultQuality(QUALITY_OPTIONS[idx].value);
            })
          this.SelectRow('默认倍速', SettingsPage.toSelectOptions(SPEED_OPTIONS.map((o: SpeedOption) => o.label)),
            this.speedIndex, (idx: number) => {
              this.speedIndex = idx;
              this.vm.setDefaultSpeed(SPEED_OPTIONS[idx].value);
            })
          this.ToggleRow('自动连播下一P', this.autoPlay, (on: boolean) => {
            this.autoPlay = on;
            this.vm.setAutoPlayNext(on);
          })
          this.ToggleRow('弹幕开关', this.danmakuOn, (on: boolean) => {
            this.danmakuOn = on;
            this.vm.setDanmakuEnabled(on);
          })

          // 外观
          this.SectionTitle('外观')
          this.SelectRow('深色模式', SettingsPage.toSelectOptions(DARK_OPTIONS.map((o: DarkOption) => o.label)),
            this.darkIndex, (idx: number) => {
              this.darkIndex = idx;
              if (this.context !== undefined) {
                this.vm.setDarkMode(DARK_OPTIONS[idx].value, this.context);
              }
            })

          // 搜索
          this.SectionTitle('搜索')
          this.ToggleRow('保存搜索历史', this.searchHistoryOn, (on: boolean) => {
            this.searchHistoryOn = on;
            this.vm.setSearchHistoryEnabled(on);
          })

          // 隐私与过滤
          this.SectionTitle('隐私与过滤')
          Column({ space: 6 }) {
            Text('屏蔽关键词（逗号分隔，命中标题即过滤）')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
            TextInput({ text: $$this.keywordsText, placeholder: '如：广告,推广' })
              .width('100%')
              .height(38)
              .fontSize(13)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.keywordsText = v;
                this.vm.setFilterKeywords(v);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          Column({ space: 6 }) {
            Text('黑名单 UP mid（逗号分隔）')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .width('100%')
            TextInput({ text: $$this.blackMidsText, placeholder: '如：546195,1577803' })
              .width('100%')
              .height(38)
              .fontSize(13)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.blackMidsText = v;
                this.vm.setFilterBlackMids(v);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          Column({ space: 6 }) {
            Row() {
              Text('最低赞播比')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
              Blank()
              Text(`${Math.round(this.minLikeRatio * 100)}%`)
                .fontSize(13)
                .fontColor(AppColors.BRAND)
            }
            .width('100%')

            Slider({
              value: this.minLikeRatio,
              min: 0,
              max: 0.5,
              step: 0.01
            })
              .selectedColor(AppColors.BRAND)
              .onChange((value: number) => {
                this.minLikeRatio = value;
                this.vm.setFilterMinLikeRatio(value);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          // 日志
          this.SectionTitle('日志')
          this.ToggleRow('日志开关', this.logOn, (on: boolean) => {
            this.logOn = on;
            this.vm.setLogEnabled(on);
          })

          // 关于
          this.SectionTitle('关于')
          Row() {
            Text('OHB · 鸿蒙第三方 Bilibili 客户端')
              .fontSize(13)
              .fontColor(AppColors.TEXT_PRIMARY)
            Blank()
            Text(this.vm.appVersion)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          if (this.vm.tipText.length > 0) {
            Text(this.vm.tipText)
              .fontSize(12)
              .fontColor(AppColors.BRAND)
              .width('100%')
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TEXT_SECONDARY)
      .width('100%')
      .margin({ top: 6 })
  }

  @Builder
  ActionButton(label: string, onTap: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor(Color.White)
      .backgroundColor(AppColors.BRAND)
      .borderRadius(16)
      .padding({
        left: 16,
        right: 16,
        top: 8,
        bottom: 8
      })
      .onClick(() => {
        onTap();
      })
  }

  @Builder
  SelectRow(label: string, options: SelectOption[], selected: number, onPick: (idx: number) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
      Blank()
      Select(options)
        .selected(selected)
        .value(options[selected].value)
        .font({ size: 13 })
        .fontColor(AppColors.BRAND)
        .onSelect((idx: number) => {
          onPick(idx);
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
  }

  private static toSelectOptions(labels: string[]): SelectOption[] {
    return labels.map((l: string): SelectOption => {
      const opt: SelectOption = { value: l };
      return opt;
    });
  }

  @Builder
  ToggleRow(label: string, isOn: boolean, onChange: (on: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(AppColors.BRAND)
        .onChange((on: boolean) => {
          onChange(on);
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
  }

  // ---------- 导入 / 导出 / 重置 ----------

  private async doExport(): Promise<void> {
    if (this.busy || this.context === undefined) {
      return;
    }
    this.busy = true;
    try {
      const dp = new picker.DocumentViewPicker(this.context);
      const uris = await dp.save({ newFileNames: ['ohb_settings.json'] });
      if (uris.length === 0) {
        this.vm.tipText = '已取消导出';
        return;
      }
      const json = this.vm.exportJson();
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file);
      this.vm.tipText = '设置已导出（仅含非默认项）';
    } catch (e) {
      this.vm.tipText = `导出失败：${JSON.stringify(e)}`;
    } finally {
      this.busy = false;
    }
  }

  private async doImport(): Promise<void> {
    if (this.busy || this.context === undefined) {
      return;
    }
    this.busy = true;
    try {
      const dp = new picker.DocumentViewPicker(this.context);
      const uris = await dp.select({ maxSelectNumber: 1 });
      if (uris.length === 0) {
        this.vm.tipText = '已取消导入';
        return;
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
      const decoder = new util.TextDecoder('utf-8');
      const json = decoder.decodeToString(new Uint8Array(buffer));
      const r = await this.vm.importJson(json);
      if (r.isOk) {
        this.vm.tipText = '设置导入成功（缺失项保留原设置）';
        this.syncFromVm();
      } else {
        this.vm.tipText = r.error.message;
      }
    } catch (e) {
      this.vm.tipText = `导入失败：${JSON.stringify(e)}`;
    } finally {
      this.busy = false;
    }
  }

  private confirmReset(): void {
    AlertDialog.show({
      title: '重置全部设置',
      message: '确定要清除所有设置吗？该操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '重置',
        fontColor: AppColors.BRAND,
        action: () => {
          this.vm.resetAll().then(() => {
            this.syncFromVm();
          });
        }
      }
    });
  }
}
