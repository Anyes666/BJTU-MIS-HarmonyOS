import { webview } from '@kit.ArkWeb';
import { CourseParser } from '../parser/CourseParser';
import { ExamParser, ExamParseResult } from '../parser/ExamParser';
import { GradeParser, GradeParseResult } from '../parser/GradeParser';
import { PageInspector } from '../parser/PageInspector';
import { ScriptResultDecoder } from '../parser/ScriptResultDecoder';
import {
  CourseDataStore,
  GradeCheckpoint,
  SnapshotCommitInput,
  SyncResult
} from '../store/CourseDataStore';
import { CourseInfo } from '../model/CourseInfo';
import { ExamInfo } from '../model/ExamInfo';
import {
  FIRST_GRADE_TERM,
  GradeInfo,
  GradeTermOption,
  GradeTermOrder,
  GradeTermSummary
} from '../model/GradeInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { LoginState } from '../model/LoginState';
import { SyncPhase, SyncPhaseTrace, SyncStatus } from '../model/SyncStatus';
import {
  AcademicProgress,
  CampusCalendar,
  ChangeEvent,
  ChangeKind,
  ModuleSyncRecord,
  StudentProfile,
  SyncRequest,
  SyncTarget
} from '../model/CampusInfo';
import { CampusParser } from '../parser/CampusParser';
import { MailParser } from '../parser/MailParser';
import { MailSnapshot, MailSummary } from '../model/MailInfo';

const AA_MODULE_URL: string = 'https://mis.bjtu.edu.cn/module/module/10/';
const TIMETABLE_URL: string = 'https://aa.bjtu.edu.cn/course_selection/courseselect/stuschedule/';
const EXAM_URL: string = 'https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/';
const PROFILE_URL: string = 'https://aa.bjtu.edu.cn/school_census/schoolcensus/stuview/';
const PROGRESS_URL: string = 'https://aa.bjtu.edu.cn/school_census/schooltraininfo/studylist/';
const MAIL_SSO_URL: string = 'https://mis.bjtu.edu.cn/osys_sso_email/';
const SCORE_BASE_URL: string = 'https://aa.bjtu.edu.cn/score/scores/stu/view/?page=1&perpage=500&ctype=';
const SCORE_TYPES: Array<string> = ['ln', 'lr'];
const PAGE_TIMEOUT_MS: number = 20000;
const SCORE_TERM_DISCOVERY_MAX_ATTEMPTS: number = 12;
const SCORE_TERM_DISCOVERY_RETRY_DELAY_MS: number = 1000;
const SCORE_TERM_PAGE_MAX_ATTEMPTS: number = 5;
const SCORE_TERM_PAGE_RETRY_DELAY_MS: number = 800;

class PageState {
  url: string = '';
  title: string = '';
  host: string = '';
  path: string = '';
  hasLoginForm: boolean = false;
  sessionExpired: boolean = false;
  forbiddenAuthPage: boolean = false;
  hasMisHomeFeature: boolean = false;
  hasAaFeature: boolean = false;
  aaEntryPath: string = '';
}

export class SyncCoordinator {
  private controller: webview.WebviewController;
  private dataStore: CourseDataStore;
  private status: SyncStatus = new SyncStatus();
  private currentUrl: string = '';
  private timeoutId: number = -1;
  private pendingTerms: Array<GradeTermOption> = [];
  private currentTermIndex: number = 0;
  private pendingTimetableTerms: Array<GradeTermOption> = [];
  private timetableTermIndex: number = 0;
  private courses: Array<CourseInfo> = [];
  private semester: SemesterInfo = new SemesterInfo();
  private exams: Array<ExamInfo> = [];
  private grades: Array<GradeInfo> = [];
  private profile: StudentProfile = new StudentProfile();
  private progress: AcademicProgress = new AcademicProgress();
  private calendar: CampusCalendar = new CampusCalendar();
  private previousMail: MailSnapshot = new MailSnapshot();
  private request: SyncRequest = new SyncRequest();
  private gradeTerms: Array<GradeTermOption> = [];
  private gradeTermSummaries: Array<GradeTermSummary> = [];
  private timetableParsed: boolean = false;
  private timetableTermParsing: boolean = false;
  private timetableTermsDiscovered: boolean = false;
  private timetableTermResolved: boolean = false;
  private examsParsed: boolean = false;
  private examParsing: boolean = false;
  private examTermSwitchAttempted: boolean = false;
  private gradesParsed: boolean = false;
  private profileParsed: boolean = false;
  private progressParsed: boolean = false;
  private scoreTermParsing: boolean = false;
  private lastNavigationKey: string = '';
  private repeatedNavigationCount: number = 0;
  private fullGradeSync: boolean = true;
  private fullTimetableSync: boolean = true;
  private timetableTermsParsed: Array<string> = [];
  private timetableTermsReplaced: Array<string> = [];
  private allTimetableTermCount: number = 0;
  private gradeTermsParsed: Array<string> = [];
  private allGradeTermCount: number = 0;
  private scoreTermDiscoveryAttempts: number = 0;
  private scoreTermDiscoveryRunning: boolean = false;
  private scoreTermDiscoverySignature: string = '';
  private scoreTermDiscoveryStableObservations: number = 0;
  private scoreTermPageAttempts: number = 0;
  private scoreTypeIndex: number = 0;
  private onStatusChanged: (status: SyncStatus) => void;
  private onLoginChanged: (state: LoginState) => void;
  private onFinished: (status: SyncStatus) => void;

  constructor(
    controller: webview.WebviewController,
    onStatusChanged: (status: SyncStatus) => void,
    onLoginChanged: (state: LoginState) => void,
    onFinished: (status: SyncStatus) => void
  ) {
    this.controller = controller;
    this.dataStore = CourseDataStore.getInstance();
    this.onStatusChanged = onStatusChanged;
    this.onLoginChanged = onLoginChanged;
    this.onFinished = onFinished;
  }

  start(request: SyncRequest = new SyncRequest()): void {
    if (this.status.running) {
      return;
    }
    this.request = request;
    this.resetRun();
    this.status.running = true;
    this.status.startedAt = Date.now();
    this.onLoginChanged(LoginState.LOGGING_IN);
    this.transition(SyncPhase.WAITING_FOR_LOGIN, '请在学校官方页面完成登录');
  }

  retry(): void {
    this.cancelTimeout();
    this.status = new SyncStatus();
    this.start();
    this.controller.loadUrl('https://mis.bjtu.edu.cn/');
  }

  cancel(): void {
    if (!this.status.running) {
      return;
    }
    const cancelledPhase: SyncPhase = this.status.phase;
    this.status.cancelled = true;
    this.status.running = false;
    if (cancelledPhase === SyncPhase.WAITING_FOR_LOGIN) {
      this.onLoginChanged(LoginState.NOT_LOGGED_IN);
    }
    this.transition(SyncPhase.CANCELLED, '同步已取消');
    this.finish();
  }

  onNetworkError(): void {
    if (!this.status.running) {
      return;
    }
    if (this.status.phase === SyncPhase.LOADING_MAIL ||
        this.status.phase === SyncPhase.PARSING_MAIL) {
      this.addError('校园邮箱同步失败，学业数据已保存');
      this.completeRun();
      return;
    }
    this.onLoginChanged(LoginState.NETWORK_ERROR);
    this.failTerminal(SyncPhase.NETWORK_ERROR, '网络不可用，已保留本地数据');
  }

  onPageEnd(url: string): void {
    if (!this.status.running || this.status.cancelled) {
      return;
    }
    this.currentUrl = this.sanitizeUrl(url);
    this.controller.runJavaScript(PageInspector.buildPageStateScript())
      .then((result: string) => {
        if (!this.status.running || this.status.cancelled) {
          return;
        }
        const page: PageState | undefined = this.parsePageState(result);
        if (page === undefined) {
          this.failTerminal(SyncPhase.PAGE_NOT_RECOGNIZED, '无法识别当前学校页面');
          return;
        }
        this.handlePage(page);
      })
      .catch(() => {
        this.failTerminal(SyncPhase.PAGE_NOT_RECOGNIZED, '页面检查失败');
      });
  }

