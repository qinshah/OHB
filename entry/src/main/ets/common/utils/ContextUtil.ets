export class ContextUtil {
  private static _context: Context | undefined = undefined

  static get context(): Context | undefined {
    return ContextUtil._context
  }

  static init(context: Context) {
    ContextUtil._context = context
  }
}