import { describe, expect, it } from '@ohos/hypium';
import { WhiteListManager } from '../../../main/ets/manager/WhiteListManager';
import { PageInspector } from '../../../main/ets/parser/PageInspector';
import { CourseParser } from '../../../main/ets/parser/CourseParser';
import { ExamParser } from '../../../main/ets/parser/ExamParser';
import { GradeParser } from '../../../main/ets/parser/GradeParser';
import { CampusParser } from '../../../main/ets/parser/CampusParser';
import { MailParser } from '../../../main/ets/parser/MailParser';

export default function securityTest(): void {
  describe('SecurityBoundaryTest', () => {
    it('allowsOnlyExactHttpsSchoolHosts', 0, () => {
      const manager: WhiteListManager = WhiteListManager.getInstance();
      manager.reset();
      expect(manager.isAllowed('https://mis.bjtu.edu.cn/')).assertTrue();
      expect(manager.isAllowed('https://mis.bjtu.edu.cn:443/')).assertTrue();
      expect(manager.isAllowed('https://mis.bjtu.edu.cn?source=app')).assertTrue();
      expect(manager.isAllowed('https://mail.bjtu.edu.cn/')).assertTrue();
      expect(manager.isAllowed('https://mail.bjtu.edu.cn.evil.example/')).assertFalse();
      expect(manager.isAllowed('https://mis.bjtu.edu.cn.evil.example/')).assertFalse();
      expect(manager.isAllowed('https://mis.bjtu.edu.cn:443@evil.example/')).assertFalse();
      expect(manager.isAllowed('')).assertFalse();
      expect(manager.isAllowed('http://mis.bjtu.edu.cn/')).assertFalse();
      expect(manager.isAllowed('javascript:alert(1)')).assertFalse();
      expect(manager.isAllowed('data:text/html,test')).assertFalse();
    });

    it('inspectionNeverReadsInputValuesOrCookies', 0, () => {
      const script: string = PageInspector.buildPageStateScript();
      const courseInspectScript: string = CourseParser.buildInspectScript();
      expect(script.includes('document.cookie')).assertFalse();
      expect(script.includes('passwordInput.value')).assertFalse();
      expect(script.includes('loginForm.value')).assertFalse();
      expect(script.includes('url: host + path')).assertTrue();
      expect(script.includes('url: window.location.href')).assertFalse();
      expect(courseInspectScript.includes('document.cookie')).assertFalse();
      expect(courseInspectScript.includes('url: window.location.href')).assertFalse();
      expect(courseInspectScript.includes("return parsed.hostname + parsed.pathname")).assertTrue();
      expect(courseInspectScript.includes("(iframes[m].src || '').substring")).assertFalse();
    });

    it('businessParsersContainNoCookieOrAuthorizationAccess', 0, () => {
      const scripts: string = CourseParser.buildExtractScript() +
        ExamParser.buildExtractScript() + GradeParser.buildExtractScript() +
        CampusParser.buildProfileScript() + CampusParser.buildProgressScript() +
        MailParser.buildListScript() + MailParser.buildDetailScript();
      const gradeScript: string = GradeParser.buildExtractScript();
      const examScript: string = ExamParser.buildExtractScript();
      const campusAndMailScripts: string = CampusParser.buildProfileScript() +
        CampusParser.buildProgressScript() + MailParser.buildListScript() +
        MailParser.buildDetailScript();
      expect(scripts.toLowerCase().includes('document.cookie')).assertFalse();
      expect(scripts.toLowerCase().includes('authorization')).assertFalse();
      expect(scripts.toLowerCase().includes('sessionstorage')).assertFalse();
      expect(scripts.toLowerCase().includes('localstorage')).assertFalse();
      expect(campusAndMailScripts.includes('input.value')).assertFalse();
      expect(campusAndMailScripts.includes('password.value')).assertFalse();
      expect(gradeScript.includes('html: rawCell.innerHTML')).assertFalse();
      expect(gradeScript.includes('detailPath: detailPathFromCell(rawCell)')).assertTrue();
      expect(examScript.includes('rawLink.href')).assertFalse();
      expect(examScript.includes('detailPath: detailPathFromCell(rawCell)')).assertTrue();
    });
  });
}
