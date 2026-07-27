import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { Theme } from '../common/Theme';

const DAY_LABELS: Array<string> = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const PERIOD_TIMES: Array<string> = [
  '08:00-09:50',
  '10:10-12:00',
  '12:10-14:00',
  '14:10-16:00',
  '16:20-18:10',
  '19:00-20:50',
  '21:00-21:50'
];
const PERIOD_LABEL_WIDTH: number = 56;
const PERIOD_ROW_HEIGHT: number = 82;

@Component
export struct ScheduleGrid {
  @Prop courses: Array<CourseInfo> = [];
  @Prop currentWeek: number = 1;
  onCourseTap: (courseId: string) => void = (id: string) => {};

  build() {
    Column() {
      this.DayHeader()
      List({ space: 0 }) {
        ForEach(Array.from({ length: this.periodCount() }, (_: Object, i: number): number => i + 1),
          (period: number) => {
            ListItem() {
              this.PeriodRow(period)
            }
          }, (_: number, i: number): string => 'p_' + i)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }.width('100%').layoutWeight(1)
  }

  @Builder DayHeader(): void {
    Row() {
      Text('节次').fontSize(10).fontWeight(FontWeight.Medium).fontColor(Theme.textSecondary())
        .width(PERIOD_LABEL_WIDTH).height(38).textAlign(TextAlign.Center)
      ForEach(DAY_LABELS, (label: string, i: number) => {
        Text(label).fontSize(11).fontWeight(FontWeight.Medium)
          .fontColor(this.isToday(i + 1) ? Theme.primary() : Theme.textSecondary())
          .layoutWeight(1).height(32).textAlign(TextAlign.Center).borderRadius(9)
          .backgroundColor(this.isToday(i + 1) ? Theme.primaryLight() : Color.Transparent)
      }, (_: string, i: number): string => 'dh_' + i)
    }
    .width('100%')
    .height(40)
    .padding({ left: 4, right: 4 })
    .backgroundColor(Theme.background())
  }

  @Builder PeriodRow(period: number): void {
    Row() {
      Column() {
        Text('第' + period + '节').fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary())
        Text(this.periodStartTime(period)).fontSize(8).fontColor(Theme.textSecondary())
          .margin({ top: 5 })
        Text(this.periodEndTime(period)).fontSize(8).fontColor(Theme.textSecondary())
          .margin({ top: 1 })
      }
      .width(PERIOD_LABEL_WIDTH)
      .height(PERIOD_ROW_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Theme.surface())
      ForEach(DAY_LABELS, (_: string, dayIndex: number) => {
        Column() {
          ForEach(this.getCoursesStartingAt(dayIndex + 1, period), (course: CourseInfo) => {
            Column() {
              Text(course.name).fontSize(this.getCoursesStartingAt(dayIndex + 1, period).length > 1 ? 8 : 9)
                .fontWeight(FontWeight.Bold).fontColor(Theme.courseText())
                .width('100%')
                .maxLines(this.getCoursesStartingAt(dayIndex + 1, period).length > 1 ? 2 : 3)
                .textAlign(TextAlign.Center)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.getCoursesStartingAt(dayIndex + 1, period).length === 1 &&
                  this.getLocationAt(course, dayIndex + 1, period).length > 0) {
                Text(this.getLocationAt(course, dayIndex + 1, period))
                  .fontSize(7).fontColor(Theme.courseText()).opacity(0.72).width('100%').maxLines(1)
                  .textAlign(TextAlign.Center)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
              }
            }
            .width('100%').layoutWeight(1).borderRadius(8).padding({ left: 2, right: 2, top: 4, bottom: 4 })
            .backgroundColor(Theme.course(course.courseType, course.id + course.name))
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .onClick(() => { this.onCourseTap(course.id); })
          }, (_: CourseInfo, ci: number): string => 'cc_' + dayIndex + '_' + period + '_' + ci)
        }
        .layoutWeight(1)
        .height(PERIOD_ROW_HEIGHT)
        .borderWidth(0.5)
        .borderColor(Theme.border())
        .backgroundColor(this.isToday(dayIndex + 1) ? Theme.primaryLight() : Color.Transparent)
        .padding(2)
      }, (_: string, i: number): string => 'dc_' + i)
    }.width('100%').height(PERIOD_ROW_HEIGHT).padding({ left: 4, right: 4 })
  }

  private getCoursesStartingAt(day: number, period: number): Array<CourseInfo> {
    const r: Array<CourseInfo> = [];
    for (let i = 0; i < this.courses.length; i++) {
      const c: CourseInfo = this.courses[i];
      for (let j = 0; j < c.sessions.length; j++) {
        const s: CourseSession = c.sessions[j];
        if (s.dayOfWeek === day && s.startPeriod === period && s.containsWeek(this.currentWeek)) {
          r.push(c); break;
        }
      }
    }
    return r;
  }

  private getLocationAt(course: CourseInfo, day: number, period: number): string {
    const session: CourseSession | undefined = course.sessions.find((item: CourseSession): boolean =>
      item.dayOfWeek === day && item.startPeriod === period && item.containsWeek(this.currentWeek));
    return session !== undefined ? session.classroom : '';
  }

  private periodCount(): number {
    let maximum: number = 1;
    for (let i = 0; i < this.courses.length; i++) {
      for (let j = 0; j < this.courses[i].sessions.length; j++) {
        if (this.courses[i].sessions[j].endPeriod > maximum) {
          maximum = this.courses[i].sessions[j].endPeriod;
        }
      }
    }
    return Math.max(maximum, PERIOD_TIMES.length);
  }

  private periodTime(period: number): string {
    for (let i = 0; i < this.courses.length; i++) {
      for (let j = 0; j < this.courses[i].sessions.length; j++) {
        const session: CourseSession = this.courses[i].sessions[j];
        if (session.startPeriod === period && session.timeRange.length > 0 &&
            session.timeRange.match(new RegExp('\\d{1,2}:\\d{2}\\s*[-~—–至]\\s*\\d{1,2}:\\d{2}')) !== null) {
          return session.timeRange.replace(new RegExp('[~—–至]'), '-').replace(new RegExp('\\s', 'g'), '');
        }
      }
    }
    return PERIOD_TIMES[period - 1] ?? '';
  }

  private periodStartTime(period: number): string {
    const parts: Array<string> = this.periodTime(period).split('-');
    return parts.length > 0 ? parts[0] : '';
  }

  private periodEndTime(period: number): string {
    const parts: Array<string> = this.periodTime(period).split('-');
    return parts.length > 1 ? parts[1] : '';
  }

  private isToday(day: number): boolean {
    const td: number = new Date().getDay();
    return (td === 0 ? 7 : td) === day;
  }

}
