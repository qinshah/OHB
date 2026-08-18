import { DataStatus } from '../common/state/DataState';
import { Route } from '../framework/Route';
import { HotSearchItem } from '../models/SearchModels';
import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { AppColors } from '../theme/AppTheme';

/**
 * 搜索首页（Task 7）：搜索框 + 建议联想 + 热搜 + 历史。
 */
@Component
export struct SearchPage {
  @State vm: SearchViewModel = new SearchViewModel();
  @State inputText: string = '';

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.vm.init(ctx);
    }
    if (this.vm.hotState.status === DataStatus.Idle) {
      this.vm.loadHot();
    }
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            // 建议列表
            if (this.vm.suggestions.length > 0) {
              Column() {
                ForEach(this.vm.suggestions, (term: string) => {
                  Text(term)
                    .fontSize(15)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .width('100%')
                    .padding({
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 12
                    })
                    .onClick(() => {
                      this.gotoResult(term);
                    })
                }, (term: string) => term)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            } else {
              // 搜索历史
              if (this.vm.history.length > 0) {
                Column({ space: 8 }) {
                  Row() {
                    Text('搜索历史')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Blank()
                    Text('清空')
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .onClick(() => {
                        this.vm.clearHistory();
                      })
                  }
                  .width('100%')

                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.vm.history, (kw: string) => {
                      Text(kw)
                        .fontSize(13)
                        .fontColor(AppColors.TEXT_PRIMARY)
                        .backgroundColor(AppColors.CARD_BG)
                        .borderRadius(14)
                        .padding({
                          left: 12,
                          right: 12,
                          top: 6,
                          bottom: 6
                        })
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.gotoResult(kw);
                        })
                    }, (kw: string) => kw)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              // 热搜榜
              Column({ space: 8 }) {
                Text('哔哩哔哩热搜')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .width('100%')
                if (this.vm.hotState.status === DataStatus.Loading) {
                  LoadingProgress()
                    .width(28)
                    .height(28)
                    .color(AppColors.BRAND)
                    .margin({ top: 12 })
                } else {
                  ForEach(this.vm.hotItems, (item: HotSearchItem, index: number) => {
                    Row({ space: 8 }) {
                      Text(`${index + 1}`)
                        .fontSize(14)
                        .fontColor(index < 3 ? AppColors.BRAND : AppColors.TEXT_SECONDARY)
                        .fontWeight(FontWeight.Bold)
                        .width(20)
                      Text(item.showName)
                        .fontSize(14)
                        .fontColor(AppColors.TEXT_PRIMARY)
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })
                    .onClick(() => {
                      this.gotoResult(item.keyword);
                    })
                  }, (item: HotSearchItem) => item.keyword)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.PAGE_BG)
    }

    .title(this.buildSearchBar())
  }

  @Builder
  buildSearchBar() {

    // 搜索栏
    Row({ space: 8 }) {
      Search({ value:this.inputText, placeholder: '搜索视频、UP主、番剧' })
        .layoutWeight(1)
        .height(40)
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .onChange((v: string) => {
          this.inputText = v
          this.vm.onKeywordChange(v);
        })
        .defaultFocus(true)
        .onSubmit((v) => {
          this.gotoResult(v);
        })
      Button('搜索')
        .height(40)
        .backgroundColor(AppColors.BRAND)
        .fontColor(Color.White)
        .onClick(() => {
          this.gotoResult(this.inputText);
        })
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 8,
      bottom: 8
    })

  }

  private gotoResult(keyword: string): void {
    const kw = keyword.trim();
    if (kw.length === 0) {
      return;
    }
    Route.push(Route.searchResult, kw);
  }
}
