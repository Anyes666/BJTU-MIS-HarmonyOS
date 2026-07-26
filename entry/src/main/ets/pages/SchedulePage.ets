import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { SyncState } from '../model/SyncState';
import { LoginState } from '../model/LoginState';
import { ScheduleGrid } from '../components/ScheduleGrid';
import { Theme } from '../common/Theme';
import { AcademicCalendar, AcademicWeekRange } from '../model/AcademicCalendar';

@Component
export struct ScheduleView {
  @Watch('onDataRevisionChanged') @Prop dataRevision: number = 0;
  @Watch('onActiveChanged') @Prop isActive: boolean = false;
  @State currentView: number = 0;
  @State courses: Array<CourseInfo> = [];
  @State syncState: SyncState = new SyncState();
  @State semester: SemesterInfo = new SemesterInfo();
  @State selectedWeek: number = 1;
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  private onDataRevisionChanged(): void {
    this.loadData();
  }

  private onActiveChanged(): void {
    if (this.isActive) {
      this.loadData();
    }
  }

  loadData(): void {
    this.dataStore.resolveUnknownCourseTerms();
    this.syncState = this.dataStore.loadSyncState();
    this.semester = this.dataStore.loadSemester();
    this.courses = CourseInfo.filterByTerm(
      this.dataStore.loadCourses(),
      this.semester.termCode,
      this.semester.termLabel
    );
    const currentWeek: number = this.effectiveCurrentWeek();
    this.selectedWeek = this.clampWeek(currentWeek > 0 ? currentWeek : 1);
  }

  build() {
    Column() {
      this.ViewSwitcher()
      if (this.courses.length > 0) { this.CurrentTermSummary() }
      if (this.courses.length === 0) { this.EmptyView() }
      else if (this.currentView === 0) { this.WeekScheduleView() }
      else { this.TodayScheduleView() }
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }

  @Builder ViewSwitcher(): void {
    Row({ space: 4 }) {
      this.ViewTab('周课表', 0)
      this.ViewTab('今日课程', 1)
    }
    .width('calc(100% - 32vp)')
    .height(44)
    .padding(4)
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .margin({ left: 16, right: 16, top: 18, bottom: 10 })
  }

  @Builder ViewTab(label: string, index: number): void {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentView === index ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.currentView === index ? Theme.primary() : Theme.textSecondary())
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(36)
      .borderRadius(10)
      .backgroundColor(this.currentView === index ? Theme.card() : Color.Transparent)
      .onClick(() => { this.currentView = index; })
  }

