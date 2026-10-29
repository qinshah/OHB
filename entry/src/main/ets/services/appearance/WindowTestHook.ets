import { window } from '@kit.ArkUI';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import BuildProfile from 'BuildProfile';

/** 启动参数键：目标窗口尺寸，形如 1400x900（px） */
export const TEST_WINDOW_PARAM = 'ohbTestWindow';

/** 主窗口可调整尺寸范围（px），与 2in1 自由窗口平台约束一致 */
const MIN_SIZE = 320;
const MAX_SIZE = 1920;

interface TestWindowSize {
  width: number;
  height: number;
}

/**
 * 调试构建的窗口尺寸注入入口：
 * 通过 `aa start ... --ps ohbTestWindow=1400x900` 把主窗口调整到指定尺寸，
 * 让窗口尺寸适配可以被自动化、可重复地验证。发布构建忽略该参数。
 */
export class WindowTestHook {
  static apply(want: Want, windowStage: window.WindowStage): void {
    if (!BuildProfile.DEBUG) {
      return;
    }
    const raw = want.parameters?.[TEST_WINDOW_PARAM];
    if (raw === undefined) {
      return;
    }
    const text = String(raw);
    const target = WindowTestHook.parse(text);
    if (target === null) {
      hilog.error(0, TAG, 'ohbTestWindow=%{public}s 非法或超出范围 [%{public}d, %{public}d]，忽略',
        text, MIN_SIZE, MAX_SIZE);
      return;
    }
    const win = windowStage.getMainWindowSync();
    // 启动瞬间窗口尚未进入可调整状态：先切自由窗口并延后一拍再 resize，
    // 失败时重试一次（部分 PC 会沿用上次最大化状态，首次 resize 被拒）
    WindowTestHook.resize(win, target, text).catch((e: Error) => {
      hilog.error(0, TAG, 'ohbTestWindow=%{public}s 首次 resize 失败: %{public}s，重试', text, e.message);
      setTimeout(() => {
        WindowTestHook.resize(win, target, text).then(() => {
          hilog.info(0, TAG, 'ohbTestWindow 已调整为 %{public}s（重试成功）', text);
        }).catch((err: Error) => {
          hilog.error(0, TAG, 'ohbTestWindow=%{public}s resize 失败: %{public}s', text, err.message);
        });
      }, 400);
    });
  }

  private static async resize(win: window.Window, target: TestWindowSize, text: string): Promise<void> {
    // 上一轮若是全屏/最大化，resize 会被系统以“window state abnormal”拒绝，
    // 先 recover() 退回浮窗状态；已是浮窗时 recover 会抛 1300001，忽略即可。
    await win.recover().catch(() => {
      // 无需处理：非全屏/最大化状态下 recover 必然失败
    });
    await win.resize(target.width, target.height);
    hilog.info(0, TAG, 'ohbTestWindow 已调整为 %{public}s', text);
  }

  private static parse(raw: string): TestWindowSize | null {
    const parts = raw.split('x');
    if (parts.length !== 2) {
      return null;
    }
    const width = Number(parts[0]);
    const height = Number(parts[1]);
    if (!Number.isFinite(width) || !Number.isFinite(height)) {
      return null;
    }
    if (width < MIN_SIZE || width > MAX_SIZE || height < MIN_SIZE || height > MAX_SIZE) {
      return null;
    }
    return { width: Math.floor(width), height: Math.floor(height) };
  }
}

const TAG = WindowTestHook.name;
