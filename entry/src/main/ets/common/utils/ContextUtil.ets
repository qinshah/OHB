import { common } from "@kit.AbilityKit"

export class ContextUtil {
  static context: Context
  static appContext: common.ApplicationContext

  static init(context: Context) {
    ContextUtil.context = context
    ContextUtil.appContext = context.getApplicationContext()
  }
}