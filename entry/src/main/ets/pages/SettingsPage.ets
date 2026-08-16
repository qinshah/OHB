import { NavService } from '../common/navigation/NavService';
import { AppColors } from '../theme/AppTheme';
import { common, ConfigurationConstant, bundleManager } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { Pref } from '../services/storage/Pref';
import { Result } from '../common/result/Result';
import { AppError } from '../common/result/AppError';

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
  // 选择器/输入框本地镜像（直接从 Pref 读取初始值）
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
  @State tipText: string = '';
  @State appVersion: string = '1.0.0';
  private context: common.Context | undefined = undefined;

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext();
    this.loadVersion();
    this.syncFromPref();
  }

  /** 读取应用版本 */
  private async loadVersion(): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = `${info.versionName} (${info.versionCode})`;
    } catch (e) {
      this.appVersion = '1.0.0';
    }
  }

  /** 从 Pref 同步所有设置到本地 @State */
  private syncFromPref(): void {
    this.qualityIndex = this.indexOfQuality(Pref.DEFAULT_QUALITY.get());
    this.speedIndex = this.indexOfSpeed(Pref.DEFAULT_SPEED.get());
    this.darkIndex = this.indexOfDark(Pref.DARK_MODE.get());
    this.autoPlay = Pref.AUTO_PLAY_NEXT.get();
    this.danmakuOn = Pref.DANMAKU_ENABLED.get();
    this.searchHistoryOn = Pref.SEARCH_HISTORY_ENABLED.get();
    this.logOn = Pref.LOG_ENABLED.get();
    this.keywordsText = Pref.FILTER_KEYWORDS.get();
    this.blackMidsText = Pref.FILTER_BLACK_MIDS.get();
    this.minLikeRatio = Pref.FILTER_MIN_LIKE_RATIO.get();
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

  /** 应用深色模式 */
  private applyDarkMode(mode: string): void {
    if (this.context === undefined) {
      return;
    }
    try {
      let cm = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (mode === 'light') {
        cm = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (mode === 'dark') {
        cm = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }
      this.context.getApplicationContext().setColorMode(cm);
    } catch (e) {
      this.tipText = `应用主题失败：${JSON.stringify(e)}`;
    }
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
              Pref.DEFAULT_QUALITY.put(QUALITY_OPTIONS[idx].value);
            })
          this.SelectRow('默认倍速', SettingsPage.toSelectOptions(SPEED_OPTIONS.map((o: SpeedOption) => o.label)),
            this.speedIndex, (idx: number) => {
              this.speedIndex = idx;
              Pref.DEFAULT_SPEED.put(SPEED_OPTIONS[idx].value);
            })
          this.ToggleRow('自动连播下一P', this.autoPlay, (on: boolean) => {
            this.autoPlay = on;
            Pref.AUTO_PLAY_NEXT.put(on);
          })
          this.ToggleRow('弹幕开关', this.danmakuOn, (on: boolean) => {
            this.danmakuOn = on;
            Pref.DANMAKU_ENABLED.put(on);
          })

          // 外观
          this.SectionTitle('外观')
          this.SelectRow('深色模式', SettingsPage.toSelectOptions(DARK_OPTIONS.map((o: DarkOption) => o.label)),
            this.darkIndex, (idx: number) => {
              this.darkIndex = idx;
              const mode = DARK_OPTIONS[idx].value;
              Pref.DARK_MODE.put(mode);
              this.applyDarkMode(mode);
            })

          // 搜索
          this.SectionTitle('搜索')
          this.ToggleRow('保存搜索历史', this.searchHistoryOn, (on: boolean) => {
            this.searchHistoryOn = on;
            Pref.SEARCH_HISTORY_ENABLED.put(on);
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
                Pref.FILTER_KEYWORDS.put(v);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          Column({ space: 6 }) {
            Text('黑名单 up mid（逗号分隔）')
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
                Pref.FILTER_BLACK_MIDS.put(v);
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
                Pref.FILTER_MIN_LIKE_RATIO.put(value);
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
            Pref.LOG_ENABLED.put(on);
          })

          // 关于
          this.SectionTitle('关于')
          Row() {
            Text('OHB · 鸿蒙第三方 Bilibili 客户端')
              .fontSize(13)
              .fontColor(AppColors.TEXT_PRIMARY)
            Blank()
            Text(this.appVersion)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(10)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(10)

          if (this.tipText.length > 0) {
            Text(this.tipText)
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

  /** 导出：使用系统分享功能 */
  private async doExport(): Promise<void> {
    if (this.context === undefined) {
      this.tipText = '上下文未初始化';
      return;
    }

    try {
      // 生成 JSON 数据
      const json = Pref.exportJson();

      // 创建临时文件
      const tempDir = this.context.cacheDir;
      const fileName = 'ohb_settings.json';
      const filePath = `${tempDir}/${fileName}`;

      // 写入文件
      const file = fileIo.openSync(filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file);

      // 使用系统分享
      // 将文件路径转换为 URI
      const uri = fileUri.getUriFromPath(filePath);

      // 获取 JSON 文件的 UTD 类型
      const utdTypeId = utd.getUniformDataTypeByFilenameExtension('.json', utd.UniformDataType.FILE);

      // 创建分享数据
      const sharedData = new systemShare.SharedData({
        utd: utdTypeId,
        uri: uri
      });

      // 创建分享控制器
      const controller = new systemShare.ShareController(sharedData);

      // 注册分享面板关闭监听
      controller.on('dismiss', () => {
        console.info('分享面板已关闭');
      });

      // 显示分享面板
      controller.show(this.context as common.UIAbilityContext, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      this.tipText = '设置已导出';
    } catch (e) {
      this.tipText = `导出失败：${JSON.stringify(e)}`;
    }
  }

  /** 导入：读取文件并解析 */
  private async doImport(): Promise<void> {
    if (this.context === undefined) {
      this.tipText = '上下文未初始化';
      return;
    }

    try {
      // 使用系统文件选择器选择文件
      const DocumentViewPicker = picker.DocumentViewPicker;
      const dp = new DocumentViewPicker(this.context);
      const uris = await dp.select({ maxSelectNumber: 1 });

      if (uris.length === 0) {
        this.tipText = '已取消导入';
        return;
      }

      // 读取文件内容
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);

      const decoder = new util.TextDecoder('utf-8');
      const json = decoder.decodeToString(new Uint8Array(buffer));

      // 导入设置
      const r = await Pref.importJson(json);
      if (r.isOk) {
        this.tipText = '设置导入成功';
        this.syncFromPref(); // 重新同步 UI
      } else {
        this.tipText = r.error.message;
      }
    } catch (e) {
      this.tipText = `导入失败：${JSON.stringify(e)}`;
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
        action: async () => {
          const r = await Pref.resetAll();
          if (r.isOk) {
            this.tipText = '已重置全部设置';
            this.syncFromPref(); // 重新同步 UI
          } else {
            this.tipText = r.error.message;
          }
        }
      }
    });
  }
}