  getStatus(): SyncStatus {
    return this.status.clone();
  }

  private resetRun(): void {
    this.cancelTimeout();
    this.status = new SyncStatus();
    this.pendingTerms = [];
    this.currentTermIndex = 0;
    this.pendingTimetableTerms = [];
    this.timetableTermIndex = 0;
    this.courses = [];
    this.semester = new SemesterInfo();
    this.exams = [];
    this.grades = [];
    this.profile = new StudentProfile();
    this.progress = new AcademicProgress();
    this.calendar = this.request.includes(SyncTarget.CALENDAR) ?
      CampusCalendar.published20262027() : new CampusCalendar();
    this.previousMail = this.dataStore.loadMailSnapshot();
    this.gradeTerms = [];
    this.gradeTermSummaries = [];
    this.timetableParsed = false;
    this.timetableTermParsing = false;
    this.timetableTermsDiscovered = false;
    this.timetableTermResolved = false;
    this.examsParsed = false;
    this.examParsing = false;
    this.examTermSwitchAttempted = false;
    this.gradesParsed = false;
    this.profileParsed = false;
    this.progressParsed = false;
    this.scoreTermParsing = false;
    this.lastNavigationKey = '';
    this.repeatedNavigationCount = 0;
    this.fullGradeSync = this.request.includeHistoricalGrades ||
      this.dataStore.shouldSyncHistoricalGrades();
    this.fullTimetableSync = false;
    this.timetableTermsParsed = [];
    this.timetableTermsReplaced = [];
    this.allTimetableTermCount = 0;
    this.gradeTermsParsed = [];
    this.allGradeTermCount = 0;
    this.scoreTermDiscoveryAttempts = 0;
    this.scoreTermDiscoveryRunning = false;
    this.scoreTermDiscoverySignature = '';
    this.scoreTermDiscoveryStableObservations = 0;
    this.scoreTermPageAttempts = 0;
    this.scoreTypeIndex = 0;
  }

  private handlePage(page: PageState): void {
    if (page.forbiddenAuthPage) {
      this.onLoginChanged(LoginState.NOT_LOGGED_IN);
      this.transition(SyncPhase.WAITING_FOR_LOGIN, '请在官方页面完成认证');
      return;
    }
    if (page.sessionExpired) {
      this.onLoginChanged(LoginState.SESSION_EXPIRED);
      this.failTerminal(SyncPhase.SESSION_EXPIRED, '会话已失效，请重新登录');
      return;
    }
    if (page.hasLoginForm || this.isAuthenticationHost(page.host)) {
      this.onLoginChanged(LoginState.NOT_LOGGED_IN);
      this.transition(SyncPhase.WAITING_FOR_LOGIN, '等待学校官方登录');
      return;
    }
    if (this.isRedirectLoop(page)) {
      this.failTerminal(SyncPhase.PAGE_NOT_RECOGNIZED, '检测到学校页面重定向循环');
      return;
    }

    if (this.status.phase === SyncPhase.WAITING_FOR_LOGIN) {
      if (page.hasAaFeature && page.host === 'aa.bjtu.edu.cn') {
        this.onLoginChanged(LoginState.LOGGED_IN);
        this.transition(SyncPhase.AA_READY, '教学支撑平台已就绪');
        this.openFirstAcademicTarget();
        return;
      }
      if (page.hasMisHomeFeature && page.host === 'mis.bjtu.edu.cn') {
        this.onLoginChanged(LoginState.LOGGED_IN);
        this.transition(SyncPhase.MIS_AUTHENTICATED, 'MIS 登录成功');
        this.transition(SyncPhase.OPENING_AA, '正在进入教学支撑平台');
        this.controller.loadUrl(this.resolveAaEntry(page.aaEntryPath));
      }
      return;
    }

    if (this.status.phase === SyncPhase.OPENING_AA) {
      if (page.host === 'aa.bjtu.edu.cn' && page.hasAaFeature) {
        this.transition(SyncPhase.AA_READY, '教学支撑平台已就绪');
        this.openFirstAcademicTarget();
      }
      return;
    }

    if (this.status.phase === SyncPhase.LOADING_TIMETABLE &&
        page.host === 'aa.bjtu.edu.cn' && this.isTimetablePath(page.path)) {
      this.parseTimetable();
      return;
    }
    if (this.status.phase === SyncPhase.LOADING_EXAMS &&
        page.host === 'aa.bjtu.edu.cn' && page.path.includes('/examine/examplanstudent/stulist/')) {
      this.parseExams();
      return;
    }
    if (this.status.phase === SyncPhase.LOADING_PROFILE &&
        page.host === 'aa.bjtu.edu.cn' &&
        page.path.includes('/school_census/schoolcensus/stuview/')) {
      this.parseProfile();
      return;
    }
    if (this.status.phase === SyncPhase.LOADING_PROGRESS &&
        page.host === 'aa.bjtu.edu.cn' &&
        page.path.includes('/school_census/schooltraininfo/studylist/')) {
      this.parseProgress();
      return;
    }
    if (this.status.phase === SyncPhase.LOADING_MAIL &&
        page.host === 'mail.bjtu.edu.cn') {
      this.parseMail();
      return;
    }
    if ((this.status.phase === SyncPhase.DISCOVERING_SCORE_TERMS ||
         this.status.phase === SyncPhase.LOADING_SCORE_TERM) &&
        page.host === 'aa.bjtu.edu.cn' && page.path.includes('/score/scores/stu/view/')) {
      this.parseAggregateScorePage();
    }
  }

  private openTimetable(): void {
    this.transition(SyncPhase.LOADING_TIMETABLE, '正在加载本学期课表');
    this.controller.loadUrl(TIMETABLE_URL);
  }

  private openFirstAcademicTarget(): void {
    if (this.request.includes(SyncTarget.TIMETABLE)) {
      this.openTimetable();
    } else if (this.request.includes(SyncTarget.EXAMS)) {
      this.openExams();
    } else if (this.request.includes(SyncTarget.PROFILE)) {
      this.openProfile();
    } else if (this.request.includes(SyncTarget.PROGRESS)) {
      this.openProgress();
    } else if (this.request.includes(SyncTarget.GRADES)) {
      this.openScores();
    } else {
      this.validateAndCommit();
    }
  }

  private nextAfterTimetable(): void {
    if (this.request.includes(SyncTarget.EXAMS)) {
      this.openExams();
    } else if (this.request.includes(SyncTarget.PROFILE)) {
      this.openProfile();
    } else if (this.request.includes(SyncTarget.PROGRESS)) {
      this.openProgress();
    } else if (this.request.includes(SyncTarget.GRADES)) {
      this.openScores();
    } else {
      this.validateAndCommit();
    }
  }

  private nextAfterExams(): void {
    if (this.request.includes(SyncTarget.PROFILE)) {
      this.openProfile();
    } else if (this.request.includes(SyncTarget.PROGRESS)) {
      this.openProgress();
    } else if (this.request.includes(SyncTarget.GRADES)) {
      this.openScores();
    } else {
      this.validateAndCommit();
    }
  }

