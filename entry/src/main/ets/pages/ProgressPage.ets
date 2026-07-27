import { AcademicProgress, ProfileField, ProgressCourse } from '../model/CampusInfo';
import { GradeInfo } from '../model/GradeInfo';
import { GradeMetrics } from '../model/GradeMetrics';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';

@Entry({ routeName: 'ProgressPage' })
@Component
struct ProgressPage {
  @State progress: AcademicProgress = new AcademicProgress();
  @State grades: Array<GradeInfo> = [];
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.progress = this.dataStore.loadProgress();
    this.grades = this.dataStore.loadGrades();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
      this.TopBar()
      Scroll() {
        Column() {
          this.CreditCard()
          if (this.attentionCourses().length > 0) {
            this.AttentionCard()
          }
          if (this.progress.fields.length > 0) {
            this.OfficialFieldsCard()
          }
          Text(this.progress.officialSummary ?
            '汇总来自学校官方培养页面' : '本地计算，仅供参考；不代表毕业或培养完成结论')
            .fontSize(11)
            .fontColor(this.progress.officialSummary ? Theme.textDisabled() : Theme.warning())
            .width('100%')
            .padding(12)
            .borderRadius(10)
            .backgroundColor(Theme.card())
            .backgroundBlurStyle(Theme.blurStyle())
            .margin({ top: 12, bottom: 32 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
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
      Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Text('学业进度').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .layoutWeight(1).textAlign(TextAlign.Center)
      Row() {}.width(60)
    }.width('100%').height(52).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
  }

  @Builder
  CreditCard(): void {
    Column() {
      Text('学分进度').fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary()).alignSelf(ItemAlign.Start)
      Row() {
        this.Metric('已获得学分', this.earnedCreditsText())
        Divider().vertical(true).height(44).color(Theme.border())
        this.Metric('培养要求学分', this.requiredCreditsText())
      }.width('100%').margin({ top: 14 })
      if (!this.progress.hasData() && this.grades.length === 0) {
        Text('暂无可计算数据，请先同步个人培养信息和历年成绩')
          .fontSize(12).fontColor(Theme.textSecondary()).margin({ top: 14 })
      }
    }
    .width('100%')
    .padding(18)
    .margin({ top: 12, bottom: 12 })
    .borderRadius(14)
    .backgroundColor(Theme.surface())
  }

  @Builder
  Metric(label: string, value: string): void {
    Column() {
      Text(label).fontSize(12).fontColor(Theme.textSecondary())
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.textPrimary()).margin({ top: 6 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder
  AttentionCard(): void {
    Column() {
      Text('需关注课程')
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
      ForEach(this.attentionCourses(), (course: ProgressCourse) => {
        Row() {
          Column() {
            Text(course.courseName).fontSize(14).fontColor(Theme.textPrimary())
            if (course.category.length > 0) {
              Text(course.category).fontSize(11).fontColor(Theme.textDisabled()).margin({ top: 3 })
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(course.status.length > 0 ? course.status : course.score)
            .fontSize(12).fontColor(Theme.warning()).margin({ left: 10 })
        }.width('100%').padding({ top: 8, bottom: 8 })
      }, (course: ProgressCourse, index: number): string => course.courseName + '_' + index)
    }.width('100%').padding(16).borderRadius(12).backgroundColor(Theme.surface()).margin({ bottom: 12 })
  }

  @Builder
  OfficialFieldsCard(): void {
    Column() {
      Text('培养信息')
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
      ForEach(this.progress.fields.slice(0, 30), (field: ProfileField) => {
        Row() {
          Text(field.label).fontSize(12).fontColor(Theme.textSecondary()).width(120)
          Text(field.value).fontSize(12).fontColor(Theme.textPrimary()).layoutWeight(1)
        }.width('100%').padding({ top: 6, bottom: 6 })
      }, (field: ProfileField, index: number): string => field.label + '_' + index)
    }.width('100%').padding(16).borderRadius(12).backgroundColor(Theme.surface())
  }

  private earnedCreditsText(): string {
    if (this.progress.earnedCredits >= 0) {
      return this.progress.earnedCredits.toFixed(1);
    }
    const credits: number = this.localEarnedCredits();
    return credits > 0 ? credits.toFixed(1) : '--';
  }

  private requiredCreditsText(): string {
    return this.progress.requiredCredits >= 0 ? this.progress.requiredCredits.toFixed(1) : '--';
  }

  private localEarnedCredits(): number {
    let result: number = 0;
    const keys: Array<string> = [];
    for (let i = 0; i < this.grades.length; i++) {
      const grade: GradeInfo = this.grades[i];
      const key: string = grade.getListDedupeKey();
      if (keys.find((item: string): boolean => item === key) !== undefined) {
        continue;
      }
      const credit: number = Number(grade.credit);
      const score: number = GradeMetrics.scoreValue(grade.score);
      const qualitativePass: boolean =
        grade.score.includes('合格') || grade.score.includes('通过') || grade.score.includes('优秀');
      if (isFinite(credit) && credit > 0 && (score >= 60 || qualitativePass)) {
        result += credit;
        keys.push(key);
      }
    }
    return result;
  }

  private attentionCourses(): Array<ProgressCourse> {
    const result: Array<ProgressCourse> = this.progress.courses.filter(
      (course: ProgressCourse): boolean => course.needsAttention());
    if (result.length > 0) {
      return result;
    }
    for (let i = 0; i < this.grades.length; i++) {
      const score: number = GradeMetrics.scoreValue(this.grades[i].score);
      if (score >= 0 && score < 60) {
        const course: ProgressCourse = new ProgressCourse();
        course.courseName = this.grades[i].courseName;
        course.score = this.grades[i].score;
        course.status = '未通过';
        course.category = '本地成绩判断';
        result.push(course);
      }
    }
    return result;
  }
}
