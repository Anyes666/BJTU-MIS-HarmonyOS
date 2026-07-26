import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { CourseDataStore, SnapshotCommitInput, SyncResult } from '../../../main/ets/store/CourseDataStore';
import { CourseInfo, CourseSession } from '../../../main/ets/model/CourseInfo';
import { SemesterInfo } from '../../../main/ets/model/SemesterInfo';
import { SyncState } from '../../../main/ets/model/SyncState';
import { ExamInfo } from '../../../main/ets/model/ExamInfo';
import {
  GradeDetailData,
  GradeDetailField,
  GradeDetailTable,
  GradeInfo,
  GradeTermOption,
  GradeTermSummary
} from '../../../main/ets/model/GradeInfo';
import { WhiteListManager } from '../../../main/ets/manager/WhiteListManager';
import { CampusCalendar, ModuleSyncRecord, StudentProfile, SyncTarget } from '../../../main/ets/model/CampusInfo';
import { MailFolder, MailSnapshot, MailSummary } from '../../../main/ets/model/MailInfo';

const TEST_STORE_NAME: string = 'bjtu_mis_ohos_test_store';

function makeCourse(name: string = '脱敏课程'): CourseInfo {
  const course: CourseInfo = new CourseInfo();
  course.name = name;
  course.courseCode = 'A123456';
  course.section = '01';
  course.termCode = 'T1';
  const session: CourseSession = new CourseSession();
  session.dayOfWeek = 1;
  session.startPeriod = 1;
  session.endPeriod = 2;
  session.startWeek = 1;
  session.endWeek = 16;
  session.weekNumbers = [1, 2, 3, 4];
  course.sessions = [session];
  return course;
}

function makeStore(): CourseDataStore {
  const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
    .getAppContext().createModuleContext('entry_test');
  return CourseDataStore.createForTesting(
    moduleContext,
    TEST_STORE_NAME
  );
}

