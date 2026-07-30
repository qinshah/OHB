import { Logger } from '../utils/Logger';

/**
 * 全局导航服务。
 * NavPathStack 不能做 @State/@Provide 状态装饰（Navigation 渲染期间会内部变更它，
 * 触发 changed-during-render 错误导致白屏），故主框架注册实例到这里，
 * 各页面通过本服务做路由跳转。
 */
export class NavService {
  private static stack: NavPathStack | null = null;

  static register(stack: NavPathStack): void {
    NavService.stack = stack;
  }

  static push(name: string, param?: Object): void {
    if (NavService.stack === null) {
      Logger.error('Nav', 'navStack not registered');
      return;
    }
    if (param !== undefined) {
      NavService.stack.pushPath({ name: name, param: param });
    } else {
      NavService.stack.pushPath({ name: name });
    }
  }

  static pop(): void {
    NavService.stack?.pop();
  }

  static popToRoot(): void {
    NavService.stack?.popToIndex(0);
  }
}
