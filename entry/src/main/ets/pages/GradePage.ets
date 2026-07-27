import { GradeInfo, GradeTermOption, GradeTermOrder } from '../model/GradeInfo';
import { GradeMetrics, GradeMetricsResult } from '../model/GradeMetrics';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';

class GradeTermFilter {
  code: string = '';
  label: string = '';
}

@Component
export struct GradeView {
  @Watch('onDataRevisionChanged') @Prop dataRevision: number = 0;
  @Watch('onActiveChanged') @Prop isActive: boolean = false;
  @State grades: Array<GradeInfo> = [];
  @State gradeTerms: Array<GradeTermOption> = [];
  @State selectedTermCode: string = '';
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

  private loadData(): void {
    this.grades = this.dataStore.loadGrades();
    this.gradeTerms = this.dataStore.loadGradeTerms();
    const terms: Array<GradeTermFilter> = this.termFilters();
    if (terms.length > 0 &&
        terms.find((term: GradeTermFilter): boolean => term.code === this.selectedTermCode) === undefined) {
      const selected: GradeTermOption | undefined =
        this.gradeTerms.find((term: GradeTermOption): boolean => term.selected);
      this.selectedTermCode = selected !== undefined &&
        terms.find((term: GradeTermFilter): boolean => term.code === selected.termCode) !== undefined ?
        selected.termCode : terms[0].code;
    }
  }

