import { common } from '@kit.AbilityKit';
import { LoginState, loginStateLabel } from '../model/LoginState';
import { CourseDataStore } from '../store/CourseDataStore';
import { SyncState } from '../model/SyncState';
import { ScheduleView } from './SchedulePage';
import { SettingsView } from './SettingsPage';
import { Theme } from '../common/Theme';
import { ExamView } from './ExamPage';
import { GradeView } from './GradePage';
import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { ExamInfo } from '../model/ExamInfo';
import { ExamTimeline } from '../model/ExamTimeline';
import { GradeInfo } from '../model/GradeInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { webview } from '@kit.ArkWeb';
import { SyncCoordinator } from '../manager/SyncCoordinator';
import { SyncPhase, SyncStatus } from '../model/SyncStatus';
import { WhiteListManager } from '../manager/WhiteListManager';
import { AcademicCalendar } from '../model/AcademicCalendar';
import { ChangeEvent, SyncTarget } from '../model/CampusInfo';

const MIS_URL: string = 'https://mis.bjtu.edu.cn/';

interface HomeWebResourceRequest {
  getRequestUrl(): string;
}

@Entry
@Component
struct HomePage {
  @State currentTabIndex: number = 0;
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  @State syncState: SyncState = new SyncState();
  @State courses: Array<CourseInfo> = [];
  @State exams: Array<ExamInfo> = [];
  @State grades: Array<GradeInfo> = [];
  @State changes: Array<ChangeEvent> = [];
  @State semester: SemesterInfo = new SemesterInfo();
  private initialLoginOpened: boolean = false;
  @State backgroundRefreshActive: boolean = false;
  private backgroundController: webview.WebviewController = new webview.WebviewController();
  private backgroundCoordinator: SyncCoordinator | undefined = undefined;
  private backgroundCurrentUrl: string = MIS_URL;
  private tabsController: TabsController = new TabsController();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.dataStore.init(getContext(this) as common.UIAbilityContext);
    this.loadData();
    if (!this.hasLocalData() && !this.initialLoginOpened) {
      this.initialLoginOpened = true;
      setTimeout(() => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/MisWebPage' });
      }, 300);
    } else if (this.dataStore.shouldAutoRefresh()) {
      this.startBackgroundRefresh();
    }
  }

  onPageShow(): void { this.loadData(); }
  loadData(): void {
    this.syncState = this.dataStore.loadSyncState();
    this.semester = this.dataStore.loadSemester();
    this.courses = CourseInfo.filterByTerm(this.dataStore.loadCourses(), this.semester.termCode);
    this.exams = this.dataStore.loadExams();
    this.grades = this.dataStore.loadGrades();
    this.changes = this.dataStore.loadChangeEvents();
  }

  build() {
    Stack() {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
        TabContent() { this.HomeContentView() }.tabBar(this.TabBarBuilder('首页', 0))
        TabContent() { ScheduleView() }.tabBar(this.TabBarBuilder('课表', 1))
        TabContent() { ExamView() }.tabBar(this.TabBarBuilder('考试', 2))
        TabContent() { GradeView() }.tabBar(this.TabBarBuilder('成绩', 3))
        TabContent() { SettingsView() }.tabBar(this.TabBarBuilder('设置', 4))
      }
      .barWidth('100%').barHeight(56)
      .onChange((index: number) => { this.currentTabIndex = index; })
      .layoutWeight(1)
      .barBackgroundColor(Theme.tabBackground())
      if (this.backgroundRefreshActive) {
        Web({ src: MIS_URL, controller: this.backgroundController })
          .width(8)
          .height(8)
          .opacity(0.01)
          .hitTestBehavior(HitTestMode.None)
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
              url = (event.data as HomeWebResourceRequest).getRequestUrl();
            }
            if (!WhiteListManager.getInstance().isAllowed(url)) {
              return true;
            }
            this.backgroundCurrentUrl = url;
            return false;
          })
          .onPageEnd((event) => {
            this.backgroundCurrentUrl = event.url;
            if (this.backgroundCoordinator !== undefined) {
              this.backgroundCoordinator.onPageEnd(this.backgroundCurrentUrl);
            }
          })
          .onErrorReceive(() => {
            if (this.backgroundCoordinator !== undefined) {
              this.backgroundCoordinator.onNetworkError();
            }
          })
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.background())
  }

  @Builder TabBarBuilder(label: string, index: number): void {
    Column() {
      Text(label).fontSize(12)
        .fontColor(this.currentTabIndex === index ? Theme.primary() : Theme.textDisabled())
    }.width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder HomeContentView(): void {
    Scroll() {
      Column() {
        this.StatusCard()
        this.OverviewCard()
        this.RecentChangesCard()
        this.QuickActions()
      }.width('100%').alignItems(HorizontalAlign.Center).padding({ left: 16, right: 16 })
    }.width('100%').height('100%')
  }

  @Builder
  OverviewCard(): void {
    Column() {
      this.SummaryRow('下一节课', this.nextCourseText())
      this.SummaryRow('今日课程', this.todayCourseCount().toString() + ' 门')
      this.SummaryRow('下一场考试', this.nextExamText())
      this.SummaryRow('最近成绩', this.recentGradeText())
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(Theme.surface())
    .margin({ top: 12 })
  }

  @Builder
  SummaryRow(label: string, value: string): void {
    Row() {
      Text(label).fontSize(13).fontColor(Theme.textSecondary()).width(88)
      Text(value).fontSize(13).fontColor(Theme.textPrimary()).layoutWeight(1).maxLines(1)
    }.width('100%').padding({ top: 5, bottom: 5 })
  }

  @Builder StatusCard(): void {
    Column() {
      Text('北京交通大学').fontSize(12).fontColor(Theme.textSecondary()).margin({ top: 16 })
      Text('MIS 助手').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.textPrimary()).margin({ top: 4 })
      Row() {
        Text(loginStateLabel(this.loginState, this.hasLocalData()))
          .fontSize(13)
          .fontColor(this.getStateColor())
      }.backgroundColor(this.getStateBgColor()).borderRadius(10)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 }).margin({ top: 8 })
      Text(this.syncState.hasData() ? '最后同步: ' + this.syncState.getSyncTimeText() : '尚未同步课表数据')
        .fontSize(12).fontColor(Theme.textDisabled()).margin({ top: 6 })
      if (this.syncState.hasData()) {
        Text('同步状态: ' + this.syncState.getOutcomeText())
          .fontSize(12)
          .fontColor(this.syncState.lastOutcome === 'partial_success' ? Theme.warning() : Theme.textSecondary())
          .margin({ top: 4 })
      }
    }
    .width('100%').padding(16).borderRadius(12)
    .backgroundColor(Theme.surface()).margin({ top: 60 }).alignItems(HorizontalAlign.Center)
  }

  @Builder QuickActions(): void {
    Column() {
      Text('服务').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .width('100%').margin({ top: 18, bottom: 10 })
      Row({ space: 10 }) {
        this.ServiceCard('课表', '本地 ' + this.courses.length + ' 门', '课', 1, '')
        this.ServiceCard('考试', this.exams.length + ' 条安排', '考', 2, '')
      }.width('100%').margin({ bottom: 10 })
      Row({ space: 10 }) {
        this.ServiceCard('成绩', this.grades.length + ' 条记录', '绩', 3, '')
        this.ServiceCard('学业进度', '学分与需关注课程', '进', -1, 'pages/ProgressPage')
      }.width('100%').margin({ bottom: 10 })
      Row({ space: 10 }) {
        this.ServiceCard('学年校历', '月份与教学周', '历', -1, 'pages/CalendarPage')
        this.ServiceCard('个人与培养信息', '只读官方信息', '人', -1, 'pages/ProfilePage')
      }.width('100%').margin({ bottom: 10 })
      Row({ space: 10 }) {
        this.ServiceCard('校园邮箱', '直接进入', '邮', -1, 'pages/MailOfficialPage')
        this.ServiceCard('同步中心', this.syncState.getOutcomeText(), '同', -1, 'pages/SyncCenterPage')
      }.width('100%').margin({ bottom: 28 })
    }.width('100%')
  }

  @Builder
  ServiceCard(
    title: string,
    status: string,
    icon: string,
    tabIndex: number,
    route: string
  ): void {
    Row() {
      Text(icon).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.primary())
        .width(34).height(34).textAlign(TextAlign.Center).borderRadius(10)
        .backgroundColor(Theme.primaryLight())
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
          .maxLines(1)
        Text(status).fontSize(10).fontColor(Theme.textSecondary()).maxLines(1).margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })
    }
    .layoutWeight(1).height(78).padding(12).borderRadius(12).backgroundColor(Theme.surface())
    .onClick(() => {
      if (tabIndex >= 0) {
        this.tabsController.changeIndex(tabIndex);
      } else if (route.length > 0) {
        this.getUIContext().getRouter().pushUrl({ url: route });
      }
    })
  }

  @Builder
  RecentChangesCard(): void {
    if (this.unreadChanges().length > 0) {
      Column() {
        Row() {
          Text('最近变化').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary()).layoutWeight(1)
          Text(this.unreadChanges().length + ' 条').fontSize(12).fontColor(Theme.primary())
        }.width('100%')
        ForEach(this.unreadChanges().slice(0, 3), (event: ChangeEvent) => {
          Row() {
            Text(this.changeTargetLabel(event.target)).fontSize(11)
              .fontColor(Theme.primary()).width(52)
            Text(event.summary).fontSize(12).fontColor(Theme.textPrimary())
              .layoutWeight(1).maxLines(1)
          }.width('100%').margin({ top: 9 })
        }, (event: ChangeEvent): string => event.id)
        Text('进入同步中心查看全部').fontSize(11).fontColor(Theme.textSecondary())
          .margin({ top: 10 }).alignSelf(ItemAlign.End)
      }.width('100%').padding(14).borderRadius(12).backgroundColor(Theme.surface())
        .margin({ top: 12 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/SyncCenterPage' });
        })
    }
  }

  private getStateColor(): ResourceColor {
    switch (this.loginState) {
      case LoginState.LOGGED_IN: return Theme.success();
      case LoginState.SESSION_EXPIRED: return Theme.warning();
      case LoginState.NETWORK_ERROR: return Theme.danger();
      case LoginState.LOGGING_IN: return Theme.primary();
      default: return this.hasLocalData() ? Theme.success() : Theme.textSecondary();
    }
  }

  private getStateBgColor(): ResourceColor { return Theme.card(); }

  private hasLocalData(): boolean {
    return this.courses.length > 0 || this.exams.length > 0 || this.grades.length > 0 ||
      this.syncState.hasData();
  }

  private unreadChanges(): Array<ChangeEvent> {
    return this.changes.filter((item: ChangeEvent): boolean => !item.acknowledged);
  }

  private changeTargetLabel(target: SyncTarget): string {
    switch (target) {
      case SyncTarget.TIMETABLE: return '课表';
      case SyncTarget.EXAMS: return '考试';
      case SyncTarget.GRADES: return '成绩';
      case SyncTarget.MAIL: return '邮件';
      default: return '学业';
    }
  }

  private startBackgroundRefresh(): void {
    if (this.backgroundRefreshActive) {
      return;
    }
    this.backgroundCoordinator = new SyncCoordinator(
      this.backgroundController,
      (): void => {
      },
      (state: LoginState): void => {
        this.loginState = state;
        if (state === LoginState.LOGGED_IN) {
          this.persistWebSession();
        }
        if (state === LoginState.NOT_LOGGED_IN || state === LoginState.SESSION_EXPIRED) {
          setTimeout(() => {
            this.stopBackgroundRefresh();
          }, 0);
        }
      },
      (status: SyncStatus): void => {
        if (status.phase === SyncPhase.COMPLETED || status.phase === SyncPhase.PARTIAL_SUCCESS) {
          this.persistWebSession();
          this.loadData();
        }
        if (status.phase !== SyncPhase.WAITING_FOR_LOGIN) {
          this.backgroundRefreshActive = false;
        }
      }
    );
    this.backgroundRefreshActive = true;
    this.backgroundCoordinator.start();
  }

  private stopBackgroundRefresh(): void {
    if (this.backgroundCoordinator !== undefined && this.backgroundCoordinator.getStatus().running) {
      this.backgroundCoordinator.cancel();
    }
    this.backgroundRefreshActive = false;
  }

  private persistWebSession(): void {
    try {
      webview.WebCookieManager.saveCookieSync();
    } catch (_) {
      // 没有活动 ArkWeb 会话时保持本地数据流程正常。
    }
  }

  private currentWeek(): number {
    const maximum: number = this.maxAvailableWeek();
    const calculated: number = AcademicCalendar.teachingWeek(
      this.semester.termCode,
      this.semester.termLabel,
      new Date(),
      this.semester.startDate,
      maximum
    );
    if (calculated > 0) {
      return calculated;
    }
    if (this.semester.startDate.length > 0 ||
        AcademicCalendar.knownStartDate(this.semester.termCode, this.semester.termLabel).length > 0) {
      return 0;
    }
    if (this.semester.currentTeachingWeek >= 1 &&
        this.semester.currentTeachingWeek <= maximum) {
      return this.semester.currentTeachingWeek;
    }
    return 0;
  }

  private maxAvailableWeek(): number {
    const calendarWeeks: number =
      AcademicCalendar.knownTotalWeeks(this.semester.termCode, this.semester.termLabel);
    let maximum: number = calendarWeeks > 0 ? calendarWeeks :
      (this.semester.totalWeeks > 0 ? this.semester.totalWeeks : 20);
    for (let i = 0; i < this.courses.length; i++) {
      for (let j = 0; j < this.courses[i].sessions.length; j++) {
        if (this.courses[i].sessions[j].endWeek > maximum) {
          maximum = this.courses[i].sessions[j].endWeek;
        }
      }
    }
    return Math.min(Math.max(maximum, 1), 30);
  }

  private todayCourseCount(): number {
    const day: number = new Date().getDay() === 0 ? 7 : new Date().getDay();
    const week: number = this.currentWeek();
    if (week <= 0) {
      return 0;
    }
    let count: number = 0;
    for (let i = 0; i < this.courses.length; i++) {
      const course: CourseInfo = this.courses[i];
      if (course.sessions.find((session: CourseSession): boolean =>
        session.dayOfWeek === day && session.containsWeek(week)) !== undefined) {
        count++;
      }
    }
    return count;
  }

  private nextCourseText(): string {
    const now: Date = new Date();
    const day: number = now.getDay() === 0 ? 7 : now.getDay();
    const week: number = this.currentWeek();
    if (week <= 0) {
      return '非教学周';
    }
    const maximum: number = this.maxAvailableWeek();
    const nowMinutes: number = now.getHours() * 60 + now.getMinutes();
    for (let offset = 0; offset < 8; offset++) {
      const targetDay: number = ((day - 1 + offset) % 7) + 1;
      const targetWeek: number = week + Math.floor((day - 1 + offset) / 7);
      if (targetWeek > maximum) {
        continue;
      }
      let bestCourse: CourseInfo | undefined = undefined;
      let bestSession: CourseSession | undefined = undefined;
      let bestMinutes: number = 24 * 60;
      for (let i = 0; i < this.courses.length; i++) {
        const course: CourseInfo = this.courses[i];
        for (let j = 0; j < course.sessions.length; j++) {
          const session: CourseSession = course.sessions[j];
          if (session.dayOfWeek !== targetDay || !session.containsWeek(targetWeek)) {
            continue;
          }
          const startMinutes: number = this.sessionStartMinutes(session);
          if (offset === 0 && startMinutes <= nowMinutes) {
            continue;
          }
          if (startMinutes < bestMinutes) {
            bestMinutes = startMinutes;
            bestCourse = course;
            bestSession = session;
          }
        }
      }
      if (bestCourse !== undefined && bestSession !== undefined) {
        const prefix: string = offset === 0 ? '' : (offset === 1 ? '明天 ' : '周' + this.weekdayName(targetDay) + ' ');
        return prefix + bestCourse.name + ' 第' + bestSession.startPeriod + '节';
      }
    }
    return '暂无';
  }

  private nextExamText(): string {
    const best: ExamInfo | undefined = ExamTimeline.nextUpcoming(this.exams);
    if (best === undefined) {
      return '暂无';
    }
    const structured: string = (best.examDate + ' ' + best.examTime).trim();
    const schedule: string = structured.length > 0 ? structured : best.scheduleText;
    return best.courseName + (schedule.length > 0 ? ' ' + schedule : '');
  }

  private recentGradeText(): string {
    if (this.grades.length === 0) {
      return '暂无';
    }
    let latest: GradeInfo = this.grades[0];
    for (let i = 1; i < this.grades.length; i++) {
      if (this.grades[i].syncedAt > latest.syncedAt) {
        latest = this.grades[i];
      }
    }
    return latest.getDisplayCourseName() + ' ' + latest.score;
  }

  private sessionStartMinutes(session: CourseSession): number {
    const match: RegExpMatchArray | null = session.timeRange.match(new RegExp('(\\d{1,2}):(\\d{2})'));
    if (match !== null && match.length >= 3) {
      return parseInt(match[1]) * 60 + parseInt(match[2]);
    }
    return session.startPeriod * 60 + 7 * 60;
  }

  private weekdayName(day: number): string {
    const names: Array<string> = ['一', '二', '三', '四', '五', '六', '日'];
    return names[day - 1] ?? '';
  }

}