  private parseTimetable(): void {
    if (this.timetableTermParsing) {
      return;
    }
    this.timetableTermParsing = true;
    this.transition(SyncPhase.PARSING_TIMETABLE, '正在解析课表');
    this.controller.runJavaScript(CourseParser.buildExtractScript())
      .then((result: string) => {
        try {
          const raw: Record<string, Object> =
            JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
          const recognized: boolean = (raw['recognized'] as boolean) ?? false;
          const termCourses: Array<CourseInfo> = CourseParser.parseCourseJson(result);
          const parsedSemester: SemesterInfo = CourseParser.parseSemesterFromResult(result);
          const expectedTermCode: string = this.timetableTermsDiscovered &&
            this.timetableTermIndex < this.pendingTimetableTerms.length ?
            this.pendingTimetableTerms[this.timetableTermIndex].termCode : '';
          const pageMatchesTerm: boolean = expectedTermCode.length === 0 ||
            parsedSemester.termCode === expectedTermCode;
          const reliable: boolean = recognized && pageMatchesTerm;
          this.timetableParsed = this.timetableParsed || reliable;
          if (!this.timetableTermsDiscovered && reliable) {
            this.semester = parsedSemester;
          }
          if (reliable && parsedSemester.termCode.length > 0 &&
              this.timetableTermsParsed.find((code: string): boolean =>
                code === parsedSemester.termCode) === undefined) {
            this.timetableTermsParsed.push(parsedSemester.termCode);
            this.timetableTermsReplaced.push(parsedSemester.termCode);
          }
          if (reliable) {
            for (let i = 0; i < termCourses.length; i++) {
              termCourses[i].sourceUrl = this.currentUrl;
              termCourses[i].syncedAt = Date.now();
              termCourses[i].updateTime = termCourses[i].syncedAt;
              this.addCourseIfMissing(termCourses[i]);
            }
          }
          if (!recognized) {
            this.addError('课表未解析到可靠数据');
          } else if (!pageMatchesTerm) {
            this.addError('课表学期 ' + expectedTermCode + ' 未完成切换，已跳过写入');
          }
        } catch (_) {
          this.addError('课表解析失败');
        }
        this.status.timetableCount = this.courses.length;
        this.timetableTermParsing = false;
        if (!this.timetableTermsDiscovered) {
          this.discoverTimetableTerms();
        } else {
          this.timetableTermIndex++;
          this.loadNextTimetableTerm();
        }
      })
      .catch(() => {
        this.addError('课表页面脚本执行失败');
        this.timetableTermParsing = false;
        if (!this.timetableTermsDiscovered) {
          this.nextAfterTimetable();
        } else {
          this.timetableTermIndex++;
          this.loadNextTimetableTerm();
        }
      });
  }

  private discoverTimetableTerms(): void {
    this.timetableTermsDiscovered = true;
    if (!this.fullTimetableSync) {
      this.allTimetableTermCount = this.timetableTermsParsed.length;
      this.nextAfterTimetable();
      return;
    }
    this.controller.runJavaScript(GradeParser.buildListTermsScript())
      .then((result: string) => {
        try {
          const terms: Array<GradeTermOption> = GradeParser.parseTermOptions(result);
          const syncTerms: Array<GradeTermOption> = terms.filter(
            (term: GradeTermOption): boolean =>
              !GradeParser.isFutureAcademicTerm(term.termLabel) &&
              GradeTermOrder.isAtOrAfter(term.termLabel, FIRST_GRADE_TERM));
          const selectedTerm: GradeTermOption | undefined = terms.find(
            (term: GradeTermOption): boolean => term.selected);
          if (selectedTerm !== undefined &&
              (this.semester.termCode.length === 0 || this.semester.termCode === 'UNKNOWN_TERM')) {
            this.replaceUnknownTimetableTerm(selectedTerm);
          }
          this.allTimetableTermCount = syncTerms.length;
          this.pendingTimetableTerms = syncTerms.filter((term: GradeTermOption): boolean =>
            this.timetableTermsParsed.find((code: string): boolean => code === term.termCode) === undefined);
        } catch (_) {
          this.addError('课表学期发现失败');
        }
        this.timetableTermIndex = 0;
        this.loadNextTimetableTerm();
      })
      .catch(() => {
        this.addError('课表学期发现脚本执行失败');
        this.nextAfterTimetable();
      });
  }

  private loadNextTimetableTerm(): void {
    if (this.timetableTermIndex >= this.pendingTimetableTerms.length) {
      this.nextAfterTimetable();
      return;
    }
    const term: GradeTermOption = this.pendingTimetableTerms[this.timetableTermIndex];
    this.transition(
      SyncPhase.LOADING_TIMETABLE,
      '正在同步课表 ' + (this.timetableTermsParsed.length + 1) + '/' + this.allTimetableTermCount
    );
    this.controller.runJavaScript(SyncCoordinator.buildTermSwitchScriptForTesting(term.termCode))
      .then((result: string) => {
        if (!SyncCoordinator.didTermSwitchSucceed(result)) {
          this.addError('课表学期 ' + term.termLabel + ' 切换失败');
          this.timetableTermIndex++;
          this.loadNextTimetableTerm();
          return;
        }
        setTimeout(() => {
          if (this.status.running && this.status.phase === SyncPhase.LOADING_TIMETABLE) {
            this.parseTimetable();
          }
        }, 2200);
      })
      .catch(() => {
        this.addError('课表学期 ' + term.termLabel + ' 切换失败');
        this.timetableTermIndex++;
        this.loadNextTimetableTerm();
      });
  }

  private openExams(): void {
    this.transition(SyncPhase.LOADING_EXAMS, '正在加载考试安排');
    this.controller.loadUrl(EXAM_URL);
  }

  private parseExams(): void {
    if (this.examParsing) {
      return;
    }
    this.examParsing = true;
    this.transition(SyncPhase.PARSING_EXAMS, '正在解析考试安排');
    this.controller.runJavaScript(ExamParser.buildExtractScript())
      .then((result: string) => {
        try {
          const parsed: ExamParseResult = ExamParser.parseResult(result, this.currentUrl);
          const expectedTermCode: string = this.request.termCode.length > 0 ?
            this.request.termCode : this.semester.termCode;
          if (!SyncCoordinator.doesExamTermMatch(expectedTermCode, parsed.termCode)) {
            this.examParsing = false;
            if (!this.examTermSwitchAttempted) {
              this.examTermSwitchAttempted = true;
              this.switchExamTerm(expectedTermCode);
              return;
            }
            this.addError('考试页面未切换到本学期，已保留旧数据');
            this.exams = [];
            this.examsParsed = false;
            this.status.examCount = 0;
            this.nextAfterExams();
            return;
          }
          this.exams = parsed.exams;
          this.examsParsed = parsed.recognized;
          if (!this.examsParsed) {
            this.addError('考试页面结构未识别');
          }
        } catch (_) {
          this.addError('考试解析失败');
        }
        this.examParsing = false;
        this.status.examCount = this.exams.length;
        this.nextAfterExams();
      })
      .catch(() => {
        this.examParsing = false;
        this.addError('考试页面脚本执行失败');
        this.nextAfterExams();
      });
  }

  private switchExamTerm(termCode: string): void {
    this.transition(SyncPhase.LOADING_EXAMS, '正在切换本学期考试');
    this.controller.runJavaScript(SyncCoordinator.buildTermSwitchScriptForTesting(termCode))
      .then((result: string) => {
        if (!SyncCoordinator.didTermSwitchSucceed(result)) {
          this.addError('考试学期切换失败，已保留旧数据');
          this.nextAfterExams();
          return;
        }
        setTimeout(() => {
          if (this.status.running && this.status.phase === SyncPhase.LOADING_EXAMS) {
            this.parseExams();
          }
        }, 1200);
      })
      .catch(() => {
        this.addError('考试学期切换失败，已保留旧数据');
        this.nextAfterExams();
      });
  }

  private openProfile(): void {
    this.transition(SyncPhase.LOADING_PROFILE, '正在加载个人与学籍信息');
    this.controller.loadUrl(PROFILE_URL);
  }

  private parseProfile(): void {
    this.transition(SyncPhase.PARSING_PROFILE, '正在解析个人与学籍信息');
    this.controller.runJavaScript(CampusParser.buildProfileScript())
      .then((result: string) => {
        if (CampusParser.isRecognized(result)) {
          this.profile = CampusParser.parseProfile(result, this.currentUrl);
          this.profileParsed = this.profile.hasData();
        } else {
          this.addError('个人信息页面结构未识别，已保留旧数据');
        }
        this.nextAfterProfile();
      })
      .catch(() => {
        this.addError('个人信息页面解析失败，已保留旧数据');
        this.nextAfterProfile();
      });
  }

