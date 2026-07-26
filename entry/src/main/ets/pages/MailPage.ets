import { MailFolder, MailSnapshot, MailSummary } from '../model/MailInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';

@Entry({ routeName: 'MailPage' })
@Component
struct MailPage {
  @State snapshot: MailSnapshot = new MailSnapshot();
  @State selectedFolder: string = '';
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.snapshot = this.dataStore.loadMailSnapshot();
    if (this.selectedFolder.length === 0 && this.snapshot.folders.length > 0) {
      this.selectedFolder = this.snapshot.folders[0].id;
    }
  }

  build() {
    Column() {
      this.TopBar()
      if (this.snapshot.folders.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.snapshot.folders, (folder: MailFolder) => {
              Button(folder.name + (folder.unreadCount > 0 ? ' ' + folder.unreadCount : ''))
                .fontSize(12).height(34).borderRadius(17)
                .fontColor(this.selectedFolder === folder.id ? Theme.onPrimary() : Theme.textPrimary())
                .backgroundColor(this.selectedFolder === folder.id ? Theme.primary() : Theme.surface())
                .onClick(() => { this.selectedFolder = folder.id; })
            }, (folder: MailFolder): string => folder.id)
          }.padding({ left: 16, right: 16 })
        }.scrollable(ScrollDirection.Horizontal).width('100%').height(48)
      }
      if (this.filteredMessages().length === 0) {
        Column() {
          Text('暂无离线邮件摘要').fontSize(17).fontColor(Theme.textPrimary())
          Text('进入官方邮箱后会缓存访问过的文件夹最近 30 封摘要')
            .fontSize(12).fontColor(Theme.textSecondary()).textAlign(TextAlign.Center)
            .margin({ top: 8, left: 24, right: 24 })
          Button('打开官方邮箱').fontSize(14).height(42).borderRadius(10)
            .backgroundColor(Theme.primary()).fontColor(Theme.onPrimary()).margin({ top: 18 })
            .onClick(() => { this.openOfficial(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.filteredMessages(), (mail: MailSummary) => {
            ListItem() {
              Column() {
                Row() {
                  Text(mail.subject).fontSize(14)
                    .fontWeight(mail.unread ? FontWeight.Bold : FontWeight.Regular)
                    .fontColor(Theme.textPrimary()).layoutWeight(1).maxLines(2)
                  Text(mail.receivedAt).fontSize(10).fontColor(Theme.textDisabled()).margin({ left: 8 })
                }.width('100%')
                Text(mail.sender).fontSize(11).fontColor(Theme.textSecondary())
                  .width('100%').maxLines(1).margin({ top: 6 })
                if (mail.preview.length > 0) {
                  Text(mail.preview).fontSize(11).fontColor(Theme.textDisabled())
                    .width('100%').maxLines(2).margin({ top: 5 })
                }
              }.width('100%').padding(14).backgroundColor(Theme.surface()).borderRadius(12)
                .onClick(() => { this.openMessage(mail); })
            }
          }, (mail: MailSummary): string => mail.businessKey())
        }.layoutWeight(1).width('100%').padding({ left: 16, right: 16, bottom: 8 })
        Button('写信 / 管理邮件 / 下载附件')
          .fontSize(13).width('calc(100% - 32vp)').height(42).borderRadius(10)
          .backgroundColor(Theme.primary()).fontColor(Theme.onPrimary()).margin({ bottom: 12 })
          .onClick(() => { this.openOfficial(); })
      }
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Column() {
        Text('校园邮箱').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
        Text('原生只读 · 写操作在官方页面完成').fontSize(9).fontColor(Theme.textDisabled())
      }.layoutWeight(1).alignItems(HorizontalAlign.Center)
      Button('更新').fontSize(12).width(60).backgroundColor(Color.Transparent).fontColor(Theme.primary())
        .onClick(() => { this.openOfficial(); })
    }.width('100%').height(56).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
  }

  private filteredMessages(): Array<MailSummary> {
    if (this.selectedFolder.length === 0) {
      return this.snapshot.messages;
    }
    const matched: Array<MailSummary> = this.snapshot.messages.filter(
      (item: MailSummary): boolean => item.folderId === this.selectedFolder);
    return matched.length > 0 ? matched : this.snapshot.messages;
  }

  private openMessage(mail: MailSummary): void {
    const key: string = mail.businessKey();
    if (this.snapshot.details.find((item): boolean => item.messageKey === key) !== undefined) {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/MailDetailPage',
        params: { messageKey: key }
      });
      return;
    }
    this.openOfficial();
  }

  private openOfficial(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MailOfficialPage' });
  }
}
