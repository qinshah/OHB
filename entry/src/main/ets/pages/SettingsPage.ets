import { Route } from '../framework/Route';
import { AppColors } from '../theme/AppTheme';
import { common, ConfigurationConstant, bundleManager } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { Pref } from '../services/storage/Pref';
import { Result } from '../common/result/Result';
import { AppError } from '../common/result/AppError';
import { ContextUtil } from '../common/utils/ContextUtil';

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
    NavDestination() {
      Column() {
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
    .title('设置')
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
    try {
      // 生成 JSON 数据
      const json = Pref.exportJson();

      // 创建临时文件
      const tempDir = ContextUtil.context.cacheDir;
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
      controller.show(ContextUtil.context as common.UIAbilityContext, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      // this.tipText = '设置已导出';
    } catch (e) {
      // this.tipText = `导出失败：${JSON.stringify(e)}`;
    }
  }

  /** 导入：读取文件并解析 */
  private async doImport(): Promise<void> {

    try {
      // 使用系统文件选择器选择文件
      const DocumentViewPicker = picker.DocumentViewPicker;
      const dp = new DocumentViewPicker(ContextUtil.context);
      const uris = await dp.select({ maxSelectNumber: 1 });

      if (uris.length === 0) {
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
      } else { // TODO
      }
    } catch (e) {
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
          } else { // TODO
          }
        }
      }
    });
  }
}