export default function storageTest(): void {
  describe('SnapshotStorageTest', () => {
    it('normalAtomicReplacementAndRestartRead', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.replaceCourses = true;
      input.courses = [makeCourse()];
      input.courses[0].sessions[0].startPeriod = 15;
      input.courses[0].sessions[0].endPeriod = 16;
      input.semester = new SemesterInfo();
      const result: SyncResult = store.commitSnapshot(input);
      expect(result.success).assertTrue();
      const restarted: CourseDataStore = makeStore();
      expect(restarted.loadCourses().length).assertEqual(1);
      expect(restarted.loadCourses()[0].sessions[0].endPeriod).assertEqual(16);
    });

    it('corruptActiveSnapshotFallsBackToPreviousCommittedSlot', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const previous: SnapshotCommitInput = new SnapshotCommitInput();
      previous.replaceCourses = true;
      previous.courses = [makeCourse('备用快照课程')];
      expect(store.commitSnapshot(previous).success).assertTrue();
      const latest: SnapshotCommitInput = new SnapshotCommitInput();
      latest.replaceCourses = true;
      latest.courses = [makeCourse('活动快照课程')];
      expect(store.commitSnapshot(latest).success).assertTrue();

      const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext().createModuleContext('entry_test');
      const rawStore = preferences.getPreferencesSync(moduleContext, { name: TEST_STORE_NAME });
      const activeSlot: string = rawStore.getSync('active_snapshot_slot', '') as string;
      expect(activeSlot === 'A' || activeSlot === 'B').assertTrue();
      const activeKey: string = activeSlot === 'A' ? 'data_snapshot_a_json' : 'data_snapshot_b_json';
      rawStore.putSync(activeKey, '{}');
      rawStore.flushSync();

      const restarted: CourseDataStore = makeStore();
      expect(restarted.loadCourses()[0].name).assertEqual('备用快照课程');
      restarted.clearAll();
    });

    it('partialOutcomeAndErrorsPersistAcrossRestart', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.replaceCourses = true;
      input.courses = [makeCourse()];
      input.lastOutcome = 'partial_success';
      input.errors = ['学期 T2 成绩页面结构未识别'];
      expect(store.commitSnapshot(input).success).assertTrue();
      const restarted: CourseDataStore = makeStore();
      expect(restarted.loadSyncState().lastOutcome).assertEqual('partial_success');
      expect(restarted.loadSyncState().lastErrors.length).assertEqual(1);
      expect(restarted.loadSyncState().getOutcomeText()).assertEqual('部分成功');
      restarted.clearAll();
    });

    it('validationFailureRollsBackOldSnapshot', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceCourses = true;
      initial.courses = [makeCourse('旧课程')];
      store.commitSnapshot(initial);
      const invalidCourse: CourseInfo = makeCourse('异常课程');
      invalidCourse.sessions[0].dayOfWeek = 9;
      const invalid: SnapshotCommitInput = new SnapshotCommitInput();
      invalid.replaceCourses = true;
      invalid.courses = [invalidCourse];
      const result: SyncResult = store.commitSnapshot(invalid);
      expect(result.success).assertFalse();
      expect(store.loadCourses()[0].name).assertEqual('旧课程');
    });

    it('partialModuleUpdatePreservesOtherModules', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceCourses = true; initial.courses = [makeCourse()];
      const initialExam: ExamInfo = new ExamInfo();
      initialExam.termCode = 'T1'; initialExam.courseName = '原考试课程';
      initialExam.rawText = '原考试课程 | 待安排';
      initial.replaceExams = true; initial.exams = [initialExam];
      const grade: GradeInfo = new GradeInfo();
      grade.termCode = 'T1'; grade.courseName = '课程甲'; grade.credit = '2';
      grade.score = '90'; grade.teacher = '教师甲';
      initial.replaceGrades = true; initial.grades = [grade]; initial.gradeTermsReplaced = ['T1'];
      store.commitSnapshot(initial);
      const updateExam: SnapshotCommitInput = new SnapshotCommitInput();
      updateExam.replaceExams = true;
      const exam: ExamInfo = new ExamInfo(); exam.termCode = 'T1'; exam.courseName = '考试课程';
      exam.rawText = '考试课程 | 待安排';
      updateExam.exams = [exam];
      store.commitSnapshot(updateExam);
      expect(store.loadCourses().length).assertEqual(1);
      expect(store.loadGrades().length).assertEqual(1);
      expect(store.loadExams()[0].courseName).assertEqual('考试课程');
    });

    it('invalidExamAndGradeCannotReplaceCommittedSnapshot', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const oldExam: ExamInfo = new ExamInfo();
      oldExam.termCode = 'T1'; oldExam.courseName = '旧考试'; oldExam.rawText = '旧考试 | 待安排';
      const oldGrade: GradeInfo = new GradeInfo();
      oldGrade.termCode = 'T1'; oldGrade.courseName = '旧成绩'; oldGrade.score = '90';
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceExams = true; initial.exams = [oldExam];
      initial.replaceGrades = true; initial.grades = [oldGrade]; initial.gradeTermsReplaced = ['T1'];
      expect(store.commitSnapshot(initial).success).assertTrue();

      const invalidExam: SnapshotCommitInput = new SnapshotCommitInput();
      invalidExam.replaceExams = true; invalidExam.exams = [new ExamInfo()];
      expect(store.commitSnapshot(invalidExam).success).assertFalse();
      expect(store.loadExams()[0].courseName).assertEqual('旧考试');

      const invalidGrade: GradeInfo = new GradeInfo();
      invalidGrade.termCode = 'T1';
      const invalidGrades: SnapshotCommitInput = new SnapshotCommitInput();
      invalidGrades.replaceGrades = true; invalidGrades.grades = [invalidGrade];
      invalidGrades.gradeTermsReplaced = ['T1'];
      expect(store.commitSnapshot(invalidGrades).success).assertFalse();
      expect(store.loadGrades()[0].courseName).assertEqual('旧成绩');
      store.clearAll();
    });

    it('moduleClearOnlyClearsSelectedData', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceCourses = true; initial.courses = [makeCourse()];
      const exam: ExamInfo = new ExamInfo();
      exam.termCode = 'T1'; exam.courseName = '考试课程'; exam.rawText = '考试课程 | 待安排';
      initial.replaceExams = true; initial.exams = [exam];
      const grade: GradeInfo = new GradeInfo();
      grade.termCode = 'T1'; grade.courseName = '成绩课程'; grade.score = '90';
      initial.replaceGrades = true; initial.grades = [grade]; initial.gradeTermsReplaced = ['T1'];
      expect(store.commitSnapshot(initial).success).assertTrue();
      expect(store.clearCourses()).assertTrue();
      expect(store.loadCourses().length).assertEqual(0);
      expect(store.loadExams().length).assertEqual(1);
      expect(store.loadGrades().length).assertEqual(1);
      expect(store.clearExams()).assertTrue();
      expect(store.loadExams().length).assertEqual(0);
      expect(store.loadGrades().length).assertEqual(1);
      expect(store.clearGrades()).assertTrue();
      expect(store.loadGrades().length).assertEqual(0);
    });

    it('sessionStateResetDoesNotDeleteBusinessSnapshot', 0, () => {
      const store: CourseDataStore = makeStore();
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.replaceCourses = true; input.courses = [makeCourse()];
      store.commitSnapshot(input);
      WhiteListManager.getInstance().reset();
      expect(store.loadCourses().length).assertEqual(1);
      store.clearAll();
    });

    it('examStructuredFieldsPersistAcrossRestart', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const exam: ExamInfo = new ExamInfo();
      exam.id = 'T1|C100|2026-06-23';
      exam.termCode = 'T1'; exam.termLabel = '当前学期';
      exam.courseCode = 'C100'; exam.courseName = '脱敏考试课程';
      exam.examDate = '2026-06-23'; exam.examTime = '09:00-11:00';
      exam.scheduleText = '2026-06-23 09:00-11:00';
      exam.campus = '东校区'; exam.building = '逸夫楼';
      exam.classroom = '逸夫楼 A101'; exam.locationText = '逸夫楼 A101';
      exam.seatNo = '12'; exam.rawText = '脱敏考试课程 | 2026-06-23 | 逸夫楼 A101 | 座位 12';
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.replaceExams = true; input.exams = [exam];
      expect(store.commitSnapshot(input).success).assertTrue();
      const saved: ExamInfo = makeStore().loadExams()[0];
      expect(saved.courseCode).assertEqual('C100');
      expect(saved.examDate).assertEqual('2026-06-23');
      expect(saved.examTime).assertEqual('09:00-11:00');
      expect(saved.locationText).assertEqual('逸夫楼 A101');
      expect(saved.seatNo).assertEqual('12');
      expect(saved.rawText.includes('座位 12')).assertTrue();
      store.clearAll();
    });

    it('failedGradeTermKeepsOldTermWhileSuccessfulTermUpdates', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const oldT1: GradeInfo = new GradeInfo();
      oldT1.termCode = 'T1'; oldT1.courseName = '课程甲'; oldT1.credit = '2';
      oldT1.score = '80'; oldT1.teacher = '教师甲';
      const oldT2: GradeInfo = new GradeInfo();
      oldT2.termCode = 'T2'; oldT2.courseName = '课程乙'; oldT2.credit = '2';
      oldT2.score = '70'; oldT2.teacher = '教师乙';
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceGrades = true;
      initial.grades = [oldT1, oldT2];
      initial.gradeTermsReplaced = ['T1', 'T2'];
      store.commitSnapshot(initial);
      const newT2: GradeInfo = new GradeInfo();
      newT2.termCode = 'T2'; newT2.courseName = '课程乙'; newT2.credit = '2';
      newT2.score = '90'; newT2.teacher = '教师乙';
      const partial: SnapshotCommitInput = new SnapshotCommitInput();
      partial.replaceGrades = true;
      partial.grades = [newT2];
      partial.gradeTermsReplaced = ['T2'];
      store.commitSnapshot(partial);
      expect(store.loadGrades().length).assertEqual(2);
      expect(store.loadGrades().find((g: GradeInfo): boolean =>
        g.termCode === 'T1')?.score).assertEqual('80');
      expect(store.loadGrades().find((g: GradeInfo): boolean =>
        g.termCode === 'T2')?.score).assertEqual('90');
    });

    it('persistsMisCollegeRankingAndClearsItWhenMissingOnReplacement', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const grade: GradeInfo = new GradeInfo();
      grade.termCode = 'T1'; grade.courseName = '课程甲'; grade.credit = '2';
      grade.score = '90'; grade.teacher = '教师甲';
      const summary: GradeTermSummary = new GradeTermSummary();
      summary.termCode = 'T1'; summary.termLabel = '2025-2026-1 学期';
      summary.collegeRank = 12; summary.collegeTotal = 100;
      const term: GradeTermOption = new GradeTermOption();
      term.termCode = 'T1'; term.termLabel = '2025-2026-1 学期';
      term.selected = true;
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceGrades = true; initial.grades = [grade]; initial.gradeTermsReplaced = ['T1'];
      initial.replaceGradeTerms = true; initial.gradeTerms = [term];
      initial.replaceGradeTermSummaries = true; initial.gradeTermSummaries = [summary];
      store.commitSnapshot(initial);
      expect(store.loadGradeTermSummaries()[0].collegeRank).assertEqual(12);
      expect(store.loadGradeTerms()[0].termCode).assertEqual('2025-2026-1');
      expect(store.loadGradeTerms()[0].selected).assertTrue();
      const replacement: SnapshotCommitInput = new SnapshotCommitInput();
      replacement.replaceGrades = true; replacement.grades = [grade];
      replacement.gradeTermsReplaced = ['T1']; replacement.replaceGradeTermSummaries = true;
      store.commitSnapshot(replacement);
      expect(store.loadGradeTermSummaries().length).assertEqual(0);
      store.clearAll();
    });

    it('progressiveGradeCheckpointCanResume', 0, () => {
      const store: CourseDataStore = makeStore();
      const grade: GradeInfo = new GradeInfo();
      grade.termCode = 'T1'; grade.courseName = '课程甲'; grade.credit = '2';
      grade.score = '88'; grade.teacher = '教师甲';
      expect(store.saveGradeCheckpoint([grade], ['T1'], 1, 3)).assertTrue();
      const checkpoint = store.loadGradeCheckpoint();
      expect(checkpoint !== undefined).assertTrue();
      expect(checkpoint?.completedTerms).assertEqual(1);
      expect(checkpoint?.totalTerms).assertEqual(3);
      expect(checkpoint?.grades.length).assertEqual(1);
      expect(checkpoint?.version).assertEqual(3);
      store.clearAll();
    });

    it('gradeDetailPersistsWithoutChangingLastSyncTime', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const grade: GradeInfo = new GradeInfo();
      grade.id = 'grade-detail-test';
      grade.termCode = 'T1'; grade.termLabel = '第一学期';
      grade.courseName = '脱敏课程'; grade.credit = '2';
      grade.score = '86'; grade.teacher = '教师甲';
      grade.detailPath = '/score/scores/stu/detail/1001/?term=T1';
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceGrades = true;
      initial.grades = [grade];
      initial.gradeTermsReplaced = ['T1'];
      store.commitSnapshot(initial);
      const syncTime: number = store.loadSyncState().lastSyncTime;

      const detail: GradeDetailData = new GradeDetailData();
      detail.title = '脱敏课程成绩详情';
      const field: GradeDetailField = new GradeDetailField();
      field.label = '总评'; field.value = '86';
      detail.fields = [field];
      const table: GradeDetailTable = new GradeDetailTable();
      table.title = '分项成绩';
      table.headers = ['项目', '比例', '成绩'];
      table.rows = [['平时', '40%', '88'], ['期末', '60%', '85']];
      detail.tables = [table];
      expect(store.saveGradeDetail(grade.id, detail)).assertTrue();

      const restarted: CourseDataStore = makeStore();
      const saved: GradeInfo = restarted.loadGrades()[0];
      expect(saved.detailFields[0].label).assertEqual('总评');
      expect(saved.detailTables[0].rows[1][0]).assertEqual('期末');
      expect(restarted.loadSyncState().lastSyncTime).assertEqual(syncTime);
      store.clearAll();
    });

    it('courseTermUpdatePreservesOtherSemesters', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const current: CourseInfo = makeCourse('当前学期课程');
      current.id = 'course-current-old'; current.termCode = 'T2'; current.termLabel = '第二学期';
      const history: CourseInfo = makeCourse('历史学期课程');
      history.id = 'course-history'; history.termCode = 'T1'; history.termLabel = '第一学期';
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceCourses = true;
      initial.courses = [current, history];
      initial.courseTermsReplaced = ['T1', 'T2'];
      store.commitSnapshot(initial);

      const updated: CourseInfo = makeCourse('当前学期新课程');
      updated.id = 'course-current-new'; updated.termCode = 'T2'; updated.termLabel = '第二学期';
      const refresh: SnapshotCommitInput = new SnapshotCommitInput();
      refresh.replaceCourses = true;
      refresh.courses = [updated];
      refresh.courseTermsReplaced = ['T2'];
      expect(store.commitSnapshot(refresh).success).assertTrue();
      expect(store.loadCourses().length).assertEqual(2);
      expect(store.loadCourses().find((course: CourseInfo): boolean =>
        course.termCode === 'T1')?.name).assertEqual('历史学期课程');
      expect(store.loadCourses().find((course: CourseInfo): boolean =>
        course.termCode === 'T2')?.name).assertEqual('当前学期新课程');
      store.clearAll();
    });

    it('selectedScheduleTermPersistsAcrossRestart', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      store.saveSelectedScheduleTerm('T1');
      const restarted: CourseDataStore = makeStore();
      expect(restarted.loadSelectedScheduleTerm()).assertEqual('T1');
      restarted.clearAll();
      expect(restarted.loadSelectedScheduleTerm()).assertEqual('');
    });

    it('unknownCourseTermMigratesFromSnapshotSemester', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const course: CourseInfo = makeCourse('待迁移课程');
      course.id = 'UNKNOWN_TERM|A123456|01';
      course.termCode = 'UNKNOWN_TERM';
      const semester: SemesterInfo = new SemesterInfo();
      semester.termCode = 'T2'; semester.termLabel = '第二学期';
      const initial: SnapshotCommitInput = new SnapshotCommitInput();
      initial.replaceCourses = true; initial.courses = [course]; initial.semester = semester;
      store.commitSnapshot(initial);
      const syncTime: number = store.loadSyncState().lastSyncTime;
      expect(store.resolveUnknownCourseTerms()).assertTrue();
      expect(store.loadCourses()[0].termCode).assertEqual('T2');
      expect(store.loadCourses()[0].termLabel).assertEqual('第二学期');
      expect(store.loadSyncState().lastSyncTime).assertEqual(syncTime);
      store.clearAll();
    });

    it('dailyRefreshDoesNotRepeatMonthlyHistorySync', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.replaceCourses = true;
      input.courses = [makeCourse()];
      input.fullTimetableSyncCompleted = true;
      input.fullGradeSyncCompleted = true;
      expect(store.commitSnapshot(input).success).assertTrue();
      const state: SyncState = store.loadSyncState();
      const day: number = 24 * 60 * 60 * 1000;
      expect(store.shouldAutoRefresh(state.lastSyncTime + day - 1)).assertFalse();
      expect(store.shouldAutoRefresh(state.lastSyncTime + day)).assertTrue();
      expect(store.shouldSyncHistoricalTimetables(state.lastFullTimetableSyncTime + 30 * day - 1))
        .assertFalse();
      expect(store.shouldSyncHistoricalTimetables(state.lastFullTimetableSyncTime + 30 * day))
        .assertTrue();
      expect(store.shouldSyncHistoricalGrades(state.lastFullGradeSyncTime + 30 * day - 1)).assertFalse();
      expect(store.shouldSyncHistoricalGrades(state.lastFullGradeSyncTime + 30 * day)).assertTrue();
      store.clearAll();
    });

    it('persistsVersion24ExtensionsAndMergesVisitedMailFolders', 0, () => {
      const store: CourseDataStore = makeStore();
      store.clearAll();
      const profile: StudentProfile = new StudentProfile();
      profile.studentName = '脱敏学生';
      profile.syncedAt = 1;
      const record: ModuleSyncRecord = new ModuleSyncRecord();
      record.target = SyncTarget.PROFILE;
      record.outcome = 'completed';
      record.updatedAt = 1;
      record.recordCount = 1;
      const input: SnapshotCommitInput = new SnapshotCommitInput();
      input.profile = profile;
      input.replaceProfile = true;
      input.calendar = CampusCalendar.published20262027();
      input.replaceCalendar = true;
      input.moduleRecords = [record];
      input.replaceModuleRecords = true;
      input.preserveSyncMetadata = true;
      expect(store.commitSnapshot(input).success).assertTrue();
      expect(store.loadProfile().studentName).assertEqual('脱敏学生');
      expect(store.loadCalendar().academicYear).assertEqual('2026-2027');

      const first: MailSnapshot = new MailSnapshot();
      const inbox: MailFolder = new MailFolder();
      inbox.id = 'inbox'; inbox.name = '收件箱';
      const firstMail: MailSummary = new MailSummary();
      firstMail.id = 'm1'; firstMail.folderId = 'inbox'; firstMail.subject = '脱敏邮件一';
      first.folders = [inbox]; first.messages = [firstMail]; first.updatedAt = 1;
      expect(store.commitMailSnapshot(first)).assertTrue();
      const second: MailSnapshot = new MailSnapshot();
      const sent: MailFolder = new MailFolder();
      sent.id = 'sent'; sent.name = '已发送';
      const secondMail: MailSummary = new MailSummary();
      secondMail.id = 'm2'; secondMail.folderId = 'sent'; secondMail.subject = '脱敏邮件二';
      second.folders = [sent]; second.messages = [secondMail]; second.updatedAt = 2;
      expect(store.commitMailSnapshot(second)).assertTrue();
      expect(store.loadMailSnapshot().folders.length).assertEqual(2);
      expect(store.loadMailSnapshot().messages.length).assertEqual(2);
      store.clearAll();
    });
  });
}