  @Builder CurrentTermSummary(): void {
    Row() {
      Text('本学期').fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(Theme.textSecondary()).margin({ right: 8 })
      Text(this.currentTermLabel())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .layoutWeight(1)
      Text(this.courses.length.toString() + ' 门')
        .fontSize(11).fontWeight(FontWeight.Medium).fontColor(Theme.primary())
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(10).backgroundColor(Theme.primaryLight()).margin({ left: 8 })
    }
    .width('calc(100% - 32vp)')
    .height(50)
    .padding({ left: 12, right: 8 })
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder EmptyView(): void {
    Column() {
      Text('暂无本学期课表').fontSize(16).fontColor(Theme.textDisabled())
      Text('同步后仅展示教务系统“本学期课表”')
        .fontSize(13).fontColor(Theme.textDisabled()).margin({ top: 8 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder WeekScheduleView(): void {
    Column() {
      Row() {
        Button('‹')
          .fontSize(22).width(36).height(36).borderRadius(18)
          .enabled(this.selectedWeek > 1)
          .backgroundColor(Theme.primaryLight())
          .fontColor(this.selectedWeek > 1 ? Theme.primary() : Theme.textDisabled())
          .onClick(() => { this.selectedWeek = this.clampWeek(this.selectedWeek - 1); })
        Column() {
          Text('第 ' + this.selectedWeek + ' 周')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.textPrimary())
          Text(this.weekDateRange(this.selectedWeek))
            .fontSize(11).fontColor(Theme.textSecondary()).margin({ top: 2 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Button('›')
          .fontSize(22).width(36).height(36).borderRadius(18)
          .enabled(this.selectedWeek < this.maxAvailableWeek())
          .backgroundColor(Theme.primaryLight())
          .fontColor(this.selectedWeek < this.maxAvailableWeek() ? Theme.primary() : Theme.textDisabled())
          .onClick(() => { this.selectedWeek = this.clampWeek(this.selectedWeek + 1); })
      }
      .width('calc(100% - 24vp)')
      .height(58)
      .padding({ left: 10, right: 10 })
      .borderRadius(14)
      .backgroundColor(Theme.surface())
      .margin({ left: 12, right: 12, bottom: 8 })
      if (this.effectiveCurrentWeek() > 0 &&
          this.selectedWeek !== this.effectiveCurrentWeek()) {
        Button('回到本周')
          .fontSize(11).height(30).backgroundColor(Theme.secondary()).margin({ bottom: 4 })
          .onClick(() => { this.selectedWeek = this.effectiveCurrentWeek(); })
      }
      ScheduleGrid({
        courses: this.courses, currentWeek: this.selectedWeek,
        onCourseTap: (courseId: string): void => {
          const params: Record<string, string> = { 'courseId': courseId };
          this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseDetailPage', params: params });
        }
      })
    }.width('100%').layoutWeight(1)
  }

  @Builder TodayScheduleView(): void {
    Scroll() {
      Column() {
        Text(this.getTodayLabel()).fontSize(14).fontColor(Theme.textSecondary())
          .margin({ left: 16, top: 8, bottom: 12 }).alignSelf(ItemAlign.Start)
        if (this.getTodayCourses().length === 0) {
          Column() {
            Text('今日无课').fontSize(18).fontColor(Theme.success())
            Text('好好休息一下吧').fontSize(13).fontColor(Theme.textDisabled()).margin({ top: 4 })
          }.width('100%').padding(40).alignItems(HorizontalAlign.Center)
        } else {
          ForEach(this.getTodayCourses(), (course: CourseInfo) => { this.TodayCourseCard(course) },
            (_: CourseInfo, i: number): string => 'today_' + i)
        }
      }.width('100%').padding({ left: 16, right: 16 }).alignItems(HorizontalAlign.Center)
    }.width('100%').layoutWeight(1)
  }

  @Builder TodayCourseCard(course: CourseInfo): void {
    Column() {
      ForEach(course.sessions, (session: CourseSession) => {
        if (this.isSessionToday(session)) {
          Column() {
            Row() {
              Column() {
                Text(course.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
                if (course.teacher.length > 0) {
                  Text(course.teacher).fontSize(12).fontColor(Theme.textSecondary()).margin({ top: 2 })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text('第' + session.startPeriod + '-' + session.endPeriod + '节')
                .fontSize(12).fontColor(Theme.primary())
            }.width('100%')
            Row() {
              Text(session.classroom).fontSize(12).fontColor(Theme.textSecondary())
              if (session.campus.length > 0) {
                Text(session.campus).fontSize(11).fontColor(Theme.textDisabled()).margin({ left: 8 })
              }
            }.width('100%').margin({ top: 6 })
          }.width('100%').padding(12).borderRadius(10)
           .backgroundColor(Theme.surface()).margin({ bottom: 8 })
        }
      }, (_: CourseSession, i: number): string => 'card_' + course.id + '_' + i)
    }.width('100%')
  }

  private getTodayCourses(): Array<CourseInfo> {
    const today: Date = new Date(); const todayDay: number = today.getDay();
    const dayOfWeek: number = todayDay === 0 ? 7 : todayDay;
    const currentWeek: number = this.selectedWeek;
    const result: Array<CourseInfo> = [];
    for (let i = 0; i < this.courses.length; i++) {
      const course: CourseInfo = this.courses[i];
      for (let j = 0; j < course.sessions.length; j++) {
        if (course.sessions[j].dayOfWeek === dayOfWeek && course.sessions[j].containsWeek(currentWeek)) {
          if (result.find((c: CourseInfo): boolean => c.id === course.id) === undefined) { result.push(course); }
          break;
        }
      }
    }
    result.sort((a: CourseInfo, b: CourseInfo): number => {
      const ap: number = a.sessions.length > 0 ? a.sessions[0].startPeriod : 99;
      const bp: number = b.sessions.length > 0 ? b.sessions[0].startPeriod : 99;
      return ap - bp;
    });
    return result;
  }

  private isSessionToday(session: CourseSession): boolean {
    const today: Date = new Date(); const td: number = today.getDay();
    const dow: number = td === 0 ? 7 : td;
    return session.dayOfWeek === dow && session.containsWeek(this.selectedWeek);
  }

  private getTodayLabel(): string {
    const today: Date = new Date();
    const dn: Array<string> = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return this.currentTermLabel() + ' 第' + this.selectedWeek + '周 · ' +
      dn[today.getDay()] + ' ' + (today.getMonth() + 1) + '月' + today.getDate() + '日';
  }

  private effectiveCurrentWeek(): number {
    const maximum: number = this.maxAvailableWeek();
    const calculated: number = AcademicCalendar.teachingWeek(
      this.semester.termCode, this.currentTermLabel(), new Date(),
      this.semester.startDate, maximum
    );
    if (calculated > 0) {
      return calculated;
    }
    if (this.semester.startDate.length > 0 ||
        AcademicCalendar.knownStartDate(this.semester.termCode, this.currentTermLabel()).length > 0) {
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
      AcademicCalendar.knownTotalWeeks(this.semester.termCode, this.currentTermLabel());
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

  private clampWeek(week: number): number {
    if (week < 1) {
      return 1;
    }
    const maximum: number = this.maxAvailableWeek();
    return week > maximum ? maximum : week;
  }

  private weekDateRange(week: number): string {
    const range: AcademicWeekRange | undefined = AcademicCalendar.weekRange(
      this.semester.termCode, this.currentTermLabel(), week, this.semester.startDate
    );
    if (range === undefined) {
      return '可查看第 1-' + this.maxAvailableWeek() + ' 周';
    }
    return this.monthDay(range.start) + ' - ' + this.monthDay(range.end);
  }

  private monthDay(date: Date): string {
    return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日';
  }

  private currentTermLabel(): string {
    if (this.semester.termLabel.length > 0) {
      return this.semester.termLabel;
    }
    if (this.semester.termCode.length > 0 && this.semester.termCode !== 'UNKNOWN_TERM') {
      return this.semester.termCode;
    }
    return '本学期';
  }
}
