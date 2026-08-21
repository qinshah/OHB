import { VideoCard } from '../../models/VideoCard';
import { FormatUtils } from '../utils/FormatUtils';
import { AppColors } from '../../theme/AppTheme';

/**
 * 视频卡片组件（首页/搜索/热门通用）
 */
@Component
export struct VideoListTile {
  @Prop card: VideoCard;
  onCardClick: (bvid: string) => void = () => {
  };

  build() {
    Row() {
      // 封面 + 时长角标
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(this.card.cover)
          .aspectRatio(16 / 9)
          .objectFit(ImageFit.Auto)
          .borderRadius(8)
          .alt($r('app.media.startIcon'))
        if (this.card.duration > 0) {
          Text(FormatUtils.duration(this.card.duration))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({
              left: 4,
              right: 4,
              top: 1,
              bottom: 1
            })
            .margin({ right: 6, bottom: 6 })
        }
        if (this.card.rcmdReason.length > 0) {
          Text(this.card.rcmdReason)
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor(AppColors.BRAND)
            .borderRadius({ topLeft: 8, bottomRight: 8 })
            .padding({
              left: 6,
              right: 6,
              top: 2,
              bottom: 2
            })
        }
      }
      .height('100%')

      Blank().width(6)

      Column() {
        // 标题
        Text(this.card.title)
          .fontSize(13)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
        Blank()
        // 作者
        Text(this.card.ownerName)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row(){
          Text(`[播放]${FormatUtils.count(this.card.playCount)}`)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
          Blank(2)
          Text(`[弹幕]${FormatUtils.count(this.card.danmakuCount)}`)
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
      }
      .height('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .padding(4)
    .onClick(() => {
      this.onCardClick(this.card.bvid);
    })
  }
}
