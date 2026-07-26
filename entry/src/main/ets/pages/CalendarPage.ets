import { AcademicCalendar } from '../model/AcademicCalendar';
import { CalendarEvent, CampusCalendar } from '../model/CampusInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';

class CalendarDay {
  day: number = 0;
  inMonth: boolean = false;
  isToday: boolean = false;
  hasEvent: boolean = false;
}

@Entry({ routeName: 'CalendarPage' })
@Component
struct CalendarPage {
  @State calendar: CampusCalendar = CampusCalendar.published20262027();
  @State semester: SemesterInfo = new SemesterInfo();
  @State displayYear: number = new Date().getFullYear();
  @State displayMonth: number = new Date().getMonth() + 1;
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.calendar = this.dataStore.loadCalendar();
    this.semester = this.dataStore.loadSemester();
  }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column() {
          this.TermCard()
          this.MonthCard()
          this.EventsCard()
          Text(this.calendar.sourceLabel + ' · 离线校历数据')
            .fontSize(10).fontColor(Theme.textDisabled()).margin({ top: 10, bottom: 30 })
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Text('学年校历').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .layoutWeight(1).textAlign(TextAlign.Center)
      Row() {}.width(60)
    }.width('100%').height(52).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
  }

  @Builder
  TermCard(): void {
    Column() {
      Text(this.semester.termLabel.length > 0 ? this.semester.termLabel : this.calendar.academicYear + ' 学年')
        .fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
      Text(this.currentWeekText()).fontSize(13).fontColor(Theme.primary()).margin({ top: 6 })
      Text(this.startDateText()).fontSize(11).fontColor(Theme.textSecondary()).margin({ top: 4 })
    }.width('100%').padding(16).margin({ top: 12, bottom: 12 })
     .borderRadius(12).backgroundColor(Theme.surface()).alignItems(HorizontalAlign.Start)
  }

  @Builder
  MonthCard(): void {
    Column() {
      Row() {
        Button('‹').width(42).height(34).backgroundColor(Color.Transparent).fontColor(Theme.primary())
          .onClick(() => { this.shiftMonth(-1); })
        Text(this.displayYear + '年' + this.displayMonth + '月')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
          .layoutWeight(1).textAlign(TextAlign.Center)
        Button('›').width(42).height(34).backgroundColor(Color.Transparent).fontColor(Theme.primary())
          .onClick(() => { this.shiftMonth(1); })
      }.width('100%')
      Row() {
        ForEach(['一', '二', '三', '四', '五', '六', '日'], (label: string) => {
          Text(label).fontSize(11).fontColor(Theme.textSecondary())
            .width('14.28%').height(28).textAlign(TextAlign.Center)
        })
      }.width('100%').margin({ top: 6 })
      Grid() {
        ForEach(this.monthDays(), (item: CalendarDay, index: number) => {
          GridItem() {
            Stack() {
              if (item.day > 0) {
                Text(item.day.toString())
                  .fontSize(13)
                  .fontColor(item.isToday ? Theme.onPrimary() : Theme.textPrimary())
                  .width(34).height(34).textAlign(TextAlign.Center)
                  .borderRadius(17)
                  .backgroundColor(item.isToday ? Theme.primary() : Color.Transparent)
                if (item.hasEvent) {
                  Text('·').fontSize(18).fontColor(Theme.warning()).margin({ top: 24 })
                }
              }
            }.width('100%').height(42).alignContent(Alignment.Center)
          }
        }, (_: CalendarDay, index: number): string =>
          this.displayYear + '_' + this.displayMonth + '_' + index)
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').width('100%')
    }.width('100%').padding(14).borderRadius(12).backgroundColor(Theme.surface())
  }

  @Builder
  EventsCard(): void {
    Column() {
      Text('本月安排').fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary()).alignSelf(ItemAlign.Start)
      if (this.monthEvents().length === 0) {
        Text('本月暂无已发布校历事项').fontSize(12).fontColor(Theme.textSecondary()).margin({ top: 12 })
      } else {
        ForEach(this.monthEvents(), (event: CalendarEvent) => {
          Row() {
            Text(this.eventDateText(event)).fontSize(12).fontColor(Theme.primary()).width(112)
            Text(event.title).fontSize(13).fontColor(Theme.textPrimary()).layoutWeight(1)
          }.width('100%').padding({ top: 9, bottom: 9 })
        }, (event: CalendarEvent, index: number): string => event.title + '_' + index)
      }
    }.width('100%').padding(16).margin({ top: 12 }).borderRadius(12).backgroundColor(Theme.surface())
  }

  private monthDays(): Array<CalendarDay> {
    const result: Array<CalendarDay> = [];
    const first: Date = new Date(this.displayYear, this.displayMonth - 1, 1);
    const leading: number = first.getDay() === 0 ? 6 : first.getDay() - 1;
    const total: number = new Date(this.displayYear, this.displayMonth, 0).getDate();
    const today: Date = new Date();
    for (let i = 0; i < leading; i++) {
      result.push(new CalendarDay());
    }
    for (let day = 1; day <= total; day++) {
      const item: CalendarDay = new CalendarDay();
      item.day = day;
      item.inMonth = true;
      item.isToday = today.getFullYear() === this.displayYear &&
        today.getMonth() + 1 === this.displayMonth && today.getDate() === day;
      const dateText: string = this.dateText(this.displayYear, this.displayMonth, day);
      item.hasEvent = this.calendar.events.find((event: CalendarEvent): boolean =>
        event.startDate === dateText || event.endDate === dateText) !== undefined;
      result.push(item);
    }
    while (result.length % 7 !== 0) {
      result.push(new CalendarDay());
    }
    return result;
  }

  private monthEvents(): Array<CalendarEvent> {
    const prefix: string = this.displayYear + '-' + (this.displayMonth < 10 ? '0' : '') + this.displayMonth;
    return this.calendar.events.filter((event: CalendarEvent): boolean =>
      event.startDate.startsWith(prefix) || event.endDate.startsWith(prefix));
  }

  private currentWeekText(): string {
    const maximum: number = AcademicCalendar.knownTotalWeeks(this.semester.termCode, this.semester.termLabel);
    const week: number = AcademicCalendar.teachingWeek(
      this.semester.termCode, this.semester.termLabel, new Date(), this.semester.startDate, maximum
    );
    return week > 0 ? '当前第 ' + week + ' 教学周' : '当前不在已知教学周内';
  }

  private startDateText(): string {
    const start: string = this.semester.startDate.length > 0 ? this.semester.startDate :
      AcademicCalendar.knownStartDate(this.semester.termCode, this.semester.termLabel);
    return start.length > 0 ? '开学日期 ' + start : '尚未取得该学期官方开学日期';
  }

  private shiftMonth(offset: number): void {
    let month: number = this.displayMonth + offset;
    let year: number = this.displayYear;
    if (month < 1) {
      month = 12;
      year--;
    } else if (month > 12) {
      month = 1;
      year++;
    }
    this.displayYear = year;
    this.displayMonth = month;
  }

  private dateText(year: number, month: number, day: number): string {
    return year + '-' + (month < 10 ? '0' : '') + month + '-' + (day < 10 ? '0' : '') + day;
  }

  private eventDateText(event: CalendarEvent): string {
    return event.startDate === event.endDate ? event.startDate : event.startDate + ' 至 ' + event.endDate;
  }
}
