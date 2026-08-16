// [API 23+] 全局导航服务
import { Logger } from '../utils/Logger';
import { DisplayHelper } from '../utils/DisplayHelper';
import { Player } from '../../player/Player';

/**
 * 全局导航服务。
 * NavPathStack 不能做 @State/@Provide 状态装饰（Navigation 渲染期间会内部变更它，
 * 触发 changed-during-render 错误导致白屏），故主框架注册实例到这里，
 * 各页面通过本服务做路由跳转。
 *
 * 路由感知：在 register 时设置 setInterception 拦截器，
 * didShow 事件触发时通知 DisplayHelper，由其根据目标页面决定是否切换全屏/方向。
 */
export class NavService {
  private static stack: NavPathStack | null = null;

  static register(stack: NavPathStack): void {
    NavService.stack = stack;
    // 注册路由拦截器：didShow 时通知 DisplayHelper
    // - 仅页面级 NavDestination 触发 didShow 时才通知
    // - 弹窗/对话框等非页面级路由变化不处理
    try {
      stack.setInterception({
        didShow: (_from: NavDestinationContext | NavBar, to: NavDestinationContext | NavBar,
          _operation: NavigationOperation, _isAnimated: boolean) => {
          if (typeof to === 'object') {
            // to 是 NavDestinationContext → 进入了一个 NavDestination 页面
            const ctx = to as NavDestinationContext;
            const name = ctx.pathInfo.name;
            DisplayHelper.onRouteChanged(name, true);
          } else {
            // to === "navBar" → 返回到根页面（Tab 首页），通知 DisplayHelper 退出全屏
            DisplayHelper.onRouteChanged(undefined, true);
          }
        }
      });
    } catch (e) {
      Logger.error('Nav', `setInterception fail: ${JSON.stringify(e)}`);
    }
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