  private nextAfterProfile(): void {
    if (this.request.includes(SyncTarget.PROGRESS)) {
      this.openProgress();
    } else if (this.request.includes(SyncTarget.GRADES)) {
      this.openScores();
    } else {
      this.validateAndCommit();
    }
  }

  private openProgress(): void {
    this.transition(SyncPhase.LOADING_PROGRESS, '正在加载培养与学分进度');
    this.controller.loadUrl(PROGRESS_URL);
  }

  private parseProgress(): void {
    this.transition(SyncPhase.PARSING_PROGRESS, '正在解析培养与学分进度');
    this.controller.runJavaScript(CampusParser.buildProgressScript())
      .then((result: string) => {
        if (CampusParser.isRecognized(result)) {
          this.progress = CampusParser.parseProgress(result, this.currentUrl);
          this.progressParsed = this.progress.hasData();
        } else {
          this.addError('培养信息页面结构未识别，已使用本地成绩参考统计');
        }
        if (this.request.includes(SyncTarget.GRADES)) {
          this.openScores();
        } else {
          this.validateAndCommit();
        }
      })
      .catch(() => {
        this.addError('培养信息页面解析失败，已保留旧数据');
        if (this.request.includes(SyncTarget.GRADES)) {
          this.openScores();
        } else {
          this.validateAndCommit();
        }
      });
  }

  private openScores(): void {
    this.scoreTypeIndex = 0;
    this.grades = [];
    this.gradeTerms = [];
    this.gradeTermsParsed = [];
    this.scoreTermPageAttempts = 0;
    this.transition(SyncPhase.DISCOVERING_SCORE_TERMS, '正在同步历年成绩');
    this.controller.loadUrl(SCORE_BASE_URL + SCORE_TYPES[this.scoreTypeIndex]);
  }

  private parseAggregateScorePage(): void {
    if (this.scoreTermParsing || this.scoreTypeIndex >= SCORE_TYPES.length) {
      return;
    }
    this.scoreTermParsing = true;
    this.scoreTermPageAttempts++;
    const expectedType: string = SCORE_TYPES[this.scoreTypeIndex];
    this.controller.runJavaScript(GradeParser.buildExtractScript())
      .then((result: string) => {
        try {
          const parsed: GradeParseResult = GradeParser.parseResult(result, this.currentUrl);
          if ((parsed.ctype !== expectedType || !parsed.recognized) &&
              this.scoreTermPageAttempts < SCORE_TERM_DISCOVERY_MAX_ATTEMPTS) {
            this.scoreTermParsing = false;
            setTimeout(() => {
              if (this.status.running &&
                  (this.status.phase === SyncPhase.DISCOVERING_SCORE_TERMS ||
                   this.status.phase === SyncPhase.LOADING_SCORE_TERM)) {
                this.parseAggregateScorePage();
              }
            }, SCORE_TERM_DISCOVERY_RETRY_DELAY_MS);
            return;
          }
          if (parsed.ctype !== expectedType) {
            if (!this.isRedundantCurrentGradePage(expectedType)) {
              this.addError('成绩列表类型 ' + expectedType + ' 未生效，已跳过写入');
            }
          } else if (!parsed.recognized) {
            if (!this.isRedundantCurrentGradePage(expectedType)) {
              this.addError('成绩列表 ' + expectedType + ' 页面结构未识别');
            }
          } else {
            this.gradesParsed = true;
            for (let i = 0; i < parsed.grades.length; i++) {
              const grade: GradeInfo = parsed.grades[i];
              if (grade.termCode.length === 0 ||
                  GradeParser.isFutureAcademicTerm(grade.termLabel)) {
                continue;
              }
              grade.id = grade.getDedupeKey();
              this.addGradeIfMissing(grade);
              const knownTerm: GradeTermOption | undefined = this.gradeTerms.find(
                (term: GradeTermOption): boolean => term.termCode === grade.termCode);
              if (knownTerm === undefined) {
                const term: GradeTermOption = new GradeTermOption();
                term.termCode = grade.termCode;
                term.termLabel = grade.termLabel;
                term.selected = expectedType === 'lr';
                this.gradeTerms.push(term);
                this.gradeTermsParsed.push(grade.termCode);
              } else if (expectedType === 'lr') {
                knownTerm.selected = true;
              }
            }
          }
        } catch (_) {
          this.addError('成绩列表 ' + expectedType + ' 解析失败');
        }
        this.scoreTermParsing = false;
        this.advanceAggregateScorePage();
      })
      .catch(() => {
        this.scoreTermParsing = false;
        this.addError('成绩列表 ' + expectedType + ' 页面脚本失败');
        this.advanceAggregateScorePage();
      });
  }

  private advanceAggregateScorePage(): void {
    this.scoreTypeIndex++;
    this.scoreTermPageAttempts = 0;
    if (this.scoreTypeIndex < SCORE_TYPES.length) {
      this.transition(SyncPhase.LOADING_SCORE_TERM, '正在同步本学期成绩');
      this.controller.loadUrl(SCORE_BASE_URL + SCORE_TYPES[this.scoreTypeIndex]);
      return;
    }
    this.finishAggregateScorePages();
  }

  private isRedundantCurrentGradePage(expectedType: string): boolean {
    if (expectedType !== 'lr') {
      return false;
    }
    const currentTermCode: string = GradeParser.currentAcademicTermCode();
    const currentTerm: GradeTermOption | undefined = this.gradeTerms.find(
      (term: GradeTermOption): boolean => term.termCode === currentTermCode);
    if (currentTerm === undefined) {
      return false;
    }
    currentTerm.selected = true;
    return true;
  }

  private finishAggregateScorePages(): void {
    const selectedCurrentTerm: GradeTermOption | undefined = this.gradeTerms.find(
      (term: GradeTermOption): boolean => term.selected);
    if (this.timetableParsed && selectedCurrentTerm !== undefined &&
        (this.semester.termCode.length === 0 || this.semester.termCode === 'UNKNOWN_TERM')) {
      this.replaceUnknownTimetableTerm(selectedCurrentTerm);
    }
    this.gradeTerms.sort((first: GradeTermOption, second: GradeTermOption): number =>
      GradeTermOrder.compare(first.termLabel, second.termLabel));
    this.allGradeTermCount = this.gradeTerms.length;
    this.status.gradeTotalTerms = this.allGradeTermCount;
    this.status.gradeCompletedTerms = this.gradeTermsParsed.length;
    this.status.gradeTotalCount = this.grades.length;
    if (this.grades.length === 0) {
      this.gradesParsed = false;
      this.addError('历年与本学期成绩均为空，已保留原有成绩');
    }
    this.validateAndCommit();
  }

