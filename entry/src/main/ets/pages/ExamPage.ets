import { ExamInfo } from '../model/ExamInfo';
import { ExamTimeline } from '../model/ExamTimeline';
import { CourseDataStore } from '../store/CourseDataStore';
import { SyncState } from '../model/SyncState';
import { Theme } from '../common/Theme';
import { GradeTermOrder } from '../model/GradeInfo';

class ExamTermFilter {
  code: string = '';
  label: string = '';
}

@Component
export struct ExamView {
  @Watch('onDataRevisionChanged') @Prop dataRevision: number = 0;
  @Watch('onActiveChanged') @Prop isActive: boolean = false;
  @State exams: Array<ExamInfo> = [];
  @State syncState: SyncState = new SyncState();
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
    this.exams = this.dataStore.loadExams();
    this.syncState = this.dataStore.loadSyncState();
    const terms: Array<ExamTermFilter> = this.termFilters();
    if (terms.length > 0 &&
        terms.find((term: ExamTermFilter): boolean => term.code === this.selectedTermCode) === undefined) {
      this.selectedTermCode = terms[0].code;
    }
  }

  build() {
    Column() {
      Text('考试安排')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary())
        .margin({ top: 56, bottom: 4 })
      Text(this.syncState.lastSyncTime > 0 ?
        '数据更新于 ' + this.syncState.getSyncTimeText() : '尚未同步考试数据')
        .fontSize(11)
        .fontColor(Theme.textDisabled())
        .margin({ bottom: 16 })
      if (this.exams.length > 0) {
        Row() {
          Text('学期').fontSize(13).fontColor(Theme.textSecondary()).margin({ right: 10 })
          Select(this.termSelectOptions())
            .selected(this.selectedTermIndex())
            .value(this.selectedTermLabel())
            .backgroundColor(Theme.surface())
            .layoutWeight(1)
            .onSelect((index: number) => {
              const terms: Array<ExamTermFilter> = this.termFilters();
              if (index >= 0 && index < terms.length) {
                this.selectedTermCode = terms[index].code;
              }
            })
          Text(this.filteredExams().length.toString() + ' 条')
            .fontSize(12).fontColor(Theme.textSecondary()).margin({ left: 10 })
        }.width('100%').padding({ left: 16, right: 16, bottom: 12 })
      }
      if (this.filteredExams().length === 0) {
        Column() {
          Text('暂无考试安排').fontSize(17).fontColor(Theme.textPrimary())
          Text('无考试是合法结果；同步失败不会清除旧数据')
            .fontSize(12)
            .fontColor(Theme.textSecondary())
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.sortedExams(), (exam: ExamInfo) => {
            ListItem() {
              this.ExamCard(exam)
            }
          }, (exam: ExamInfo): string => exam.id)
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
  ExamCard(exam: ExamInfo): void {
    Column() {
      Text(exam.getDisplayCourseName())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isPast(exam) ? Theme.textSecondary() : Theme.textPrimary())
        .width('100%')
        .maxLines(2)
      Row() {
        Text(this.dateTimeText(exam))
          .fontSize(13)
          .fontColor(Theme.textSecondary())
          .layoutWeight(1)
        Text(this.countdownText(exam))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isPast(exam) ? Theme.textDisabled() : Theme.primary())
          .margin({ left: 10 })
      }.width('100%').margin({ top: 8 })
      if (this.locationText(exam).length > 0 || exam.seatNo.length > 0) {
        Row() {
          if (this.locationText(exam).length > 0) {
            Text(this.locationText(exam))
              .fontSize(13)
              .fontColor(Theme.textPrimary())
              .layoutWeight(1)
              .maxLines(2)
          }
          if (exam.seatNo.length > 0) {
            Text('座位 ' + exam.seatNo)
              .fontSize(12)
              .fontColor(Theme.secondary())
              .margin({ left: 10 })
          }
        }.width('100%').margin({ top: 6 })
      }
      if (exam.examType.length > 0) {
        Text(exam.examType)
          .fontSize(12)
          .fontColor(Theme.textSecondary())
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
      }
      Row() {
        if (exam.examMode.length > 0) {
          Text(exam.examMode)
            .fontSize(12)
            .fontColor(Theme.primary())
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (exam.status.length > 0) {
          Text(exam.status).fontSize(12).fontColor(Theme.warning()).margin({ left: 12 })
        }
      }
      .width('100%')
      .margin({ top: exam.examType.length > 0 ? 4 : 8 })
      if (exam.remark.length > 0) {
        Text(exam.remark)
          .fontSize(11)
          .fontColor(Theme.textDisabled())
          .margin({ top: 6 })
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(Theme.surface())
    .opacity(this.isPast(exam) ? 0.62 : 1)
  }

  private sortedExams(): Array<ExamInfo> {
    const result: Array<ExamInfo> = this.filteredExams().slice(0);
    result.sort((first: ExamInfo, second: ExamInfo): number => {
      const firstPast: boolean = this.isPast(first);
      const secondPast: boolean = this.isPast(second);
      if (firstPast !== secondPast) {
        return firstPast ? 1 : -1;
      }
      const firstTime: number = ExamTimeline.startTimestamp(first);
      const secondTime: number = ExamTimeline.startTimestamp(second);
      return firstPast ? secondTime - firstTime : firstTime - secondTime;
    });
    return result;
  }

  private termFilters(): Array<ExamTermFilter> {
    const result: Array<ExamTermFilter> = [];
    for (let i = 0; i < this.exams.length; i++) {
      const code: string = GradeTermOrder.canonical(
        this.exams[i].termCode, this.exams[i].termLabel);
      if (code.length === 0 ||
          result.find((item: ExamTermFilter): boolean => item.code === code) !== undefined) {
        continue;
      }
      const item: ExamTermFilter = new ExamTermFilter();
      item.code = code;
      item.label = GradeTermOrder.normalize(
        this.exams[i].termLabel.length > 0 ? this.exams[i].termLabel : this.exams[i].termCode);
      result.push(item);
    }
    result.sort((first: ExamTermFilter, second: ExamTermFilter): number =>
      GradeTermOrder.compare(second.label, first.label));
    return result;
  }

  private termSelectOptions(): Array<SelectOption> {
    const terms: Array<ExamTermFilter> = this.termFilters();
    const options: Array<SelectOption> = [];
    for (let i = 0; i < terms.length; i++) {
      options.push({ value: terms[i].label });
    }
    return options;
  }

  private selectedTermIndex(): number {
    const terms: Array<ExamTermFilter> = this.termFilters();
    for (let i = 0; i < terms.length; i++) {
      if (terms[i].code === this.selectedTermCode) {
        return i;
      }
    }
    return 0;
  }

  private selectedTermLabel(): string {
    const terms: Array<ExamTermFilter> = this.termFilters();
    const index: number = this.selectedTermIndex();
    return index >= 0 && index < terms.length ? terms[index].label : '选择学期';
  }

  private filteredExams(): Array<ExamInfo> {
    if (this.exams.length === 0 || this.selectedTermCode.length === 0) {
      return this.exams;
    }
    return this.exams.filter((exam: ExamInfo): boolean =>
      GradeTermOrder.canonical(exam.termCode, exam.termLabel) === this.selectedTermCode);
  }

  private dateTimeText(exam: ExamInfo): string {
    const structured: string = (exam.examDate + ' ' + exam.examTime).trim();
    if (structured.length > 0) {
      return structured;
    }
    return exam.scheduleText.length > 0 ? exam.scheduleText : '时间待公布';
  }

  private locationText(exam: ExamInfo): string {
    if (exam.locationText.length > 0) {
      return exam.locationText;
    }
    if (exam.classroom.length > 0) {
      return exam.classroom;
    }
    return exam.detail !== '详情' && exam.detail !== '查看' ? exam.detail : '';
  }

  private countdownText(exam: ExamInfo): string {
    if (this.isPast(exam)) {
      return '已结束';
    }
    const timestamp: number = ExamTimeline.startTimestamp(exam);
    if (timestamp === Number.MAX_SAFE_INTEGER) {
      return '时间待确认';
    }
    const diff: number = timestamp - Date.now();
    if (diff <= 0) {
      return '进行中';
    }
    const days: number = Math.floor(diff / (24 * 60 * 60 * 1000));
    if (days > 0) {
      return '还有 ' + days.toString() + ' 天';
    }
    const hours: number = Math.max(1, Math.floor(diff / (60 * 60 * 1000)));
    return '还有 ' + hours.toString() + ' 小时';
  }

  private isPast(exam: ExamInfo): boolean {
    return ExamTimeline.isPast(exam);
  }
}
