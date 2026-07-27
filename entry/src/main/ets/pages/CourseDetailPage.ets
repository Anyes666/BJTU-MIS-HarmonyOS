import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';

@Entry({ routeName: 'CourseDetailPage' })
@Component
struct CourseDetailPage {
  @State course: CourseInfo = new CourseInfo();
  @State notFound: boolean = false;
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    const params: Object = this.getUIContext().getRouter().getParams();
    if (params !== undefined) {
      const typed: Record<string, Object> = params as Record<string, Object>;
      const courseId: string = (typed['courseId'] as string) ?? '';
      const courses: Array<CourseInfo> = this.dataStore.loadCourses();
      for (let i = 0; i < courses.length; i++) { if (courses[i].id === courseId) { this.course = courses[i]; return; } }
      this.notFound = true;
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
        Row() {
          Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
            .onClick(() => { this.getUIContext().getRouter().back(); })
          Text('课程详情').fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary()).layoutWeight(1).textAlign(TextAlign.Center)
          Row(){}.width(60).height(44)
        }.width('100%').height(44).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
        if (this.notFound) {
          Text('课程未找到')
            .fontSize(16)
            .fontColor(Theme.textDisabled())
            .padding(18)
            .borderRadius(12)
            .backgroundColor(Theme.surface())
            .backgroundBlurStyle(Theme.blurStyle())
            .margin({ top: 100 })
        }
        else { this.CourseDetailContent() }
        }.width('100%').height('100%').backgroundColor(Theme.background())
      }
    }.width('100%').height('100%')
  }

  @Builder CourseDetailContent(): void {
    Scroll() {
      Column() {
        this.CourseSummaryCard()
        Text('上课安排')
          .fontSize(14)
          .fontColor(Theme.textSecondary())
          .width('100%')
          .padding(10)
          .borderRadius(10)
          .backgroundColor(Theme.card())
          .backgroundBlurStyle(Theme.blurStyle())
          .margin({ top: 12, bottom: 8 })
        ForEach(this.course.sessions, (session: CourseSession) => { this.SCard(session) },
          (_: CourseSession, i: number): string => 'dets_' + i)
        Text('更新时间: ' + new Date(this.course.updateTime).toLocaleString())
          .fontSize(11)
          .fontColor(Theme.textDisabled())
          .width('100%')
          .padding(10)
          .borderRadius(10)
          .backgroundColor(Theme.card())
          .backgroundBlurStyle(Theme.blurStyle())
          .margin({ top: 16, bottom: 40 })
          .textAlign(TextAlign.Center)
      }.width('100%').padding({ left: 16, right: 16 }).alignItems(HorizontalAlign.Center)
    }.width('100%').layoutWeight(1)
  }

  @Builder CourseSummaryCard(): void {
    Column() {
      Text(this.course.name)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary())
        .margin({ bottom: 10 })
        .alignSelf(ItemAlign.Center)
      if (this.course.courseCode.length > 0) {
        this.DRow('课程代码', this.course.courseCode)
      }
      this.DRow('教师', this.course.teacher)
      this.DRow('类型', this.course.courseType)
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .backgroundBlurStyle(Theme.blurStyle())
    .margin({ top: 16 })
  }

  @Builder DRow(label: string, value: string): void {
    Row() {
      Text(label).fontSize(14).fontColor(Theme.textSecondary()).width(80)
      Text(value.length > 0 ? value : '暂无').fontSize(14).fontColor(Theme.textPrimary())
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  @Builder SCard(session: CourseSession): void {
    Column() {
      Row() { Text(this.dayLbl(session.dayOfWeek)).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary()) }.width('100%')
      this.SRow('节次', '第' + session.startPeriod + '-' + session.endPeriod + '节')
      this.SRow('周次', this.wkLbl(session))
      this.SRow('教室', session.classroom.length > 0 ? session.classroom : '暂无')
      this.SRow('校区', session.campus.length > 0 ? session.campus : '暂无')
    }.width('100%').padding(12).borderRadius(10).backgroundColor(Theme.surface())
      .backgroundBlurStyle(Theme.blurStyle()).margin({ top: 8 }).alignItems(HorizontalAlign.Start)
  }

  @Builder SRow(label: string, value: string): void {
    Row() { Text(label).fontSize(13).fontColor(Theme.textSecondary()).width(80); Text(value).fontSize(13).fontColor(Theme.textPrimary()) }
      .width('100%').margin({ top: 4 })
  }

  private dayLbl(d: number): string {
    const l: Array<string> = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return (d >= 1 && d <= 7) ? l[d] : '未知';
  }

  private wkLbl(s: CourseSession): string {
    let l: string = '第' + s.startWeek + '-' + s.endWeek + '周';
    if (s.weekType === 'odd') { l += ' (单周)'; }
    else if (s.weekType === 'even') { l += ' (双周)'; }
    if (s.discontinuousWeeks.length > 0) { l += ' [' + s.discontinuousWeeks + ']'; }
    return l;
  }
}
