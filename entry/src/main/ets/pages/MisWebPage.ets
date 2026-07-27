import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { LoginState } from '../model/LoginState';
import { SyncPhase, SyncStatus } from '../model/SyncStatus';
import { WhiteListManager } from '../manager/WhiteListManager';
import { SyncCoordinator } from '../manager/SyncCoordinator';
import { Theme } from '../common/Theme';
import { SyncRequest, SyncTarget } from '../model/CampusInfo';
import { MisWebParams } from '../model/RouteParams';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';

const MIS_URL: string = 'https://mis.bjtu.edu.cn/';

interface WebResourceRequest {
  getRequestUrl(): string;
}

@Entry({ routeName: 'MisWebPage' })
@Component
struct MisWebPage {
  @State currentUrl: string = MIS_URL;
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  @State syncStatus: SyncStatus = new SyncStatus();
  private controller: webview.WebviewController = new webview.WebviewController();
  private whiteListManager: WhiteListManager = WhiteListManager.getInstance();
  private coordinator: SyncCoordinator | undefined = undefined;

  aboutToAppear(): void {
    this.coordinator = new SyncCoordinator(
      this.controller,
      (status: SyncStatus): void => {
        this.syncStatus = status;
      },
      (state: LoginState): void => {
        this.loginState = state;
        if (state === LoginState.LOGGED_IN) {
          this.persistWebSession();
        }
      },
      (status: SyncStatus): void => {
        if (status.phase === SyncPhase.COMPLETED || status.phase === SyncPhase.PARTIAL_SUCCESS) {
          this.persistWebSession();
          const revision: number = AppStorage.get<number>('dataRevision') ?? 0;
          AppStorage.setOrCreate('dataRevision', revision + 1);
          promptAction.showToast({
            message: status.phase === SyncPhase.COMPLETED ? '同步完成' : '同步部分完成，旧数据已保留'
          });
          this.getUIContext().getRouter().back();
        }
      }
    );
    this.coordinator.start(this.buildSyncRequest());
  }

  private buildSyncRequest(): SyncRequest {
    const request: SyncRequest = new SyncRequest();
    const params: MisWebParams | undefined =
      this.getUIContext().getRouter().getParams() as MisWebParams | undefined;
    if (params === undefined || params.target === undefined ||
        params.target.length === 0 || params.target === 'all') {
      request.includeHistoricalGrades = false;
      return request;
    }
    const target: SyncTarget | undefined = this.parseTarget(params.target);
    if (target !== undefined) {
      request.targets = [target];
    }
    request.forceRefresh = true;
    request.includeHistoricalGrades = target === SyncTarget.GRADES;
    request.termCode = params.termCode ?? '';
    return request;
  }

  private parseTarget(value: string): SyncTarget | undefined {
    switch (value) {
      case SyncTarget.TIMETABLE: return SyncTarget.TIMETABLE;
      case SyncTarget.EXAMS: return SyncTarget.EXAMS;
      case SyncTarget.GRADES: return SyncTarget.GRADES;
      case SyncTarget.PROFILE: return SyncTarget.PROFILE;
      case SyncTarget.PROGRESS: return SyncTarget.PROGRESS;
      case SyncTarget.CALENDAR: return SyncTarget.CALENDAR;
      default: return undefined;
    }
  }

