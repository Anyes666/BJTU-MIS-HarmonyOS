export class PageInspector {
  static buildPageStateScript(): string {
    return `
(function() {
  var title = document.title || '';
  var host = window.location.hostname || '';
  var path = window.location.pathname || '';
  var text = (document.body && document.body.innerText ? document.body.innerText : '').substring(0, 6000);
  var lower = (title + ' ' + text).toLowerCase();
  var passwordInput = document.querySelector('input[type="password"]');
  var loginForm = passwordInput ? passwordInput.closest('form') : null;
  var hasLoginForm = !!passwordInput || !!loginForm;
  var sessionExpired = lower.indexOf('会话已过期') >= 0 ||
    lower.indexOf('登录已失效') >= 0 || lower.indexOf('重新登录') >= 0;
  var forbiddenAuthPage = lower.indexOf('找回密码') >= 0 ||
    lower.indexOf('修改密码') >= 0 || lower.indexOf('二次认证') >= 0 ||
    lower.indexOf('多因素认证') >= 0;
  var hasMisHomeFeature = host === 'mis.bjtu.edu.cn' && !hasLoginForm &&
    (lower.indexOf('校园信息门户') >= 0 || lower.indexOf('信息检索') >= 0 ||
     lower.indexOf('教学') >= 0 || lower.indexOf('个人中心') >= 0 ||
     document.querySelector('a[href*="/module/module/"]') !== null);
  var hasAaFeature = host === 'aa.bjtu.edu.cn' && !hasLoginForm &&
    (lower.indexOf('教学支撑平台') >= 0 || lower.indexOf('课程') >= 0 ||
     document.querySelector('select[name="zxjxjhh"], select#zxjxjhh, nav, .navbar') !== null);
  var aaEntryPath = '';
  if (host === 'mis.bjtu.edu.cn') {
    var aaLink = document.querySelector('a[href*="/module/module/10/"], a[href*="aa.bjtu.edu.cn"]');
    if (aaLink) {
      try {
        var parsedEntry = new URL(aaLink.href, window.location.href);
        if (parsedEntry.hostname === 'mis.bjtu.edu.cn' || parsedEntry.hostname === 'aa.bjtu.edu.cn') {
          aaEntryPath = parsedEntry.hostname + parsedEntry.pathname;
        }
      } catch (_) {
      }
    }
  }
  return JSON.stringify({
    url: host + path,
    title: title,
    host: host,
    path: path,
    hasLoginForm: hasLoginForm,
    sessionExpired: sessionExpired,
    forbiddenAuthPage: forbiddenAuthPage,
    hasMisHomeFeature: hasMisHomeFeature,
    hasAaFeature: hasAaFeature,
    aaEntryPath: aaEntryPath
  });
})();
`;
  }

  static isSchedulePage(inspectResult: string): boolean {
    if (inspectResult.length === 0) {
      return false;
    }
    const lower: string = inspectResult.toLowerCase();
    let score: number = 0;
    const weekdays: Array<string> = ['星期一', '星期二', '星期三', '星期四', '星期五', '周六', '周日', '周一', '周二', '周三', '周四', '周五'];
    for (let i = 0; i < weekdays.length; i++) {
      if (lower.includes(weekdays[i])) {
        score += 5;
        break;
      }
    }
    const periods: Array<string> = ['第1节', '第2节', '第 1 节', '第一大节', '第一节'];
    for (let i = 0; i < periods.length; i++) {
      if (lower.includes(periods[i])) {
        score += 5;
        break;
      }
    }
    const courseTerms: Array<string> = ['课程', '上课', '节次', '周次', '教师', '教室', 'stuschedule', 'schedule', 'course'];
    for (let i = 0; i < courseTerms.length; i++) {
      if (lower.includes(courseTerms[i])) {
        score += 1;
      }
    }
    if (lower.includes('aa.bjtu.edu.cn')) {
      score += 3;
    }
    return score >= 10;
  }
}
