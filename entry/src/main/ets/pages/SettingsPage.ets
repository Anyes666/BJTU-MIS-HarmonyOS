import { promptAction } from '@kit.ArkUI';
import { CourseDataStore } from '../store/CourseDataStore';
import { SyncState } from '../model/SyncState';
import { WhiteListManager } from '../manager/WhiteListManager';
import { LoginState } from '../model/LoginState';
import { Theme } from '../common/Theme';
import { webview } from '@kit.ArkWeb';

@Component
export struct SettingsView {
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  @State syncState: SyncState = new SyncState();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();
  private whiteListMgr: WhiteListManager = WhiteListManager.getInstance();

  aboutToAppear(): void {
    this.refresh();
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
        this.DangerZoneCard()
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
      this.Btn('清除本地课表', Theme.warning(), () => { this.showClearConfirm(); })
      this.Btn('清除本地考试', Theme.warning(), () => {
        const success: boolean = this.dataStore.clearExams();
        this.refresh();
        this.showClearResult(success, '考试数据已清除');
      })
      this.Btn('清除本地成绩', Theme.warning(), () => {
        const success: boolean = this.dataStore.clearGrades();
        this.refresh();
        this.showClearResult(success, '成绩数据已清除');
      })
      this.Btn('清除网页登录会话', Theme.warning(), () => { this.showClearSessionConfirm(); })
    }.width('100%').margin({ top: 8 })
  }

  @Builder DangerZoneCard(): void {
    Column() {
      Text('危险区域').fontSize(14).fontColor(Theme.danger()).fontWeight(FontWeight.Bold).margin({ bottom: 8 }).alignSelf(ItemAlign.Start)
      this.Btn('清除全部本地业务数据', Theme.danger(), () => { this.showClearAllConfirm(); })
    }.width('100%').padding(16).borderRadius(12).backgroundColor(Theme.dangerBackground()).margin({ top: 8 })
  }

  @Builder AboutCard(): void {
    Column() {
      Text('关于').fontSize(14).fontColor(Theme.textSecondary()).margin({ bottom: 4 }).alignSelf(ItemAlign.Center)
      Text('BjtuMis v2.0.0').fontSize(13).fontColor(Theme.textDisabled())
      Text('北京交通大学 MIS 本地助手').fontSize(12).fontColor(Theme.textDisabled()).margin({ top: 2 })
      Text('数据仅保存在手机本地，不上传任何服务器').fontSize(11).fontColor(Theme.textDisabled()).margin({ top: 8 })
    }.width('100%').padding(16).margin({ top: 8, bottom: 40 }).alignItems(HorizontalAlign.Center)
  }

  @Builder Btn(label: string, color: ResourceColor, action: () => void): void {
    Button(label).fontSize(15).width('100%').height(44).borderRadius(8)
      .backgroundColor(color).margin({ top: 6, bottom: 6 }).onClick(action)
  }

  private showClearConfirm(): void {
    promptAction.showDialog({
      title: '清除本地课表', message: '将清除所有已保存的课表数据。',
      buttons: [{ text: '取消', color: '#007AFF' }, { text: '确认清除', color: '#FF3B30' }]
    }).then((r: Object) => {
      if (((r as Record<string,Object>)['index'] as number ?? -1) === 1) {
        const success: boolean = this.dataStore.clearCourses();
        this.refresh();
        this.showClearResult(success, '课表数据已清除');
      }
    });
  }
  private showReloginConfirm(): void {
    promptAction.showDialog({
      title: '重新登录', message: '将清除当前网页登录会话，本地校园数据保持不变。',
      buttons: [{ text: '取消', color: '#007AFF' }, { text: '继续', color: '#FF3B30' }]
    }).then((r: Object) => {
      if (((r as Record<string,Object>)['index'] as number ?? -1) === 1) {
        webview.WebCookieManager.clearAllCookiesSync();
        this.loginState = LoginState.NOT_LOGGED_IN;
        this.whiteListMgr.reset();
        this.getUIContext().getRouter().pushUrl({ url: 'pages/MisWebPage' });
      }
    });
  }
  private showClearSessionConfirm(): void {
    promptAction.showDialog({
      title: '清除登录会话', message: '将清除登录状态，课表数据保留。',
      buttons: [{ text: '取消', color: '#007AFF' }, { text: '确认清除', color: '#FF3B30' }]
    }).then((r: Object) => { if (((r as Record<string,Object>)['index'] as number ?? -1) === 1) { webview.WebCookieManager.clearAllCookiesSync(); this.loginState = LoginState.NOT_LOGGED_IN; this.whiteListMgr.reset(); promptAction.showToast({ message: '登录会话已清除，本地数据已保留' }); } });
  }
  private showClearAllConfirm(): void {
    promptAction.showDialog({
      title: '清除全部本地业务数据', message: '将清除课表、考试和成绩；网页登录会话保持不变。',
      buttons: [{ text: '取消', color: '#007AFF' }, { text: '全部清除', color: '#FF3B30' }]
    }).then((r: Object) => {
      if (((r as Record<string,Object>)['index'] as number ?? -1) === 1) {
        const success: boolean = this.dataStore.clearAll();
        this.refresh();
        this.showClearResult(success, '本地业务数据已清除，网页登录会话已保留');
      }
    });
  }

  private showClearResult(success: boolean, successMessage: string): void {
    promptAction.showToast({
      message: success ? successMessage : '清除失败，本地数据状态未确认，请重试'
    });
  }
}