  aboutToDisappear(): void {
    if (this.coordinator !== undefined && this.syncStatus.running) {
      this.coordinator.cancel();
    }
    this.persistWebSession();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
      this.TopBar()
      Stack() {
        Web({ src: MIS_URL, controller: this.controller })
          .width('100%')
          .height('100%')
          .opacity(this.shouldShowOfficialPage() ? 1 : 0.01)
          .hitTestBehavior(this.shouldShowOfficialPage() ? HitTestMode.Default : HitTestMode.None)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .mixedMode(MixedMode.None)
          .onUrlLoadIntercept((event) => {
            if (event === undefined || event.data === undefined) {
              return false;
            }
            let url: string = '';
            if (typeof event.data === 'string') {
              url = event.data as string;
            } else {
              url = (event.data as WebResourceRequest).getRequestUrl();
            }
            if (url.length === 0) {
              return false;
            }
            this.currentUrl = url;
            if (!this.whiteListManager.isAllowed(url)) {
              const blockedDomain: string = this.whiteListManager.displayDomain(url);
              promptAction.showToast({
                message: blockedDomain.length > 0 ?
                  '已阻止未知域名：' + blockedDomain : '已阻止非 HTTPS 页面'
              });
              return true;
            }
            return false;
          })
          .onPageEnd((event) => {
            this.currentUrl = event.url;
            if (this.coordinator !== undefined) {
              this.coordinator.onPageEnd(this.currentUrl);
            }
          })
          .onErrorReceive(() => {
            if (this.coordinator !== undefined) {
              this.coordinator.onNetworkError();
            }
          })
        if (!this.shouldShowOfficialPage()) {
          this.SyncStatusView()
        }
      }
      .layoutWeight(1)
      .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.background())
      }
    }.width('100%').height('100%')
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .fontColor(Theme.primary())
        .onClick(() => {
          if (this.coordinator !== undefined && this.syncStatus.running) {
            this.coordinator.cancel();
          }
          this.getUIContext().getRouter().back();
        })
      Text(this.titleText())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row() {
      }.width(60).height(44)
    }
    .width('100%')
    .height(44)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Theme.topBackground())
  }

  @Builder
  SyncStatusView(): void {
    Column() {
      Column() {
        Text(this.phaseBadgeText())
          .fontSize(12)
          .fontColor(Theme.primary())
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor(Theme.primaryLight())
        Text(this.phaseTitle())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary())
          .margin({ top: 18 })
        Text(this.statusMessage())
          .fontSize(13)
          .fontColor(Theme.textSecondary())
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
        Row() {
          Text('总体进度')
            .fontSize(12)
            .fontColor(Theme.textSecondary())
            .layoutWeight(1)
          Text(this.syncStatus.totalProgress.toString() + '%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.primary())
        }
        .width('100%')
        .margin({ top: 24 })
        Progress({ value: this.syncStatus.totalProgress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(5)
          .color(Theme.primary())
          .margin({ top: 8 })
        if (this.syncStatus.gradeTotalTerms > 0) {
          Text('成绩学期 ' + this.syncStatus.gradeCompletedTerms + '/' + this.syncStatus.gradeTotalTerms)
            .fontSize(11)
            .fontColor(Theme.textSecondary())
            .margin({ top: 10 })
        }
        if (this.isFailurePhase()) {
          Button('重新尝试')
            .fontSize(14)
            .height(40)
            .width('100%')
            .fontColor(Theme.onPrimary())
            .backgroundColor(Theme.secondary())
            .margin({ top: 22 })
            .onClick(() => {
              if (this.coordinator !== undefined) {
                this.coordinator.retry();
              }
            })
        } else if (this.syncStatus.running) {
          Button('取消同步')
            .fontSize(14)
            .height(40)
            .width('100%')
            .fontColor(Theme.onPrimary())
            .backgroundColor(Theme.warning())
            .margin({ top: 22 })
            .onClick(() => {
              if (this.coordinator !== undefined) {
                this.coordinator.cancel();
              }
              this.getUIContext().getRouter().back();
            })
        }
      }
      .width('100%')
      .padding(22)
      .borderRadius(18)
      .backgroundColor(Theme.surface())
      Text('学校页面仅在后台读取，完成后会自动返回\n同步失败不会清除已有数据')
        .fontSize(12)
        .fontColor(Theme.textDisabled())
        .textAlign(TextAlign.Center)
        .lineHeight(19)
        .margin({ top: 18 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.background())
  }

  private shouldShowOfficialPage(): boolean {
    return this.syncStatus.phase === SyncPhase.WAITING_FOR_LOGIN &&
      this.loginState === LoginState.NOT_LOGGED_IN;
  }

  private isFailurePhase(): boolean {
    return this.syncStatus.phase === SyncPhase.SESSION_EXPIRED ||
      this.syncStatus.phase === SyncPhase.NETWORK_ERROR ||
      this.syncStatus.phase === SyncPhase.PAGE_NOT_RECOGNIZED ||
      this.syncStatus.phase === SyncPhase.PARSE_FAILED;
  }

  private phaseBadgeText(): string {
    if (this.isFailurePhase()) {
      return '需要处理';
    }
    if (this.syncStatus.phase === SyncPhase.WAITING_FOR_LOGIN) {
      return '正在连接';
    }
    if (this.syncStatus.phase === SyncPhase.VALIDATING ||
        this.syncStatus.phase === SyncPhase.COMMITTING) {
      return '即将完成';
    }
    return '安全同步中';
  }

  private phaseTitle(): string {
    switch (this.syncStatus.phase) {
      case SyncPhase.WAITING_FOR_LOGIN:
        return '正在检查登录状态';
      case SyncPhase.MIS_AUTHENTICATED:
      case SyncPhase.OPENING_AA:
      case SyncPhase.AA_READY:
        return '正在连接教务系统';
      case SyncPhase.LOADING_TIMETABLE:
      case SyncPhase.PARSING_TIMETABLE:
        return '正在同步课表';
      case SyncPhase.LOADING_EXAMS:
      case SyncPhase.PARSING_EXAMS:
        return '正在同步考试';
      case SyncPhase.DISCOVERING_SCORE_TERMS:
      case SyncPhase.LOADING_SCORE_TERM:
        return '正在同步历年成绩';
      case SyncPhase.LOADING_PROFILE:
      case SyncPhase.PARSING_PROFILE:
        return '正在同步个人信息';
      case SyncPhase.LOADING_PROGRESS:
      case SyncPhase.PARSING_PROGRESS:
        return '正在同步学业进度';
      case SyncPhase.LOADING_MAIL:
      case SyncPhase.PARSING_MAIL:
        return '正在连接校园邮箱';
      case SyncPhase.VALIDATING:
        return '正在校验数据';
      case SyncPhase.COMMITTING:
        return '正在保存到本机';
      case SyncPhase.SESSION_EXPIRED:
        return '登录状态已失效';
      case SyncPhase.NETWORK_ERROR:
        return '网络暂时不可用';
      case SyncPhase.PAGE_NOT_RECOGNIZED:
      case SyncPhase.PARSE_FAILED:
        return '同步没有完成';
      case SyncPhase.CANCELLED:
        return '同步已取消';
      default:
        return '正在准备同步';
    }
  }

  private statusMessage(): string {
    if (this.syncStatus.phase === SyncPhase.WAITING_FOR_LOGIN &&
        this.loginState !== LoginState.NOT_LOGGED_IN) {
      return '正在连接学校系统并检查现有登录状态';
    }
    return this.syncStatus.message;
  }

  private titleText(): string {
    if (this.shouldShowOfficialPage()) {
      return '学校官方登录';
    }
    if (this.syncStatus.running) {
      return '自动同步';
    }
    return '学校系统';
  }

  private persistWebSession(): void {
    try {
      webview.WebCookieManager.saveCookieSync();
    } catch (_) {
      // ArkWeb 尚未建立 Cookie 存储时无需阻断登录或同步。
    }
  }
}
