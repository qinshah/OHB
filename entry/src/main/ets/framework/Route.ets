import { Logger } from '../common/utils/Logger';
import { DisplayHelper } from '../common/utils/DisplayHelper';
import { VideoDetailPage } from '../pages/VideoDetailPage';
import { SearchPage } from '../pages/SearchPage';
import { SearchResultPage } from '../pages/SearchResultPage';
import { LoginPage } from '../pages/LoginPage';
import { VideoFullscreenPage } from '../pages/VideoFullscreenPage';
import { LivePage } from '../pages/LivePage';
import { LiveRoomPage } from '../pages/LiveRoomPage';
import { FavoritesPage } from '../pages/FavoritesPage';
import { FavoriteDetailPage } from '../pages/FavoriteDetailPage';
import { HistoryPage } from '../pages/HistoryPage';
import { WatchLaterPage } from '../pages/WatchLaterPage';
import { UserSpacePage } from '../pages/UserSpacePage';
import { DynamicDetailPage } from '../pages/DynamicDetailPage';
import { PublishDynamicPage } from '../pages/PublishDynamicPage';
import { TopicPage } from '../pages/TopicPage';
import { TopicFeedPage } from '../pages/TopicFeedPage';
import { BangumiPage } from '../pages/BangumiPage';
import { BangumiDetailPage } from '../pages/BangumiDetailPage';
import { MusicPage } from '../pages/MusicPage';
import { SettingsPage } from '../pages/SettingsPage';
import {
  BangumiDetailParam,
  DynamicDetailParam,
  FavoriteDetailParam,
  LiveRoomParam,
  TopicFeedParam,
  UserSpaceParam
} from '../pages/RouteParams';

let routeMap: Map<string, WrappedBuilder<Object[]>> = new Map()

export class RoutePage {
  name: string
  builder: WrappedBuilder<Object[]>

  constructor(name: string, builder: WrappedBuilder<Object[]>) {
    this.name = name
    this.builder = builder
    routeMap[this.name] = this.builder
  }
}

export class Route {
  private static stack: NavPathStack | null = null;

  static get(name: string): WrappedBuilder<Object[]> | undefined {
    return routeMap[name]
  }

  static register(stack: NavPathStack): void {
    Route.stack = stack;
    try {
      stack.setInterception({
        didShow: (_from: NavDestinationContext | NavBar, to: NavDestinationContext | NavBar,
          _operation: NavigationOperation, _isAnimated: boolean) => {
          if (typeof to === 'object') {
            const ctx = to as NavDestinationContext;
            const name = ctx.pathInfo.name;
            DisplayHelper.onRouteChanged(name, true);
          } else {
            DisplayHelper.onRouteChanged(undefined, true);
          }
        }
      });
    } catch (e) {
      Logger.error('Nav', `setInterception fail: ${JSON.stringify(e)}`);
    }
  }

  static push(page: RoutePage, param?: Object): void {
    if (Route.stack === null) {
      Logger.error('Nav', 'navStack not registered');
      return;
    }
    Route.stack.pushPath({ name: page.name, param: param });
  }

  static pop(): void {
    Route.stack?.pop();
  }

  static popToRoot(): void {
    Route.stack?.popToIndex(0);
  }

