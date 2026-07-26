import { webview } from '@kit.ArkWeb';
import {
  GradeDetailField,
  GradeDetailTable,
  GradeInfo
} from '../model/GradeInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { GradeDetailParser } from '../parser/GradeDetailParser';
import { GradeParser } from '../parser/GradeParser';
import { WhiteListManager } from '../manager/WhiteListManager';
import { Theme } from '../common/Theme';

interface GradeWebResourceRequest {
  getRequestUrl(): string;
}

@Entry({ routeName: 'GradeDetailPage' })
@Component
struct GradeDetailPage {
  @State grade: GradeInfo = new GradeInfo();
  @State loading: boolean = false;
  @State notFound: boolean = false;
  @State errorMessage: string = '';
  @State detailUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();
  private whiteList: WhiteListManager = WhiteListManager.getInstance();

  aboutToAppear(): void {
    const params: Object = this.getUIContext().getRouter().getParams();
    const typed: Record<string, Object> = params as Record<string, Object>;
    const gradeId: string = (typed['gradeId'] as string) ?? '';
    if (!this.loadGrade(gradeId)) {
      this.notFound = true;
      return;
    }
    if (this.grade.hasDetailData()) {
      return;
    }
    this.detailUrl = this.resolveDetailUrl(this.grade.detailPath);
    if (this.detailUrl.length === 0) {
      this.errorMessage = 'MIS 未为这条成绩提供可用的组成明细';
      return;
    }
    this.loading = true;
  }

  build() {
    Stack() {
      Column() {
        this.TopBar()
        if (this.notFound) {
          this.MessageView('成绩记录未找到')
        } else if (this.loading) {
          this.MessageView('正在从 MIS 读取成绩组成…')
        } else if (this.errorMessage.length > 0 && !this.grade.hasDetailData()) {
          this.MessageView(this.errorMessage)
        } else {
          this.DetailContent()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.background())

      if (this.loading && this.detailUrl.length > 0) {
        Web({ src: this.detailUrl, controller: this.controller })
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
            const url: string = typeof event.data === 'string' ?
              event.data as string :
              (event.data as GradeWebResourceRequest).getRequestUrl();
            return url.length > 0 && !this.whiteList.isAllowed(url);
          })
          .onPageEnd((event) => {
            this.handlePageEnd(event.url);
          })
          .onErrorReceive(() => {
            this.loading = false;
            this.errorMessage = '成绩组成加载失败，本地成绩数据已保留';
          })
      }
    }
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Text('成绩组成')
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
  MessageView(message: string): void {
    Column() {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(Theme.primary())
      }
      Text(message)
        .fontSize(15)
        .fontColor(Theme.textSecondary())
        .textAlign(TextAlign.Center)
        .margin({ top: this.loading ? 16 : 0 })
    }
    .layoutWeight(1)
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DetailContent(): void {
    Scroll() {
      Column() {
        Text(this.grade.detailTitle.length > 0 ? this.grade.detailTitle : this.grade.courseName)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary())
          .margin({ top: 24, bottom: 6 })
          .textAlign(TextAlign.Center)
        Text(this.grade.termLabel.length > 0 ? this.grade.termLabel : this.grade.termCode)
          .fontSize(12)
          .fontColor(Theme.textSecondary())
          .margin({ bottom: 16 })
        if (this.grade.detailFields.length > 0) {
          Column() {
            ForEach(this.grade.detailFields, (field: GradeDetailField) => {
              Row() {
                Text(field.label).fontSize(13).fontColor(Theme.textSecondary()).width(100)
                Text(field.value).fontSize(13).fontColor(Theme.textPrimary()).layoutWeight(1)
              }.width('100%').padding({ top: 7, bottom: 7 })
            }, (field: GradeDetailField, index: number): string =>
              'field_' + index + '_' + field.label)
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(Theme.surface())
        }
        ForEach(this.grade.detailTables, (table: GradeDetailTable, tableIndex: number) => {
          this.DetailTableCard(table, tableIndex)
        }, (_: GradeDetailTable, tableIndex: number): string => 'table_' + tableIndex)
        if (this.grade.detailLoadedAt > 0) {
          Text('明细已保存在本地')
            .fontSize(11)
            .fontColor(Theme.textDisabled())
            .margin({ top: 18, bottom: 36 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  DetailTableCard(table: GradeDetailTable, tableIndex: number): void {
    Column() {
      Text(table.title.length > 0 ? table.title : '分数构成')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })
      ForEach(table.rows, (row: Array<string>, rowIndex: number) => {
        Column() {
          ForEach(row, (value: string, cellIndex: number) => {
            Row() {
              Text(cellIndex < table.headers.length ? table.headers[cellIndex] :
                '项目 ' + (cellIndex + 1).toString())
                .fontSize(12)
                .fontColor(Theme.textSecondary())
                .width(90)
              Text(value.length > 0 ? value : '—')
                .fontSize(13)
                .fontColor(Theme.textPrimary())
                .layoutWeight(1)
            }.width('100%').padding({ top: 3, bottom: 3 })
          }, (_: string, cellIndex: number): string =>
            'cell_' + tableIndex + '_' + rowIndex + '_' + cellIndex)
        }
        .width('100%')
        .padding(10)
        .borderRadius(8)
        .backgroundColor(Theme.background())
        .margin({ top: rowIndex > 0 ? 6 : 0 })
      }, (_: Array<string>, rowIndex: number): string =>
        'row_' + tableIndex + '_' + rowIndex)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(Theme.surface())
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  private handlePageEnd(url: string): void {
    if (!this.loading) {
      return;
    }
    const sanitized: string = this.resolveDetailUrl(url);
    if (sanitized.length === 0 || !sanitized.includes('/score/')) {
      this.loading = false;
      this.errorMessage = '学校会话已失效，请重新登录后再查看成绩组成';
      return;
    }
    this.controller.runJavaScript(GradeDetailParser.buildExtractScript())
      .then((result: string) => {
        const detail = GradeDetailParser.parseResult(result);
        if (!detail.hasContent()) {
          this.loading = false;
          this.errorMessage = 'MIS 未返回可展示的成绩组成';
          return;
        }
        if (!this.dataStore.saveGradeDetail(this.grade.id, detail)) {
          this.loading = false;
          this.errorMessage = '成绩组成保存失败，原成绩数据已保留';
          return;
        }
        this.loadGrade(this.grade.id);
        this.loading = false;
        this.errorMessage = '';
      })
      .catch(() => {
        this.loading = false;
        this.errorMessage = '成绩组成解析失败，原成绩数据已保留';
      });
  }

  private loadGrade(gradeId: string): boolean {
    const grades: Array<GradeInfo> = this.dataStore.loadGrades();
    for (let i = 0; i < grades.length; i++) {
      if (grades[i].id === gradeId) {
        this.grade = grades[i];
        return true;
      }
    }
    return false;
  }

  private resolveDetailUrl(candidate: string): string {
    const path: string = GradeParser.normalizeDetailPath(candidate);
    if (path.startsWith('/')) {
      return 'https://aa.bjtu.edu.cn' + path;
    }
    if (path.startsWith('https://aa.bjtu.edu.cn/')) {
      return path;
    }
    return '';
  }
}
