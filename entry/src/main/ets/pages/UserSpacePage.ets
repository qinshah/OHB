import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { FormatUtils } from '../common/utils/FormatUtils';
import { DynamicItem, DynamicKind } from '../models/DynamicItem';
import { FavoriteFolder } from '../models/FavoriteModels';
import { UserArchiveItem, UserSpaceInfo } from '../models/UserSpaceModels';
import { UserSpaceViewModel } from '../viewmodel/UserSpaceViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { DynamicDetailParam, FavoriteDetailParam } from './RouteParams';

/**
 * 用户主页（P2 Task 17）：空间信息 + 视频/动态/收藏 Tab + 关注。
 */
@Component
export struct UserSpacePage {
  @Prop mid: number = 0;
  @State vm: UserSpaceViewModel = new UserSpaceViewModel();
  @State currentTabIdx: number = 0;

  aboutToAppear(): void {
    this.vm.init(this.mid);
    this.vm.load();
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            Route.pop();
          })
        Text(this.vm.info?.name ?? '用户主页')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      if (this.vm.infoState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.infoState.status === DataStatus.Error) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.load();
          }
        })
          .layoutWeight(1)
      } else if (this.vm.info !== null) {
        Scroll() {
          Column({ space: 12 }) {
            this.ProfileCard(this.vm.info)
            Tabs({ index: $$this.currentTabIdx }) {
              TabContent() {
                this.ArchiveTab()
              }
              .tabBar('视频')

              TabContent() {
                this.DynamicTab()
              }
              .tabBar('动态')

              TabContent() {
                this.FolderTab()
              }
              .tabBar('收藏')
            }
            .barHeight(40)
            .onChange((idx: number) => {
              this.currentTabIdx = idx;
              if (idx === 0 && this.vm.archiveState.status === DataStatus.Idle) {
                this.vm.loadArchives();
              } else if (idx === 1 && this.vm.dynamicState.status === DataStatus.Idle) {
                this.vm.loadDynamics();
              } else if (idx === 2 && this.vm.folderState.status === DataStatus.Idle) {
                this.vm.loadFolders();
              }
            })
          }
          .width('100%')
          .padding(8)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  ProfileCard(info: UserSpaceInfo) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Image(info.face)
          .width(64)
          .height(64)
          .borderRadius(32)
          .alt($r('app.media.startIcon'))
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(info.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            if (info.isVip) {
              Text('大会员')
                .fontSize(10)
                .fontColor(Color.White)
                .backgroundColor(AppColors.BRAND)
                .borderRadius(6)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            }
          }
          Text(`LV${info.level} · ${info.sex}${info.officialTitle.length > 0 ? ' · ' + info.officialTitle : ''}`)
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.vm.isFollowing ? '已关注' : '+ 关注')
          .fontSize(13)
          .fontColor(this.vm.isFollowing ? AppColors.TEXT_SECONDARY : Color.White)
          .backgroundColor(this.vm.isFollowing ? AppColors.CARD_BG : AppColors.BRAND)
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 5, bottom: 5 })
          .border({ width: 1, color: AppColors.DIVIDER })
          .onClick(() => {
            this.vm.toggleFollow();
          })
      }
      .width('100%')

      if (info.sign.length > 0) {
        Text(info.sign)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Row() {
        Text(`${FormatUtils.count(info.follower)}粉丝`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(`${FormatUtils.count(info.following)}关注`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 16 })
        Text(`${info.archiveCount}视频`)
          .fontSize(12)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 16 })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ArchiveTab() {
    Column() {
      if (this.vm.archiveState.status === DataStatus.Loading) {
        LoadingView()
          .height(200)
      } else if (this.vm.archiveState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无投稿' })
          .height(200)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.archives, (item: UserArchiveItem) => {
            ListItem() {
              this.ArchiveRow(item)
            }
          }, (item: UserArchiveItem) => item.bvid)
        }
        .onReachEnd(() => {
          this.vm.loadMoreArchives();
        })
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ArchiveRow(item: UserArchiveItem) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(item.cover)
          .width(140)
          .height(84)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.startIcon'))
        Text(FormatUtils.duration(item.duration))
          .fontSize(10)
          .fontColor(Color.White)
          .backgroundColor('#99000000')
          .borderRadius(4)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .margin(4)
      }
      .width(140)
      .height(84)
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${FormatUtils.count(item.playCount)}播放 · ${FormatUtils.relativeTime(item.pubdate)}`)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      Route.push(Route.video, item.bvid);
    })
  }

  @Builder
  DynamicTab() {
    Column() {
      if (this.vm.dynamicState.status === DataStatus.Loading) {
        LoadingView()
          .height(200)
      } else if (this.vm.dynamicState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无动态' })
          .height(200)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.dynamics, (item: DynamicItem) => {
            ListItem() {
              this.SpaceDynamicCard(item)
            }
          }, (item: DynamicItem) => item.idStr)
        }
        .onReachEnd(() => {
          this.vm.loadMoreDynamics();
        })
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SpaceDynamicCard(item: DynamicItem) {
    Column({ space: 6 }) {
      if (item.text.length > 0) {
        Text(item.text)
          .fontSize(13)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (item.kind === DynamicKind.Video && item.videoBvid.length > 0) {
        Row({ space: 8 }) {
          Image(item.videoCover)
            .width(96)
            .height(60)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
          Text(item.videoTitle)
            .fontSize(13)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .onClick(() => {
          Route.push(Route.video, item.videoBvid);
        })
      }
      if (item.images.length > 0) {
        Row({ space: 4 }) {
          ForEach(item.images.slice(0, 3), (img: string) => {
            Image(img)
              .width(80)
              .height(80)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
              .alt($r('app.media.startIcon'))
          }, (img: string) => img)
        }
        .width('100%')
      }
      Text(FormatUtils.relativeTime(item.pubTs))
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      const p: DynamicDetailParam = { id: item.idStr };
      Route.push(Route.dynamicDetail, p);
    })
  }

  @Builder
  FolderTab() {
    Column() {
      if (this.vm.folderState.status === DataStatus.Loading) {
        LoadingView()
          .height(200)
      } else if (this.vm.folderState.status === DataStatus.Empty) {
        EmptyView({ tip: '暂无收藏夹' })
          .height(200)
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
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(1)
                  Text(`${folder.mediaCount}个内容`)
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(8)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(10)
              .onClick(() => {
                const p: FavoriteDetailParam = { mediaId: folder.id, title: folder.title };
                Route.push(Route.favoriteDetail, p);
              })
            }
          }, (folder: FavoriteFolder) => `${folder.id}`)
        }
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
