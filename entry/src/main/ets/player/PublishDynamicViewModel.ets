import { AppError } from '../common/result/AppError';
import { DynamicRepository } from '../data/repository/DynamicRepository';

/**
 * 发布动态 ViewModel（P2 Task 18）：纯文字/图文（文字内容）发布。
 */
@Observed
export class PublishDynamicViewModel {
  isPublishing: boolean = false;
  tipText: string = '';
  isSuccess: boolean = false;

  private repo: DynamicRepository = new DynamicRepository();

  async publish(text: string, topicId: number = 0, topicName: string = ''): Promise<boolean> {
    if (text.trim().length === 0 || this.isPublishing) {
      this.tipText = '动态内容不能为空';
      return false;
    }
    this.isPublishing = true;
    this.tipText = '';
    this.isSuccess = false;
    const r = await this.repo.publish(text, topicId, topicName);
    this.isPublishing = false;
    if (!r.isOk) {
      this.tipText = r.error.message;
      return false;
    }
    this.isSuccess = true;
    this.tipText = '发布成功';
    return true;
  }

  get errorMessage(): string {
    return this.tipText.length > 0 ? this.tipText : AppError.unknown('').message;
  }
}
