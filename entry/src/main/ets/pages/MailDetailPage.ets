import { MailDetail, MailSnapshot } from '../model/MailInfo';
import { MailDetailParams } from '../model/RouteParams';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';

@Entry({ routeName: 'MailDetailPage' })
@Component
struct MailDetailPage {
  @State detail: MailDetail = new MailDetail();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    const params: MailDetailParams = this.getUIContext().getRouter().getParams() as MailDetailParams;
    const snapshot: MailSnapshot = this.dataStore.loadMailSnapshot();
    const found: MailDetail | undefined = snapshot.details.find(
      (item: MailDetail): boolean => item.messageKey === params.messageKey);
    if (found !== undefined) {
      this.detail = found;
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
          .onClick(() => { this.getUIContext().getRouter().back(); })
        Text('邮件详情').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
          .layoutWeight(1).textAlign(TextAlign.Center)
        Row() {}.width(60)
      }.width('100%').height(52).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
      Scroll() {
        Column() {
          Text(this.detail.subject).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(Theme.textPrimary()).width('100%')
          Text(this.detail.sender).fontSize(12).fontColor(Theme.textSecondary())
            .width('100%').margin({ top: 10 })
          Text(this.detail.receivedAt).fontSize(11).fontColor(Theme.textDisabled())
            .width('100%').margin({ top: 4 })
          Divider().color(Theme.border()).margin({ top: 14, bottom: 14 })
          Text(this.detail.bodyText).fontSize(14).fontColor(Theme.textPrimary())
            .width('100%').lineHeight(22)
          Button('查看完整格式 / 下载附件')
            .fontSize(13).width('100%').height(42).borderRadius(10)
            .backgroundColor(Theme.primary()).fontColor(Theme.onPrimary()).margin({ top: 24, bottom: 24 })
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MailOfficialPage' });
            })
        }.width('100%').padding({ left: 16, right: 16, top: 18 })
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }
}
