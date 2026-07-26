import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { Theme } from '../common/Theme';

const DAY_LABELS: Array<string> = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

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
      Text('节').fontSize(9).fontColor(Theme.textDisabled())
        .width(30).height(36).textAlign(TextAlign.Center)
      ForEach(DAY_LABELS, (label: string, i: number) => {
        Text(label).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.isToday(i + 1) ? Theme.primary() : Theme.textSecondary())
          .layoutWeight(1).height(32).textAlign(TextAlign.Center).borderRadius(8)
          .backgroundColor(this.isToday(i + 1) ? Theme.primaryLight() : Color.Transparent)
      }, (_: string, i: number): string => 'dh_' + i)
    }
    .width('100%')
    .height(36)
    .padding({ left: 2, right: 2 })
    .backgroundColor(Theme.background())
  }

  @Builder PeriodRow(period: number): void {
    Row() {
      Text(period.toString()).fontSize(11).fontWeight(FontWeight.Medium)
        .fontColor(Theme.textSecondary()).width(30).height(68).textAlign(TextAlign.Center)
      ForEach(DAY_LABELS, (_: string, dayIndex: number) => {
        Column() {
          ForEach(this.getCoursesStartingAt(dayIndex + 1, period), (course: CourseInfo) => {
            Column() {
              Text(course.name).fontSize(this.getCoursesStartingAt(dayIndex + 1, period).length > 1 ? 8 : 10)
                .fontWeight(FontWeight.Medium).fontColor(Theme.onPrimary())
                .width('100%')
                .maxLines(this.getCoursesStartingAt(dayIndex + 1, period).length > 1 ? 2 : 3)
                .textAlign(TextAlign.Start)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.getCoursesStartingAt(dayIndex + 1, period).length === 1 &&
                  this.getLocationAt(course, dayIndex + 1, period).length > 0) {
                Text(this.getLocationAt(course, dayIndex + 1, period))
                  .fontSize(8).fontColor(Theme.onPrimary()).opacity(0.8).width('100%').maxLines(1)
                  .textAlign(TextAlign.Start)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
              }
            }
            .width('100%').layoutWeight(1).borderRadius(7).padding(4)
            .backgroundColor(Theme.course(course.courseType, course.id + course.name))
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
            .onClick(() => { this.onCourseTap(course.id); })
          }, (_: CourseInfo, ci: number): string => 'cc_' + dayIndex + '_' + period + '_' + ci)
        }
        .layoutWeight(1)
        .height(68)
        .borderWidth(0.5)
        .borderColor(Theme.border())
        .backgroundColor(this.isToday(dayIndex + 1) ? Theme.primaryLight() : Color.Transparent)
        .padding(2)
      }, (_: string, i: number): string => 'dc_' + i)
    }.width('100%').height(68)
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
    return Math.max(maximum, 1);
  }

  private isToday(day: number): boolean {
    const td: number = new Date().getDay();
    return (td === 0 ? 7 : td) === day;
  }

}