  static readonly videoDetail: RoutePage = new RoutePage(VideoDetailPage.name, wrapBuilder(videoDetailPageBuilder))
  static readonly search: RoutePage = new RoutePage(SearchPage.name, wrapBuilder(searchPageBuilder))
  static readonly searchResult: RoutePage = new RoutePage(SearchResultPage.name, wrapBuilder(searchResultPageBuilder))
  static readonly login: RoutePage = new RoutePage(LoginPage.name, wrapBuilder(loginPageBuilder))
  static readonly videoFullscreen: RoutePage =
    new RoutePage(VideoFullscreenPage.name, wrapBuilder(videoFullscreenPageBuilder))
  static readonly live: RoutePage = new RoutePage(LivePage.name, wrapBuilder(livePageBuilder))
  static readonly liveRoom: RoutePage = new RoutePage(LiveRoomPage.name, wrapBuilder(liveRoomPageBuilder))
  static readonly favorites: RoutePage = new RoutePage(FavoritesPage.name, wrapBuilder(favoritesPageBuilder))
  static readonly favoriteDetail: RoutePage =
    new RoutePage(FavoriteDetailPage.name, wrapBuilder(favoriteDetailPageBuilder))
  static readonly history: RoutePage = new RoutePage(HistoryPage.name, wrapBuilder(historyPageBuilder))
  static readonly watchLater: RoutePage = new RoutePage(WatchLaterPage.name, wrapBuilder(watchLaterPageBuilder))
  static readonly userSpace: RoutePage = new RoutePage(UserSpacePage.name, wrapBuilder(userSpacePageBuilder))
  static readonly dynamicDetail: RoutePage =
    new RoutePage(DynamicDetailPage.name, wrapBuilder(dynamicDetailPageBuilder))
  static readonly publishDynamic: RoutePage =
    new RoutePage(PublishDynamicPage.name, wrapBuilder(publishDynamicPageBuilder))
  static readonly topic: RoutePage = new RoutePage(TopicPage.name, wrapBuilder(topicPageBuilder))
  static readonly topicFeed: RoutePage = new RoutePage(TopicFeedPage.name, wrapBuilder(topicFeedPageBuilder))
  static readonly bangumi: RoutePage = new RoutePage(BangumiPage.name, wrapBuilder(bangumiPageBuilder))
  static readonly bangumiDetail: RoutePage =
    new RoutePage(BangumiDetailPage.name, wrapBuilder(bangumiDetailPageBuilder))
  static readonly music: RoutePage = new RoutePage(MusicPage.name, wrapBuilder(musicPageBuilder))
  static readonly settings: RoutePage = new RoutePage(SettingsPage.name, wrapBuilder(settingsPageBuilder))
}

@Builder
function videoDetailPageBuilder(param: Object) {
  VideoDetailPage({ bvid: param as string })
}

@Builder
function searchPageBuilder(_param: Object) {
  SearchPage()
}

@Builder
function searchResultPageBuilder(param: Object) {
  SearchResultPage({ keyword: param as string })
}

@Builder
function loginPageBuilder(_param: Object) {
  LoginPage()
}

@Builder
function videoFullscreenPageBuilder(param: Object) {
  VideoFullscreenPage({ playerId: param as string })
}

@Builder
function livePageBuilder(_param: Object) {
  LivePage()
}

@Builder
function liveRoomPageBuilder(param: Object) {
  LiveRoomPage({ roomId: (param as LiveRoomParam).roomId, title: (param as LiveRoomParam).title })
}

@Builder
function favoritesPageBuilder(_param: Object) {
  FavoritesPage()
}

@Builder
function favoriteDetailPageBuilder(param: Object) {
  FavoriteDetailPage({ mediaId: (param as FavoriteDetailParam).mediaId, title: (param as FavoriteDetailParam).title })
}

@Builder
function historyPageBuilder(_param: Object) {
  HistoryPage()
}

@Builder
function watchLaterPageBuilder(_param: Object) {
  WatchLaterPage()
}

@Builder
function userSpacePageBuilder(param: Object) {
  UserSpacePage({ mid: (param as UserSpaceParam).mid })
}

@Builder
function dynamicDetailPageBuilder(param: Object) {
  DynamicDetailPage({ dynId: (param as DynamicDetailParam).id })
}

@Builder
function publishDynamicPageBuilder(_param: Object) {
  PublishDynamicPage()
}

@Builder
function topicPageBuilder(_param: Object) {
  TopicPage()
}

@Builder
function topicFeedPageBuilder(param: Object) {
  TopicFeedPage({ topicId: (param as TopicFeedParam).topicId, topicName: (param as TopicFeedParam).topicName })
}

@Builder
function bangumiPageBuilder(_param: Object) {
  BangumiPage()
}

@Builder
function bangumiDetailPageBuilder(param: Object) {
  BangumiDetailPage({ seasonId: (param as BangumiDetailParam).seasonId })
}

@Builder
function musicPageBuilder(_param: Object) {
  MusicPage()
}

@Builder
function settingsPageBuilder(_param: Object) {
  SettingsPage()
}
