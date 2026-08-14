export class ContextUtil {
  static context: Context

  static init(context: Context) {
    ContextUtil.context = context
  }
}