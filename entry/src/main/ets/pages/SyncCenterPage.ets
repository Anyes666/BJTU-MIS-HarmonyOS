import { ChangeEvent, ChangeKind, ModuleSyncRecord, SyncTarget } from '../model/CampusInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';

@Entry({ routeName: 'SyncCenterPage' })
@Component
struct SyncCenterPage {
  @Watch('onDataRevisionChanged') @StorageLink('dataRevision') dataRevision: number = 0;
  @State records: Array<ModuleSyncRecord> = [];
  @State changes: Array<ChangeEvent> = [];
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  private onDataRevisionChanged(): void {
    this.reload();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
      this.TopBar()
      Scroll() {
        Column() {
          Button('同步全部')
            .width('100%').height(46).borderRadius(10)
            .backgroundColor(Theme.primary()).fontColor(Theme.onPrimary())
            .onClick(() => { this.openSync('all'); })
          Text('模块状态').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(Theme.textPrimary()).alignSelf(ItemAlign.Start).margin({ top: 18, bottom: 8 })
          ForEach(this.targets(), (target: SyncTarget) => {
            this.ModuleRow(target)
          }, (target: SyncTarget): string => target)
          Row() {
            Text('最近变化').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(Theme.textPrimary()).layoutWeight(1)
            if (this.unreadChanges().length > 0) {
              Button('全部已读').fontSize(12).height(32).backgroundColor(Color.Transparent)
                .fontColor(Theme.primary()).onClick(() => {
                  this.dataStore.acknowledgeChanges();
                  this.reload();
                })
            }
          }.width('100%').margin({ top: 18, bottom: 8 })
          if (this.unreadChanges().length === 0) {
            Text('暂无未读变化').fontSize(13).fontColor(Theme.textSecondary())
              .width('100%').padding(16).backgroundColor(Theme.surface()).borderRadius(12)
          } else {
            ForEach(this.unreadChanges(), (event: ChangeEvent) => {
              Row() {
                Text(this.changeBadge(event)).fontSize(12).fontColor(this.changeColor(event)).width(54)
                Column() {
                  Text(this.targetLabel(event.target)).fontSize(12).fontColor(Theme.textSecondary())
                  Text(event.summary).fontSize(13).fontColor(Theme.textPrimary())
                    .maxLines(2).margin({ top: 3 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding(14).margin({ bottom: 8 })
                .backgroundColor(Theme.surface()).borderRadius(12)
            }, (event: ChangeEvent): string => event.id)
          }
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 28 })
      }.layoutWeight(1).width('100%')
        }.width('100%').height('100%').backgroundColor(Theme.background())
      }
    }.width('100%').height('100%')
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Text('同步中心').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        .layoutWeight(1).textAlign(TextAlign.Center)
      Row() {}.width(60)
    }.width('100%').height(52).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
  }

  @Builder
  ModuleRow(target: SyncTarget): void {
    Row() {
      Column() {
        Text(this.targetLabel(target)).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary())
        Text(this.recordText(target)).fontSize(11).fontColor(Theme.textSecondary()).margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('重试').fontSize(12).height(34).borderRadius(8)
        .backgroundColor(Theme.card()).fontColor(Theme.primary())
        .onClick(() => { this.openSync(target); })
    }.width('100%').padding(14).margin({ bottom: 8 }).backgroundColor(Theme.surface()).borderRadius(12)
  }

  private reload(): void {
    this.records = this.dataStore.loadModuleSyncRecords();
    this.changes = this.dataStore.loadChangeEvents();
  }

  private targets(): Array<SyncTarget> {
    return [
      SyncTarget.TIMETABLE, SyncTarget.EXAMS, SyncTarget.GRADES, SyncTarget.PROFILE,
      SyncTarget.PROGRESS, SyncTarget.CALENDAR, SyncTarget.MAIL
    ];
  }

  private record(target: SyncTarget): ModuleSyncRecord | undefined {
    return this.records.find((item: ModuleSyncRecord): boolean => item.target === target);
  }

  private recordText(target: SyncTarget): string {
    const item: ModuleSyncRecord | undefined = this.record(target);
    if (item === undefined || item.updatedAt <= 0) {
      return '尚未同步';
    }
    const date: Date = new Date(item.updatedAt);
    const state: string = item.outcome === 'completed' ? '成功' :
      (item.outcome === 'partial_success' ? '部分成功' : '失败');
    return state + ' · ' + item.recordCount + ' 条 · ' +
      (date.getMonth() + 1) + '-' + date.getDate() + ' ' +
      date.getHours().toString().padStart(2, '0') + ':' +
      date.getMinutes().toString().padStart(2, '0');
  }

  private unreadChanges(): Array<ChangeEvent> {
    return this.changes.filter((item: ChangeEvent): boolean => !item.acknowledged).slice(0, 30);
  }

  private targetLabel(target: SyncTarget): string {
    switch (target) {
      case SyncTarget.TIMETABLE: return '课表';
      case SyncTarget.EXAMS: return '考试';
      case SyncTarget.GRADES: return '成绩';
      case SyncTarget.PROFILE: return '个人信息';
      case SyncTarget.PROGRESS: return '学业进度';
      case SyncTarget.CALENDAR: return '校历';
      case SyncTarget.MAIL: return '校园邮箱';
      default: return '模块';
    }
  }

  private changeBadge(event: ChangeEvent): string {
    if (event.kind === ChangeKind.ADDED) { return '新增'; }
    if (event.kind === ChangeKind.MODIFIED) { return '变更'; }
    return '删除';
  }

  private changeColor(event: ChangeEvent): ResourceColor {
    if (event.kind === ChangeKind.ADDED) { return Theme.success(); }
    if (event.kind === ChangeKind.MODIFIED) { return Theme.warning(); }
    return Theme.danger();
  }

  private openSync(target: string): void {
    if (target === SyncTarget.MAIL) {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MailOfficialPage' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/MisWebPage',
      params: { mode: 'sync', target: target }
    });
  }
}