  private discoverScoreTerms(): void {
    if (this.scoreTermDiscoveryRunning) {
      return;
    }
    this.scoreTermDiscoveryRunning = true;
    this.scoreTermDiscoveryAttempts++;
    this.controller.runJavaScript(GradeParser.buildListTermsScript())
      .then((result: string) => {
        try {
          this.gradeTerms = GradeParser.parseTermOptions(result);
          this.pendingTerms = this.gradeTerms.filter(
            (term: GradeTermOption): boolean =>
              !GradeParser.isFutureAcademicTerm(term.termLabel));
          const discoverySignature: string = this.pendingTerms
            .map((term: GradeTermOption): string => term.termCode)
            .join('|');
          if (discoverySignature.length > 0 &&
              discoverySignature === this.scoreTermDiscoverySignature) {
            this.scoreTermDiscoveryStableObservations++;
          } else {
            this.scoreTermDiscoverySignature = discoverySignature;
            this.scoreTermDiscoveryStableObservations =
              discoverySignature.length > 0 ? 1 : 0;
          }
          const explicitlySelectedTerm: GradeTermOption | undefined = this.pendingTerms.find(
            (term: GradeTermOption): boolean => term.selected);
          const selectedTerm: GradeTermOption | undefined = explicitlySelectedTerm !== undefined ?
            explicitlySelectedTerm : (this.pendingTerms.length > 0 ? this.pendingTerms[0] : undefined);
          const storedCourses: Array<CourseInfo> = this.dataStore.loadCourses();
          const hasUnknownStoredCourse: boolean = storedCourses.find((course: CourseInfo): boolean =>
            course.termCode.length === 0 || course.termCode === 'UNKNOWN_TERM') !== undefined;
          if (selectedTerm !== undefined &&
              (this.semester.termCode.length === 0 || this.semester.termCode === 'UNKNOWN_TERM' ||
               hasUnknownStoredCourse)) {
            this.replaceUnknownTimetableTerm(selectedTerm);
          }
          if (!this.fullGradeSync) {
            const selectedTerms: Array<GradeTermOption> =
              this.pendingTerms.filter((term: GradeTermOption): boolean => term.selected);
            this.pendingTerms = selectedTerms.length > 0 ? selectedTerms :
              this.pendingTerms.slice(0, 1);
          }
        } catch (_) {
          this.gradeTerms = [];
          this.pendingTerms = [];
        }
        this.scoreTermDiscoveryRunning = false;
        if (SyncCoordinator.shouldRetryScoreTermDiscovery(
          this.scoreTermDiscoveryAttempts,
          this.pendingTerms.length,
          this.scoreTermDiscoveryStableObservations
        )) {
          setTimeout(() => {
            if (this.status.running && this.status.phase === SyncPhase.DISCOVERING_SCORE_TERMS) {
              this.discoverScoreTerms();
            }
          }, SCORE_TERM_DISCOVERY_RETRY_DELAY_MS);
          return;
        }
        this.allGradeTermCount = this.pendingTerms.length;
        this.grades = [];
        this.restoreGradeCheckpoint();
        this.status.gradeTotalTerms = this.allGradeTermCount;
        this.currentTermIndex = 0;
        if (this.pendingTerms.length === 0) {
          if (this.allGradeTermCount === 0) {
            this.addError('未发现可用成绩学期');
          }
          this.validateAndCommit();
          return;
        }
        this.loadNextScoreTerm();
      })
      .catch(() => {
        this.scoreTermDiscoveryRunning = false;
        if (SyncCoordinator.shouldRetryScoreTermDiscovery(
          this.scoreTermDiscoveryAttempts,
          0,
          this.scoreTermDiscoveryStableObservations
        )) {
          setTimeout(() => {
            if (this.status.running && this.status.phase === SyncPhase.DISCOVERING_SCORE_TERMS) {
              this.discoverScoreTerms();
            }
          }, SCORE_TERM_DISCOVERY_RETRY_DELAY_MS);
          return;
        }
        this.addError('历史学期页面脚本执行失败');
        this.validateAndCommit();
      });
  }

  static shouldRetryScoreTermDiscovery(
    attempts: number,
    termCount: number,
    stableObservations: number
  ): boolean {
    return attempts < SCORE_TERM_DISCOVERY_MAX_ATTEMPTS &&
      (termCount === 0 || stableObservations < 2);
  }

  static shouldRejectEmptyGradeAggregate(
    discoveredTermCount: number,
    parsedTermCount: number,
    gradeCount: number
  ): boolean {
    return discoveredTermCount > 0 &&
      parsedTermCount === discoveredTermCount &&
      gradeCount === 0;
  }

  static shouldRetryScoreTermPage(attempts: number, pageMatchesTerm: boolean): boolean {
    return !pageMatchesTerm && attempts < SCORE_TERM_PAGE_MAX_ATTEMPTS;
  }

  static gradeListContractForTesting(): string {
    return SCORE_TYPES.map((ctype: string): string => SCORE_BASE_URL + ctype).join('|');
  }

  private loadNextScoreTerm(): void {
    if (this.currentTermIndex >= this.pendingTerms.length) {
      this.validateAndCommit();
      return;
    }
    const term: GradeTermOption = this.pendingTerms[this.currentTermIndex];
    this.scoreTermParsing = false;
    this.scoreTermPageAttempts = 0;
    this.transition(
      SyncPhase.LOADING_SCORE_TERM,
      '正在同步成绩 ' + (this.status.gradeCompletedTerms + 1) + '/' + this.allGradeTermCount
    );
    this.controller.runJavaScript(SyncCoordinator.buildTermSwitchScriptForTesting(term.termCode))
      .then((result: string) => {
        if (!SyncCoordinator.didTermSwitchSucceed(result)) {
          this.addError('学期 ' + term.termLabel + ' 切换失败');
          this.currentTermIndex++;
          this.status.gradeCompletedTerms =
            this.allGradeTermCount - this.pendingTerms.length + this.currentTermIndex;
          this.loadNextScoreTerm();
          return;
        }
        if (SyncCoordinator.isTermReadyWithoutReload(result)) {
          this.parseCurrentScoreTerm();
        }
      })
      .catch(() => {
        this.addError('学期 ' + term.termLabel + ' 切换失败');
        this.currentTermIndex++;
        this.status.gradeCompletedTerms =
          this.allGradeTermCount - this.pendingTerms.length + this.currentTermIndex;
        this.loadNextScoreTerm();
      });
  }

  private parseCurrentScoreTerm(): void {
    if (this.scoreTermParsing) {
      return;
    }
    if (this.currentTermIndex >= this.pendingTerms.length) {
      this.validateAndCommit();
      return;
    }
    this.scoreTermParsing = true;
    this.scoreTermPageAttempts++;
    const term: GradeTermOption = this.pendingTerms[this.currentTermIndex];
    this.controller.runJavaScript(GradeParser.buildExtractScript())
      .then((result: string) => {
        try {
          const parsed: GradeParseResult = GradeParser.parseResult(result, this.currentUrl);
          const termGrades: Array<GradeInfo> = parsed.grades;
          const termMatches: boolean = parsed.termCode.length > 0 &&
            parsed.termCode === term.termCode;
          const pageMatchesTerm: boolean = termMatches && parsed.ctype === 'ln';
          if (SyncCoordinator.shouldRetryScoreTermPage(
            this.scoreTermPageAttempts,
            pageMatchesTerm
          )) {
            this.scoreTermParsing = false;
            setTimeout(() => {
              if (this.status.running && this.status.phase === SyncPhase.LOADING_SCORE_TERM) {
                this.parseCurrentScoreTerm();
              }
            }, SCORE_TERM_PAGE_RETRY_DELAY_MS);
            return;
          }
          if (!pageMatchesTerm) {
            if (!termMatches) {
              this.addError('学期 ' + term.termLabel + ' 查询选择未生效，已跳过写入');
            } else {
              this.addError('学期 ' + term.termLabel + ' 历年成绩页面标记缺失，已跳过写入');
            }
          }
          const recognized: boolean = parsed.recognized && pageMatchesTerm;
          this.gradesParsed = this.gradesParsed || recognized;
          if (recognized &&
            this.gradeTermsParsed.find((code: string): boolean => code === term.termCode) === undefined) {
            this.gradeTermsParsed.push(term.termCode);
          }
          if (!recognized) {
            this.addError('学期 ' + term.termLabel + ' 成绩页面结构未识别');
          }
          if (pageMatchesTerm) {
            for (let i = 0; i < termGrades.length; i++) {
              termGrades[i].termCode = term.termCode;
              termGrades[i].termLabel = term.termLabel;
              termGrades[i].id = termGrades[i].getDedupeKey();
              this.addGradeIfMissing(termGrades[i]);
            }
            if (parsed.termSummary.hasCollegeRanking()) {
              parsed.termSummary.termCode = term.termCode;
              parsed.termSummary.termLabel = term.termLabel;
              this.gradeTermSummaries.push(parsed.termSummary);
            }
          }
        } catch (_) {
          this.addError('学期 ' + term.termLabel + ' 成绩解析失败');
        }
        this.currentTermIndex++;
        this.scoreTermParsing = false;
        this.status.gradeCompletedTerms =
          this.allGradeTermCount - this.pendingTerms.length + this.currentTermIndex;
        this.status.gradeTotalCount = this.grades.length;
        const checkpointSaved: boolean = this.dataStore.saveGradeCheckpoint(
          this.grades,
          this.gradeTermsParsed,
          this.status.gradeCompletedTerms,
          this.status.gradeTotalTerms,
          this.gradeTermSummaries
        );
        if (!checkpointSaved) {
          this.addError('成绩渐进检查点保存失败，已继续同步');
        }
        this.loadNextScoreTerm();
      })
      .catch(() => {
        this.addError('学期 ' + term.termLabel + ' 成绩页面脚本失败');
        this.currentTermIndex++;
        this.status.gradeCompletedTerms =
          this.allGradeTermCount - this.pendingTerms.length + this.currentTermIndex;
        this.scoreTermParsing = false;
        this.loadNextScoreTerm();
      });
  }

