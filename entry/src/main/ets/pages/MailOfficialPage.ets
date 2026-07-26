import { webview } from '@kit.ArkWeb';
import { MailParser } from '../parser/MailParser';
import { MailDetail, MailSnapshot, MailSummary } from '../model/MailInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { WhiteListManager } from '../manager/WhiteListManager';
import { Theme } from '../common/Theme';

const MAIL_SSO_URL: string = 'https://mis.bjtu.edu.cn/osys_sso_email/';

interface MailWebResourceRequest {
  getRequestUrl(): string;
}

@Entry({ routeName: 'MailOfficialPage' })
@Component
struct MailOfficialPage {
  @State currentUrl: string = MAIL_SSO_URL;
  @State statusText: string = '正在打开北京交通大学官方邮箱';
  private controller: webview.WebviewController = new webview.WebviewController();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();
  private whiteList: WhiteListManager = WhiteListManager.getInstance();
  private parsing: boolean = false;

  build() {
    Column() {
      Row() {
        Button('返回').fontSize(14).backgroundColor(Color.Transparent).fontColor(Theme.primary())
          .onClick(() => { this.getUIContext().getRouter().back(); })
        Column() {
          Text('官方校园邮箱').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.textPrimary())
          Text(this.statusText).fontSize(9).fontColor(Theme.textDisabled()).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Row() {}.width(60)
      }.width('100%').height(54).padding({ left: 8, right: 8 }).backgroundColor(Theme.topBackground())
      Web({ src: MAIL_SSO_URL, controller: this.controller })
        .layoutWeight(1).javaScriptAccess(true).domStorageAccess(true).mixedMode(MixedMode.None)
        .onUrlLoadIntercept((event) => {
          if (event === undefined || event.data === undefined) {
            return false;
          }
          let url: string = '';
          if (typeof event.data === 'string') {
            url = event.data as string;
          } else {
            url = (event.data as MailWebResourceRequest).getRequestUrl();
          }
          if (url.length > 0 && !this.whiteList.isAllowed(url)) {
            this.statusText = '已阻止非学校白名单页面';
            return true;
          }
          this.currentUrl = url;
          return false;
        })
        .onPageEnd((event) => {
          this.currentUrl = event.url;
          const sessionSaved: boolean = this.persistWebSession();
          if (this.safeHost(event.url) === 'mail.bjtu.edu.cn') {
            this.captureVisibleMail();
          } else {
            this.statusText = sessionSaved ?
              '请在学校官方页面完成登录' : '登录状态暂未保存，请完成当前登录';
          }
        })
        .onErrorReceive(() => { this.statusText = '官方邮箱暂时无法访问，离线缓存仍可使用'; })
    }.width('100%').height('100%').backgroundColor(Theme.background())
  }

  private captureVisibleMail(): void {
    if (this.parsing) {
      return;
    }
    this.parsing = true;
    this.controller.runJavaScript(MailParser.buildListScript())
      .then((result: string) => {
        if (MailParser.isRecognized(result)) {
          const snapshot: MailSnapshot = MailParser.parseList(result, this.safePageUrl(this.currentUrl));
          this.statusText = this.dataStore.commitMailSnapshot(snapshot) ?
            '邮件摘要已安全缓存' : '当前页面没有可缓存摘要';
          this.parsing = false;
          return;
        }
        this.captureDetail();
      })
      .catch(() => {
        this.parsing = false;
        this.statusText = '邮件页面解析失败，旧缓存已保留';
      });
  }

  private captureDetail(): void {
    this.controller.runJavaScript(MailParser.buildDetailScript())
      .then((result: string) => {
        const key: string = this.safePageUrl(this.currentUrl);
        const detail: MailDetail = MailParser.parseDetail(result, key);
        const snapshot: MailSnapshot = this.dataStore.loadMailSnapshot();
        const summary: MailSummary | undefined = snapshot.messages.find((item: MailSummary): boolean => {
          if (item.subject !== detail.subject) {
            return false;
          }
          return detail.sender.length === 0 || item.sender === detail.sender;
        });
        if (summary !== undefined) {
          detail.messageKey = summary.businessKey();
        }
        this.statusText = this.dataStore.saveMailDetail(detail) ?
          '当前邮件正文已转为安全文本缓存' : '未识别到邮件正文';
        this.parsing = false;
      })
      .catch(() => {
        this.parsing = false;
        this.statusText = '邮件正文解析失败，旧缓存已保留';
      });
  }

  private safeHost(url: string): string {
    const match: RegExpMatchArray | null = url.match(new RegExp('^https://([^/]+)', 'i'));
    return match !== null && match.length > 1 ? match[1].toLowerCase() : '';
  }

  private safePageUrl(url: string): string {
    const match: RegExpMatchArray | null = url.match(new RegExp('^(https://[^/?#]+)(/[^?#]*)?', 'i'));
    return match !== null ? match[1] + (match[2] ?? '/') : '';
  }

  private persistWebSession(): boolean {
    try {
      webview.WebCookieManager.saveCookieSync();
      return true;
    } catch (_) {
      return false;
    }
  }
}
