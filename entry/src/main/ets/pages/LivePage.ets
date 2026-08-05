import { DataStatus } from '../common/state/DataState';
import { NavService } from '../common/navigation/NavService';
import { FormatUtils } from '../common/utils/FormatUtils';
import { LiveArea, LiveRoom } from '../models/LiveModels';
import { LiveViewModel } from '../viewmodel/LiveViewModel';
import { EmptyView, ErrorView, LoadingView } from '../common/components/StateViews';
import { AppColors } from '../theme/AppTheme';
import { RouteNames } from './RouteNames';
import { LiveRoomParam } from './RouteParams';

/**
 * 直播页（P2 Task 15）：分区 Tab + 直播间列表，点击进入直播间。
 */
@Component
export struct LivePage {
  @State vm: LiveViewModel = new LiveViewModel();

  aboutToAppear(): void {
    this.vm.loadAreas();
    this.vm.loadFirst(0);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width(32)
          .onClick(() => {
            NavService.pop();
          })
        Text('直播')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      // 分区栏
      if (this.vm.areaState.status === DataStatus.Data) {
        Scroll() {
          Row({ space: 8 }) {
            this.AreaTag(0, '全部')
            ForEach(this.vm.areas, (area: LiveArea) => {
              this.AreaTag(area.id, area.name)
            }, (area: LiveArea) => `${area.id}`)
          }
          .padding({ left: 12, right: 12, top: 4, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      // 直播间列表
      if (this.vm.roomState.status === DataStatus.Loading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.vm.roomState.status === DataStatus.Error && this.vm.rooms.length === 0) {
        ErrorView({
          message: this.vm.errorMessage,
          retryable: true,
          onRetry: () => {
            this.vm.loadFirst(this.vm.currentAreaId);
          }
        })
          .layoutWeight(1)
      } else if (this.vm.roomState.status === DataStatus.Empty) {
        EmptyView({ tip: '该分区暂无直播' })
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.rooms, (room: LiveRoom) => {
            ListItem() {
              this.LiveCard(room)
            }
          }, (room: LiveRoom) => `${room.roomId}`)
        }
        .padding(8)
        .onReachEnd(() => {
          this.vm.loadMore();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BG)
  }

  @Builder
  AreaTag(id: number, name: string) {
    Text(name)
      .fontSize(13)
      .fontColor(this.vm.currentAreaId === id ? Color.White : AppColors.TEXT_PRIMARY)
      .backgroundColor(this.vm.currentAreaId === id ? AppColors.BRAND : AppColors.CARD_BG)
      .borderRadius(15)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .onClick(() => {
        if (this.vm.currentAreaId !== id) {
          this.vm.loadFirst(id);
        }
      })
  }

  @Builder
  LiveCard(room: LiveRoom) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(room.cover)
          .width(140)
          .height(84)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.startIcon'))
        Text(`${FormatUtils.count(room.online)}观看`)
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
        Text(room.title)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Image(room.face)
            .width(18)
            .height(18)
            .borderRadius(9)
            .alt($r('app.media.startIcon'))
          Text(room.uname)
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
          Text(room.areaName)
            .fontSize(11)
            .fontColor(AppColors.BRAND)
            .maxLines(1)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(10)
    .onClick(() => {
      const p: LiveRoomParam = { roomId: room.roomId, title: room.title };
      NavService.push(RouteNames.LIVE_ROOM, p);
    })
  }
}
