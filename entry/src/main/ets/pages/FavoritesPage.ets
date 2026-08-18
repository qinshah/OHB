import { DataState, DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FavoriteFolder } from '../models/FavoriteModels';
import { FavoriteViewModel } from '../viewmodel/FavoriteViewModel';
import { AccountManager } from '../services/account/AccountManager';
import { AppError } from '../common/result/AppError';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { FavoriteDetailParam } from './RouteParams';

/**
 * 收藏页（P2 Task 16）：收藏夹列表，点击进入收藏夹详情。
 */
@Component
export struct FavoritesPage {
  @State vm: FavoriteViewModel = new FavoriteViewModel();

  aboutToAppear(): void {
    const am = AccountManager.getInstance();
    if (!am.isLoggedIn) {
      this.vm.folderState = DataState.error<FavoriteFolder[]>(ErrorHolder.unauthorized());
      return;
    }
    this.vm.loadFolders(Number(am.current?.mid ?? 0));
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            Route.pop();
          })
        Text('我的收藏')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.folderState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.folderState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.folderState.error?.message ?? '加载失败',
          retryable: true,
          onRetry: () => {
            const am = AccountManager.getInstance();
            this.vm.loadFolders(Number(am.current?.mid ?? 0));
          }
        })
          .layoutWeight(1)
      } else if (this.vm.folderState.status === DataStatus.Empty) {
        EmptyView({ tip: '还没有收藏夹' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.folders, (folder: FavoriteFolder) => {
            ListItem() {
              Row({ space: 10 }) {
                Image(folder.cover)
                  .width(96)
                  .height(60)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .alt($r('app.media.startIcon'))
                Column({ space: 4 }) {
                  Text(folder.title)
                    .fontSize(15)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${folder.mediaCount}个内容`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›')
                  .fontSize(20)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                const p: FavoriteDetailParam = { mediaId: folder.id, title: folder.title };
                Route.push(Route.favoriteDetail, p);
              })
            }
          }, (folder: FavoriteFolder) => `${folder.id}`)
        }
        .padding(8)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }
}

/** 未登录占位错误 */
class ErrorHolder {
  static unauthorized(): AppError {
    return AppError.unauthorized('请先登录后查看收藏');
  }
}