  private validateAndCommit(): void {
    this.transition(SyncPhase.VALIDATING, '正在校验同步结果');
    const hasExtendedData: boolean = this.profileParsed || this.progressParsed ||
      (this.request.includes(SyncTarget.CALENDAR) && this.calendar.events.length > 0);
    if (!this.timetableParsed && !this.examsParsed && !this.gradesParsed && !hasExtendedData) {
      this.failTerminal(SyncPhase.PARSE_FAILED, '未获得可提交的数据，已保留旧数据');
      return;
    }
    const rejectEmptyGradeAggregate: boolean = SyncCoordinator.shouldRejectEmptyGradeAggregate(
      this.allGradeTermCount,
      this.gradeTermsParsed.length,
      this.grades.length
    );
    if (rejectEmptyGradeAggregate) {
      this.addError('历史成绩查询结果全部为空，已保留原有成绩');
    }
    this.transition(SyncPhase.COMMITTING, '正在保存到本地');
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.courses = this.courses;
    input.semester = this.semester;
    input.exams = this.exams;
    input.grades = this.grades;
    input.gradeTerms = this.gradeTerms;
    input.gradeTermSummaries = this.gradeTermSummaries;
    input.profile = this.profile;
    input.progress = this.progress;
    input.calendar = this.calendar;
    input.replaceCourses = this.timetableParsed || this.timetableTermResolved;
    input.courseTermsReplaced = this.timetableTermsReplaced;
    input.fullTimetableSyncCompleted = this.fullTimetableSync &&
      ((this.allTimetableTermCount > 0 &&
        this.timetableTermsParsed.length === this.allTimetableTermCount) ||
       (this.allTimetableTermCount === 0 && this.timetableParsed &&
        this.semester.termCode.length > 0 && this.semester.termCode !== 'UNKNOWN_TERM'));
    input.replaceExams = this.examsParsed;
    input.examTermsReplaced = this.examTermCodes();
    input.replaceGrades = this.gradesParsed && !rejectEmptyGradeAggregate;
    input.replaceGradeTerms = this.gradeTerms.length > 0 && !rejectEmptyGradeAggregate;
    input.replaceGradeTermSummaries = this.gradesParsed && !rejectEmptyGradeAggregate;
    input.gradeTermsReplaced = rejectEmptyGradeAggregate ? [] : this.gradeTermsParsed;
    input.fullGradeSyncCompleted = this.fullGradeSync &&
      !rejectEmptyGradeAggregate && this.allGradeTermCount > 0 &&
      this.gradeTermsParsed.length === this.allGradeTermCount;
    input.replaceProfile = this.profileParsed;
    input.replaceProgress = this.progressParsed;
    input.replaceCalendar = this.request.includes(SyncTarget.CALENDAR) &&
      this.calendar.events.length > 0;
    input.moduleRecords = this.buildModuleRecords();
    input.replaceModuleRecords = true;
    input.lastOutcome = this.status.errors.length > 0 ? 'partial_success' : 'completed';
    input.errors = this.status.errors.slice(0);
    input.sourcePage = this.currentUrl;
    const result: SyncResult = this.dataStore.commitSnapshot(input);
    if (!result.success) {
      this.failTerminal(SyncPhase.PARSE_FAILED, result.errorMessage);
      return;
    }
    if (this.request.includes(SyncTarget.MAIL)) {
      this.openMail();
      return;
    }
    this.completeRun();
  }

  private openMail(): void {
    this.transition(SyncPhase.LOADING_MAIL, '正在通过学校官方 SSO 更新校园邮箱');
    this.controller.loadUrl(MAIL_SSO_URL);
  }

  private parseMail(): void {
    this.transition(SyncPhase.PARSING_MAIL, '正在缓存邮件摘要');
    this.controller.runJavaScript(MailParser.buildListScript())
      .then((result: string) => {
        if (!MailParser.isRecognized(result)) {
          this.addError('校园邮箱页面结构未识别，旧缓存已保留');
          this.completeRun();
          return;
        }
        const incoming: MailSnapshot = MailParser.parseList(result, this.currentUrl);
        if (!this.dataStore.commitMailSnapshot(incoming)) {
          this.addError('校园邮箱摘要保存失败，旧缓存已保留');
          this.completeRun();
          return;
        }
        this.persistMailStatusAndChanges(incoming);
        this.completeRun();
      })
      .catch(() => {
        this.addError('校园邮箱页面解析失败，旧缓存已保留');
        this.completeRun();
      });
  }

  private persistMailStatusAndChanges(incoming: MailSnapshot): void {
    const records: Array<ModuleSyncRecord> = this.dataStore.loadModuleSyncRecords();
    let record: ModuleSyncRecord | undefined = records.find(
      (item: ModuleSyncRecord): boolean => item.target === SyncTarget.MAIL);
    if (record === undefined) {
      record = new ModuleSyncRecord();
      record.target = SyncTarget.MAIL;
      records.push(record);
    }
    record.outcome = 'completed';
    record.updatedAt = incoming.updatedAt;
    record.recordCount = incoming.messages.length;
    record.errorMessage = '';
    record.sourcePage = incoming.sourcePage;
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.moduleRecords = records;
    input.replaceModuleRecords = true;
    input.changeEvents = this.dataStore.loadChangeEvents().concat(
      this.mailChangeEvents(this.previousMail, incoming));
    input.replaceChangeEvents = true;
    input.preserveSyncMetadata = true;
    if (!this.dataStore.commitSnapshot(input).success) {
      this.addError('校园邮箱同步状态保存失败');
    }
  }

  private mailChangeEvents(before: MailSnapshot, after: MailSnapshot): Array<ChangeEvent> {
    const result: Array<ChangeEvent> = [];
    for (let i = 0; i < after.messages.length; i++) {
      const message: MailSummary = after.messages[i];
      const key: string = message.businessKey();
      const previous: MailSummary | undefined = before.messages.find(
        (item: MailSummary): boolean => item.businessKey() === key);
      const changed: boolean = previous !== undefined &&
        (previous.subject !== message.subject || previous.sender !== message.sender ||
         previous.receivedAt !== message.receivedAt || previous.unread !== message.unread);
      if (previous === undefined || changed) {
        const event: ChangeEvent = new ChangeEvent();
        event.id = 'mail_' + Date.now() + '_' + i;
        event.target = SyncTarget.MAIL;
        event.kind = previous === undefined ? ChangeKind.ADDED : ChangeKind.MODIFIED;
        event.businessKey = key;
        event.summary = previous === undefined ? '收到新邮件：' + message.subject :
          '邮件状态已变化：' + message.subject;
        event.createdAt = Date.now();
        result.push(event);
      }
    }
    return result;
  }

