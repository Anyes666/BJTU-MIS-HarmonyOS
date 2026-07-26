import { promptAction } from '@kit.ArkUI';
import { CourseDataStore } from '../store/CourseDataStore';
import { SyncState } from '../model/SyncState';
import { WhiteListManager } from '../manager/WhiteListManager';
import { LoginState } from '../model/LoginState';
import { Theme } from '../common/Theme';
import { webview } from '@kit.ArkWeb';

@Component
export struct SettingsView {
  @Watch('onDataRevisionChanged') @Prop dataRevision: number = 0;
  @Watch('onActiveChanged') @Prop isActive: boolean = false;
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  @State syncState: SyncState = new SyncState();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.refresh();
  }

  private onDataRevisionChanged(): void {
    this.refresh();
  }

  private onActiveChanged(): void {
    if (this.isActive) {
      this.refresh();
    }
  }

  refresh(): void { this.syncState = this.dataStore.loadSyncState(); }

  build() {
    Scroll() {
      Column() {
        Text('设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.textPrimary())
          .margin({ top: 60, bottom: 24 }).alignSelf(ItemAlign.Center)
        this.SyncStatusCard()
        this.SecDiv()
        this.DataActionsCard()
        this.SecDiv()
        this.AboutCard()
      }.width('100%').padding({ left: 16, right: 16 }).alignItems(HorizontalAlign.Center)
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }

  @Builder SecDiv(): void { Divider().width('90%').color(Theme.border()).margin({ top: 4, bottom: 4 }) }

  @Builder SyncStatusCard(): void {
    Column() {
      Text('数据同步状态').fontSize(14).fontColor(Theme.textSecondary()).margin({ bottom: 8 }).alignSelf(ItemAlign.Start)
      this.RowInfo('最后同步', this.syncState.getSyncTimeText())
      this.RowInfo('上次结果', this.syncState.getOutcomeText())
      this.RowInfo('课程数量', this.syncState.courseCount.toString() + ' 门')
      this.RowInfo('考试数量', this.syncState.examCount.toString() + ' 条')
      this.RowInfo('成绩数量', this.syncState.gradeCount.toString() + ' 条')
      this.RowInfo('数据版本', 'v' + this.syncState.dataVersion.toString())
      this.RowInfo('解析器版本', '2.0.0')
      if (this.syncState.lastErrors.length > 0) {
        Text('提示：' + this.syncState.lastErrors.slice(0, 2).join('；'))
          .fontSize(12)
          .fontColor(Theme.warning())
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }
    }.width('100%').padding(16).borderRadius(12).backgroundColor(Theme.surface()).margin({ top: 8 })
  }

  @Builder RowInfo(label: string, value: string): void {
    Row() {
      Text(label).fontSize(15).fontColor(Theme.textPrimary()).layoutWeight(1)
      Text(value).fontSize(15).fontColor(Theme.textSecondary())
    }.width('100%').padding({ top: 6, bottom: 6 })
  }

  @Builder DataActionsCard(): void {
    Column() {
      this.Btn('同步数据', Theme.primary(), () => { this.getUIContext().getRouter().pushUrl({ url: 'pages/MisWebPage' }); })
      this.Btn('重新登录', Theme.secondary(), () => { this.showReloginConfirm(); })
      this.Btn('数据管理', Theme.surface(), () => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DataManagementPage' });
      }, Theme.textPrimary())
    }.width('100%').margin({ top: 8 })
  }

  @Builder AboutCard(): void {
    Column() {
      Text('关于').fontSize(14).fontColor(Theme.textSecondary()).margin({ bottom: 4 }).alignSelf(ItemAlign.Center)
      Text('BjtuMis v2.0.0').fontSize(13).fontColor(Theme.textDisabled())
      Text('北京交通大学 MIS 本地助手').fontSize(12).fontColor(Theme.textDisabled()).margin({ top: 2 })
      Text('数据仅保存在手机本地，不上传任何服务器').fontSize(11).fontColor(Theme.textDisabled()).margin({ top: 8 })
    }.width('100%').padding(16).margin({ top: 8, bottom: 40 }).alignItems(HorizontalAlign.Center)
  }

  @Builder Btn(
    label: string,
    color: ResourceColor,
    action: () => void,
    textColor: ResourceColor = Theme.onPrimary()
  ): void {
    Button(label).fontSize(15).width('100%').height(44).borderRadius(8)
      .fontColor(textColor)
      .backgroundColor(color).margin({ top: 6, bottom: 6 }).onClick(action)
  }

  private showReloginConfirm(): void {
    const pageRouter = this.getUIContext().getRouter();
    promptAction.showDialog({
      title: '重新登录', message: '将清除当前网页登录会话，本地校园数据保持不变。',
      buttons: [{ text: '取消', color: '#007AFF' }, { text: '继续', color: '#FF3B30' }]
    }).then((r: Object) => {
      if (((r as Record<string,Object>)['index'] as number ?? -1) === 1) {
        webview.WebCookieManager.clearAllCookiesSync();
        AppStorage.setOrCreate('loginState', LoginState.NOT_LOGGED_IN);
        WhiteListManager.getInstance().reset();
        pageRouter.pushUrl({ url: 'pages/MisWebPage' });
      }
    });
  }
}