  build() {
    Column() {
      Text('历年成绩')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary())
        .margin({ top: 56, bottom: 12 })
      if (this.grades.length === 0) {
        Column() {
          Text('暂无成绩数据').fontSize(17).fontColor(Theme.textPrimary())
          Text('登录后将按学期低频同步并保存在本地')
            .fontSize(12)
            .fontColor(Theme.textSecondary())
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Row() {
          Text('学期').fontSize(13).fontColor(Theme.textSecondary()).margin({ right: 10 })
          Select(this.termSelectOptions())
            .selected(this.selectedTermIndex())
            .value(this.selectedTermLabel())
            .backgroundColor(Theme.surface())
            .backgroundBlurStyle(Theme.blurStyle())
            .layoutWeight(1)
            .onSelect((index: number) => {
              const terms: Array<GradeTermFilter> = this.termFilters();
              if (index >= 0 && index < terms.length) {
                this.selectedTermCode = terms[index].code;
              }
            })
          Text(this.filteredGrades().length.toString() + ' 门')
            .fontSize(12).fontColor(Theme.textSecondary()).margin({ left: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        this.OverallMetricsCard()
        List({ space: 8 }) {
          ForEach(this.filteredGrades(), (grade: GradeInfo) => {
            ListItem() {
              this.GradeCard(grade)
            }
          }, (grade: GradeInfo): string => grade.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background())
  }

  @Builder
  OverallMetricsCard(): void {
    Column() {
      Row() {
        Column() {
          Text('累计加权平均成绩')
            .fontSize(13)
            .fontColor(Theme.textSecondary())
          Text(this.overallAverageText())
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.textPrimary())
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        Divider()
          .vertical(true)
          .height(42)
          .color(Theme.border())
        Column() {
          Text('累计平均学分绩点（4.0 制）')
            .fontSize(13)
            .fontColor(Theme.textSecondary())
          Text(this.overallGpaText())
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.textPrimary())
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .margin({ left: 20 })
      }
      .width('100%')
      Text('全部已同步历史课程 · 按北交大成绩管理办法计算')
        .fontSize(10)
        .fontColor(Theme.textDisabled())
        .margin({ top: 10 })
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding(18)
    .margin({ left: 16, right: 16, bottom: 12 })
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .backgroundBlurStyle(Theme.blurStyle())
  }

  @Builder
  GradeCard(grade: GradeInfo): void {
    Row() {
      Column() {
        Text(grade.courseName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary())
          .maxLines(2)
        if (grade.teacher.length > 0) {
          Text(grade.teacher)
            .fontSize(11)
            .fontColor(Theme.textDisabled())
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('学分 ' + (grade.credit.length > 0 ? grade.credit : '—') +
        '   成绩 ' + (grade.score.length > 0 ? grade.score : '—'))
        .fontSize(12)
        .fontColor(Theme.textSecondary())
        .margin({ left: 10 })
      Text('›')
        .fontSize(24)
        .fontColor(grade.detailPath.length > 0 || grade.hasDetailData() ?
          Theme.primary() : Theme.textDisabled())
        .margin({ left: 10 })
    }
    .width('100%')
    .height(72)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(Theme.surface())
    .backgroundBlurStyle(Theme.blurStyle())
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const params: Record<string, string> = { 'gradeId': grade.id };
      this.getUIContext().getRouter().pushUrl({ url: 'pages/GradeDetailPage', params: params });
    })
  }

  private termFilters(): Array<GradeTermFilter> {
    const result: Array<GradeTermFilter> = [];
    for (let i = 0; i < this.gradeTerms.length; i++) {
      const hasGrades: boolean = this.grades.find((grade: GradeInfo): boolean =>
        grade.termCode === this.gradeTerms[i].termCode) !== undefined;
      if (this.gradeTerms[i].selected || hasGrades) {
        this.addTermFilter(result, this.gradeTerms[i].termCode, this.gradeTerms[i].termLabel);
      }
    }
    for (let i = 0; i < this.grades.length; i++) {
      const code: string = this.grades[i].termCode.length > 0 ?
        this.grades[i].termCode : this.termLabel(this.grades[i]);
      const label: string = this.termLabel(this.grades[i]);
      this.addTermFilter(result, code, label);
    }
    return result;
  }

  private addTermFilter(result: Array<GradeTermFilter>, code: string, label: string): void {
    const canonicalCode: string = GradeTermOrder.canonical(code, label);
    if (result.find((term: GradeTermFilter): boolean => term.code === canonicalCode) !== undefined) {
      return;
    }
    const term: GradeTermFilter = new GradeTermFilter();
    term.code = canonicalCode;
    term.label = GradeTermOrder.normalize(label);
    let insertAt: number = result.length;
    for (let index = 0; index < result.length; index++) {
      if (GradeTermOrder.compare(term.label, result[index].label) > 0) {
        insertAt = index;
        break;
      }
    }
    result.splice(insertAt, 0, term);
  }

  private termSelectOptions(): Array<SelectOption> {
    const terms: Array<GradeTermFilter> = this.termFilters();
    const options: Array<SelectOption> = [];
    for (let i = 0; i < terms.length; i++) {
      options.push({ value: terms[i].label });
    }
    return options;
  }

  private selectedTermIndex(): number {
    const terms: Array<GradeTermFilter> = this.termFilters();
    for (let i = 0; i < terms.length; i++) {
      if (terms[i].code === this.selectedTermCode) {
        return i;
      }
    }
    return 0;
  }

  private selectedTermLabel(): string {
    const terms: Array<GradeTermFilter> = this.termFilters();
    const index: number = this.selectedTermIndex();
    return index >= 0 && index < terms.length ? terms[index].label : '选择学期';
  }

  private filteredGrades(): Array<GradeInfo> {
    if (this.selectedTermCode.length === 0) {
      return this.grades;
    }
    return this.grades.filter((grade: GradeInfo): boolean => {
      const code: string = GradeTermOrder.canonical(grade.termCode, this.termLabel(grade));
      return code === this.selectedTermCode;
    });
  }

  private overallGrades(): Array<GradeInfo> {
    return this.grades;
  }

  private overallMetrics(): GradeMetricsResult {
    return GradeMetrics.calculate(this.overallGrades());
  }

  private overallAverageText(): string {
    const metrics: GradeMetricsResult = this.overallMetrics();
    return metrics.hasAverage() ? metrics.averageScore.toFixed(1) : '--';
  }

  private overallGpaText(): string {
    const metrics: GradeMetricsResult = this.overallMetrics();
    return metrics.hasGpa() ? metrics.gpa.toFixed(2) : '--';
  }

  private termLabel(grade: GradeInfo): string {
    if (grade.termLabel.length > 0) {
      return grade.termLabel;
    }
    return grade.termCode.length > 0 ? grade.termCode : '未知学期';
  }

}