  private completeRun(): void {
    this.status.running = false;
    this.status.completedAt = Date.now();
    if (this.status.errors.length > 0) {
      this.transition(SyncPhase.PARTIAL_SUCCESS, '同步部分完成，旧数据已保留');
    } else {
      this.transition(SyncPhase.COMPLETED, '同步完成');
    }
    this.finish();
  }

  private examTermCodes(): Array<string> {
    const result: Array<string> = [];
    for (let i = 0; i < this.exams.length; i++) {
      const code: string = this.exams[i].termCode;
      if (code.length > 0 &&
          result.find((item: string): boolean => item === code) === undefined) {
        result.push(code);
      }
    }
    return result;
  }

  private buildModuleRecords(): Array<ModuleSyncRecord> {
    const records: Array<ModuleSyncRecord> = this.dataStore.loadModuleSyncRecords();
    const targets: Array<SyncTarget> = [
      SyncTarget.TIMETABLE, SyncTarget.EXAMS, SyncTarget.GRADES,
      SyncTarget.PROFILE, SyncTarget.PROGRESS, SyncTarget.CALENDAR
    ];
    for (let i = 0; i < targets.length; i++) {
      const target: SyncTarget = targets[i];
      if (!this.request.includes(target)) {
        continue;
      }
      let record: ModuleSyncRecord | undefined = records.find(
        (item: ModuleSyncRecord): boolean => item.target === target);
      if (record === undefined) {
        record = new ModuleSyncRecord();
        record.target = target;
        records.push(record);
      }
      const success: boolean = this.didTargetSucceed(target);
      record.outcome = success ? 'completed' : 'partial_success';
      record.updatedAt = Date.now();
      record.recordCount = this.targetRecordCount(target);
      record.errorMessage = success || this.status.errors.length === 0 ? '' :
        this.status.errors[this.status.errors.length - 1];
      record.sourcePage = target === SyncTarget.CALENDAR ?
        this.calendar.sourceUrl : this.currentUrl;
    }
    return records;
  }

  private didTargetSucceed(target: SyncTarget): boolean {
    switch (target) {
      case SyncTarget.TIMETABLE: return this.timetableParsed;
      case SyncTarget.EXAMS: return this.examsParsed;
      case SyncTarget.GRADES: return this.gradesParsed;
      case SyncTarget.PROFILE: return this.profileParsed;
      case SyncTarget.PROGRESS: return this.progressParsed;
      case SyncTarget.CALENDAR: return this.calendar.events.length > 0;
      default: return false;
    }
  }

  private targetRecordCount(target: SyncTarget): number {
    switch (target) {
      case SyncTarget.TIMETABLE:
        return this.timetableParsed ? this.courses.length : this.dataStore.loadCourses().length;
      case SyncTarget.EXAMS:
        return this.examsParsed ? this.exams.length : this.dataStore.loadExams().length;
      case SyncTarget.GRADES:
        return this.gradesParsed ? this.grades.length : this.dataStore.loadGrades().length;
      case SyncTarget.PROFILE:
        return this.profileParsed ? this.profile.fields.length : this.dataStore.loadProfile().fields.length;
      case SyncTarget.PROGRESS:
        return this.progressParsed ? this.progress.courses.length : this.dataStore.loadProgress().courses.length;
      case SyncTarget.CALENDAR:
        return this.calendar.events.length;
      default:
        return 0;
    }
  }

  private transition(phase: SyncPhase, message: string, errorReason: string = ''): void {
    const now: number = Date.now();
    if (this.status.phaseStartedAt > 0) {
      this.status.phaseEndedAt = now;
    }
    if (this.status.traces.length > 0) {
      this.status.traces[this.status.traces.length - 1].endedAt = now;
    }
    this.status.phase = phase;
    this.status.message = message;
    this.status.phaseStartedAt = now;
    this.status.errorReason = errorReason;
    const trace: SyncPhaseTrace = new SyncPhaseTrace();
    trace.phase = phase;
    trace.message = message;
    trace.startedAt = now;
    trace.errorReason = errorReason;
    this.status.traces.push(trace);
    this.updateProgress();
    this.onStatusChanged(this.status.clone());
    this.scheduleTimeout(phase);
  }

  private scheduleTimeout(phase: SyncPhase): void {
    this.cancelTimeout();
    if (!this.status.running || phase === SyncPhase.WAITING_FOR_LOGIN ||
        phase === SyncPhase.COMPLETED || phase === SyncPhase.PARTIAL_SUCCESS) {
      return;
    }
    this.timeoutId = setTimeout(() => {
      if (this.status.running && this.status.phase === phase) {
        this.failTerminal(SyncPhase.NETWORK_ERROR, '页面加载或同步超时，已保留本地数据');
      }
    }, PAGE_TIMEOUT_MS);
  }

  private cancelTimeout(): void {
    if (this.timeoutId >= 0) {
      clearTimeout(this.timeoutId);
      this.timeoutId = -1;
    }
  }

  private failTerminal(phase: SyncPhase, reason: string): void {
    if (!this.status.running && phase !== SyncPhase.CANCELLED) {
      return;
    }
    this.addError(reason);
    this.status.running = false;
    this.status.completedAt = Date.now();
    this.transition(phase, reason, reason);
    this.finish();
  }

  private finish(): void {
    this.cancelTimeout();
    const now: number = Date.now();
    this.status.phaseEndedAt = now;
    if (this.status.traces.length > 0 &&
        this.status.traces[this.status.traces.length - 1].endedAt === 0) {
      this.status.traces[this.status.traces.length - 1].endedAt = now;
    }
    this.onStatusChanged(this.status.clone());
    this.onFinished(this.status.clone());
  }

  private addError(message: string): void {
    if (message.length === 0) {
      return;
    }
    if (this.status.errors.find((item: string): boolean => item === message) === undefined) {
      this.status.errors.push(message);
    }
  }

  private updateProgress(): void {
    const phaseProgress: Record<string, number> = {
      'idle': 0,
      'waiting_login': 5,
      'mis_authenticated': 10,
      'opening_aa': 15,
      'aa_ready': 20,
      'loading_timetable': 25,
      'parsing_timetable': 35,
      'loading_exams': 45,
      'parsing_exams': 55,
      'loading_profile': 58,
      'parsing_profile': 60,
      'loading_progress': 62,
      'parsing_progress': 64,
      'loading_mail': 92,
      'parsing_mail': 94,
      'discovering_score_terms': 65,
      'loading_score_term': 75,
      'validating': 90,
      'committing': 95,
      'completed': 100,
      'partial_success': 100
    };
    this.status.totalProgress = phaseProgress[this.status.phase] ?? this.status.totalProgress;
    if (this.status.phase === SyncPhase.LOADING_SCORE_TERM && this.status.gradeTotalTerms > 0) {
      this.status.totalProgress = 70 +
        Math.floor(18 * this.status.gradeCompletedTerms / this.status.gradeTotalTerms);
    }
  }

  private parsePageState(result: string): PageState | undefined {
    try {
      const raw: Record<string, Object> =
        JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
      const page: PageState = new PageState();
      page.url = (raw['url'] as string) ?? '';
      page.title = (raw['title'] as string) ?? '';
      page.host = (raw['host'] as string) ?? '';
      page.path = (raw['path'] as string) ?? '';
      page.hasLoginForm = (raw['hasLoginForm'] as boolean) ?? false;
      page.sessionExpired = (raw['sessionExpired'] as boolean) ?? false;
      page.forbiddenAuthPage = (raw['forbiddenAuthPage'] as boolean) ?? false;
      page.hasMisHomeFeature = (raw['hasMisHomeFeature'] as boolean) ?? false;
      page.hasAaFeature = (raw['hasAaFeature'] as boolean) ?? false;
      page.aaEntryPath = (raw['aaEntryPath'] as string) ?? '';
      return page;
    } catch (_) {
      return undefined;
    }
  }

