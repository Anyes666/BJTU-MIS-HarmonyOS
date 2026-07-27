import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Theme } from '../common/Theme';
import { WhiteListManager } from '../manager/WhiteListManager';
import { LoginState } from '../model/LoginState';
import { CourseDataStore } from '../store/CourseDataStore';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';

@Entry({ routeName: 'DataManagementPage' })
@Component
struct DataManagementPage {
  @StorageLink('loginState') loginState: LoginState = LoginState.UNKNOWN;
  private dataStore: CourseDataStore = CourseDataStore.getInstance();
  private whiteListManager: WhiteListManager = WhiteListManager.getInstance();

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
      this.TopBar()
      Scroll() {
        Column() {
          Text('本地数据')
            .fontSize(14)
            .fontColor(Theme.textSecondary())
            .width('100%')
            .padding(10)
            .borderRadius(10)
            .backgroundColor(Theme.card())
            .backgroundBlurStyle(Theme.blurStyle())
            .margin({ top: 20, bottom: 8 })
          this.ActionRow('清除课表', '删除本机已缓存的课表', () => {
            this.confirmClear('清除本地课表', '将清除所有已保存的课表数据。', () => {
              return this.dataStore.clearCourses();
            }, '课表数据已清除');
          })
          this.ActionRow('清除考试', '删除本机已缓存的考试安排', () => {
            this.confirmClear('清除本地考试', '将清除所有已保存的考试数据。', () => {
              return this.dataStore.clearExams();
            }, '考试数据已清除');
          })
          this.ActionRow('清除成绩', '删除本机已缓存的成绩记录', () => {
            this.confirmClear('清除本地成绩', '将清除所有已保存的成绩数据。', () => {
              return this.dataStore.clearGrades();
            }, '成绩数据已清除');
          })
          Text('账号与应用')
            .fontSize(14)
            .fontColor(Theme.textSecondary())
            .width('100%')
            .padding(10)
            .borderRadius(10)
            .backgroundColor(Theme.card())
            .backgroundBlurStyle(Theme.blurStyle())
            .margin({ top: 24, bottom: 8 })
          this.ActionRow('清除网页登录会话', '保留课表、考试和成绩', () => {
            this.confirmClear('清除登录会话', '将退出学校网页登录，本地校园数据保持不变。', () => {
              webview.WebCookieManager.clearAllCookiesSync();
              this.loginState = LoginState.NOT_LOGGED_IN;
              this.whiteListManager.reset();
              return true;
            }, '登录会话已清除，本地数据已保留');
          })
          this.ActionRow('清除全部本地数据', '登录会话保持不变', () => {
            this.confirmClear(
              '清除全部本地数据',
              '将清除课表、考试、成绩及其他本地业务数据，网页登录会话保持不变。',
              () => {
                return this.dataStore.clearAll();
              },
              '全部本地业务数据已清除'
            );
          }, true)
          Text('所有清除操作都只影响当前设备，且执行前会再次确认。')
            .fontSize(11)
            .fontColor(Theme.textDisabled())
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(12)
            .borderRadius(10)
            .backgroundColor(Theme.card())
            .backgroundBlurStyle(Theme.blurStyle())
            .margin({ top: 20, bottom: 32 })
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
      Button('返回')
        .fontSize(14)
        .fontColor(Theme.primary())
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
      Text('数据管理')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row().width(60).height(44)
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Theme.topBackground())
  }

  @Builder
  ActionRow(title: string, description: string, action: () => void, danger: boolean = false): void {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(danger ? Theme.danger() : Theme.textPrimary())
        Text(description)
          .fontSize(11)
          .fontColor(Theme.textSecondary())
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(22)
        .fontColor(Theme.textDisabled())
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 14, top: 10, bottom: 10 })
    .borderRadius(12)
    .backgroundColor(danger ? Theme.dangerBackground() : Theme.surface())
    .backgroundBlurStyle(Theme.blurStyle())
    .margin({ bottom: 8 })
    .onClick(action)
  }

  private confirmClear(
    title: string,
    message: string,
    clearAction: () => boolean,
    successMessage: string
  ): void {
    promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: Theme.dialogPrimary() },
        { text: '确认清除', color: Theme.dialogDanger() }
      ]
    }).then((result: Object) => {
      if (((result as Record<string, Object>)['index'] as number ?? -1) !== 1) {
        return;
      }
      let success: boolean = false;
      try {
        success = clearAction();
      } catch (_) {
        success = false;
      }
      promptAction.showToast({
        message: success ? successMessage : '清除失败，本地数据状态未确认，请重试'
      });
    });
  }
}