  private addGradeIfMissing(grade: GradeInfo): void {
    const key: string = grade.getListDedupeKey();
    if (this.grades.find((item: GradeInfo): boolean => item.getListDedupeKey() === key) === undefined) {
      this.grades.push(grade);
    }
  }

  private addCourseIfMissing(course: CourseInfo): void {
    const key: string = course.id.length > 0 ? course.id :
      course.termCode + '|' + course.courseCode + '|' + course.section + '|' + course.name + '|' + course.teacher;
    if (this.courses.find((item: CourseInfo): boolean => {
      const itemKey: string = item.id.length > 0 ? item.id :
        item.termCode + '|' + item.courseCode + '|' + item.section + '|' + item.name + '|' + item.teacher;
      return itemKey === key;
    }) === undefined) {
      this.courses.push(course);
    }
  }

  private replaceUnknownTimetableTerm(term: GradeTermOption): void {
    const oldCode: string = this.semester.termCode;
    if (!this.timetableParsed) {
      this.courses = this.dataStore.loadCourses();
    }
    this.semester.termCode = term.termCode;
    this.semester.termLabel = term.termLabel;
    for (let i = 0; i < this.courses.length; i++) {
      if (this.courses[i].termCode === oldCode || this.courses[i].termCode.length === 0 ||
          this.courses[i].termCode === 'UNKNOWN_TERM') {
        this.courses[i].termCode = term.termCode;
        this.courses[i].termLabel = term.termLabel;
        this.courses[i].id = term.termCode + '|' +
          (this.courses[i].courseCode.length > 0 ?
            this.courses[i].courseCode + '|' + this.courses[i].section :
            this.courses[i].name + '|' + this.courses[i].teacher);
      }
    }
    this.timetableTermsParsed = this.timetableTermsParsed.filter(
      (code: string): boolean => code !== oldCode && code.length > 0);
    if (oldCode.length > 0 &&
        this.timetableTermsReplaced.find((code: string): boolean => code === oldCode) === undefined) {
      this.timetableTermsReplaced.push(oldCode);
    }
    if (this.timetableTermsReplaced.find((code: string): boolean => code === 'UNKNOWN_TERM') === undefined) {
      this.timetableTermsReplaced.push('UNKNOWN_TERM');
    }
    if (this.timetableTermsParsed.find((code: string): boolean => code === term.termCode) === undefined) {
      this.timetableTermsParsed.push(term.termCode);
    }
    if (this.timetableTermsReplaced.find((code: string): boolean => code === term.termCode) === undefined) {
      this.timetableTermsReplaced.push(term.termCode);
    }
    this.timetableTermResolved = this.courses.length > 0;
  }

  static buildTermSwitchScriptForTesting(termCode: string): string {
    const encoded: string = JSON.stringify(termCode);
    return `
(function() {
  var sel = document.querySelector('select[name="zxjxjhh"], select#zxjxjhh');
  if (!sel) return JSON.stringify({changed:false,ready:false});
  var target = ${encoded};
  for (var i = 0; i < sel.options.length; i++) {
    if (sel.options[i].value === target) {
      sel.value = target;
      sel.selectedIndex = i;
      var form = sel.closest('form');
      if (form) {
        var ctypeInput = form.querySelector('input[name="ctype"]');
        if (!ctypeInput) {
          ctypeInput = document.createElement('input');
          ctypeInput.type = 'hidden';
          ctypeInput.name = 'ctype';
          form.appendChild(ctypeInput);
        }
        ctypeInput.value = 'ln';
        var submitter = form.querySelector(
          'button[type="submit"], input[type="submit"], button:not([type])'
        );
        if(typeof form.requestSubmit === 'function') {
          if(submitter) form.requestSubmit(submitter);
          else form.requestSubmit();
        } else if(submitter && typeof submitter.click === 'function') {
          submitter.click();
        } else {
          form.submit();
        }
        return JSON.stringify({changed:true,ready:false});
      }
      sel.dispatchEvent(new Event('change', { bubbles: true }));
      return JSON.stringify({changed:sel.value === target,ready:sel.value === target});
    }
  }

  return JSON.stringify({changed:false,ready:false});
})();
`;
  }

  static didTermSwitchSucceed(result: string): boolean {
    try {
      const raw: Record<string, Object> =
        JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
      return (raw['changed'] as boolean) ?? false;
    } catch (_) {
      return false;
    }
  }

  static isTermReadyWithoutReload(result: string): boolean {
    try {
      const raw: Record<string, Object> =
        JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
      return ((raw['changed'] as boolean) ?? false) &&
        ((raw['ready'] as boolean) ?? false);
    } catch (_) {
      return false;
    }
  }

  static doesExamTermMatch(expectedTermCode: string, parsedTermCode: string): boolean {
    if (parsedTermCode.length === 0) {
      return false;
    }
    if (expectedTermCode.length === 0 || expectedTermCode === 'UNKNOWN_TERM') {
      return true;
    }
    return parsedTermCode === expectedTermCode;
  }

  private restoreGradeCheckpoint(): void {
    if (!this.fullGradeSync) {
      return;
    }
    const checkpoint: GradeCheckpoint | undefined = this.dataStore.loadGradeCheckpoint();
    if (checkpoint === undefined || checkpoint.totalTerms !== this.allGradeTermCount ||
        checkpoint.completedTermCodes.length === 0) {
      return;
    }
    const availableCodes: Array<string> =
      this.pendingTerms.map((term: GradeTermOption): string => term.termCode);
    for (let i = 0; i < checkpoint.completedTermCodes.length; i++) {
      if (availableCodes.find((code: string): boolean =>
          code === checkpoint.completedTermCodes[i]) === undefined) {
        return;
      }
    }
    this.grades = checkpoint.grades;
    this.gradeTermSummaries = checkpoint.gradeTermSummaries;
    this.gradeTermsParsed = checkpoint.completedTermCodes;
    this.gradesParsed = this.gradeTermsParsed.length > 0;
    this.pendingTerms = this.pendingTerms.filter((term: GradeTermOption): boolean =>
      this.gradeTermsParsed.find((code: string): boolean => code === term.termCode) === undefined);
    this.status.gradeCompletedTerms = this.gradeTermsParsed.length;
    this.status.gradeTotalCount = this.grades.length;
  }

  private sanitizeUrl(url: string): string {
    const queryIndex: number = url.indexOf('?');
    const fragmentIndex: number = url.indexOf('#');
    let end: number = url.length;
    if (queryIndex >= 0 && queryIndex < end) {
      end = queryIndex;
    }
    if (fragmentIndex >= 0 && fragmentIndex < end) {
      end = fragmentIndex;
    }
    return url.substring(0, end);
  }

  private isAuthenticationHost(host: string): boolean {
    return host === 'cas.bjtu.edu.cn' || host === 'ids.bjtu.edu.cn' ||
      host === 'auth.bjtu.edu.cn' || host === 'sso.bjtu.edu.cn';
  }

  private isTimetablePath(path: string): boolean {
    return path.includes('/course_selection/courseselect/stuschedule/') ||
      path.includes('/course_selection/courseselecttask/schedule/');
  }

  private resolveAaEntry(entryPath: string): string {
    if (entryPath.startsWith('mis.bjtu.edu.cn/module/module/')) {
      return 'https://' + entryPath;
    }
    if (entryPath.startsWith('aa.bjtu.edu.cn/')) {
      return 'https://' + entryPath;
    }
    return AA_MODULE_URL;
  }

  private isRedirectLoop(page: PageState): boolean {
    if (this.status.phase !== SyncPhase.WAITING_FOR_LOGIN &&
        this.status.phase !== SyncPhase.OPENING_AA) {
      this.lastNavigationKey = '';
      this.repeatedNavigationCount = 0;
      return false;
    }
    const key: string = page.host + page.path;
    if (key === this.lastNavigationKey) {
      this.repeatedNavigationCount++;
    } else {
      this.lastNavigationKey = key;
      this.repeatedNavigationCount = 1;
    }
    return this.repeatedNavigationCount >= 6;
  }
}
