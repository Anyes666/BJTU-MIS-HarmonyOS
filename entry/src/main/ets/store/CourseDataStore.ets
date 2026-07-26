import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { SyncState } from '../model/SyncState';
import { ExamInfo } from '../model/ExamInfo';
import {
  GradeDetailData,
  GradeDetailField,
  GradeDetailTable,
  GradeInfo,
  GradeTermOption,
  GradeTermOrder,
  GradeTermSummary
} from '../model/GradeInfo';
import {
  AcademicProgress,
  CalendarEvent,
  CampusCalendar,
  ChangeEvent,
  ChangeKind,
  ModuleSyncRecord,
  ProfileField,
  ProgressCourse,
  StudentProfile,
  SyncTarget
} from '../model/CampusInfo';
import { MailDetail, MailFolder, MailSnapshot, MailSummary } from '../model/MailInfo';

const STORE_NAME: string = 'bjtu_mis_store';
const KEY_COURSES: string = 'courses_json';
const KEY_SYNC_STATE: string = 'sync_state_json';
const KEY_SEMESTER: string = 'semester_json';
const KEY_DATA_VERSION: string = 'data_version';
const KEY_COURSES_TEMP: string = 'courses_json_temp';
const KEY_SNAPSHOT: string = 'data_snapshot_json';
const KEY_SNAPSHOT_TEMP: string = 'data_snapshot_temp_json';
const KEY_SNAPSHOT_A: string = 'data_snapshot_a_json';
const KEY_SNAPSHOT_B: string = 'data_snapshot_b_json';
const KEY_ACTIVE_SNAPSHOT: string = 'active_snapshot_slot';
const KEY_GRADE_CHECKPOINT: string = 'grade_checkpoint_json';
const KEY_SELECTED_SCHEDULE_TERM: string = 'selected_schedule_term';
const KEY_MAIL_SNAPSHOT_A: string = 'mail_snapshot_a_json';
const KEY_MAIL_SNAPSHOT_B: string = 'mail_snapshot_b_json';
const KEY_ACTIVE_MAIL_SNAPSHOT: string = 'active_mail_snapshot_slot';

const MIN_COURSE_COUNT: number = 1;
const MAX_COURSE_COUNT: number = 1000;
const CURRENT_DATA_VERSION: number = 24;
const GRADE_CHECKPOINT_VERSION: number = 3;
const AUTO_REFRESH_INTERVAL_MS: number = 24 * 60 * 60 * 1000;
const FULL_TIMETABLE_REFRESH_INTERVAL_MS: number = 30 * 24 * 60 * 60 * 1000;
const FULL_GRADE_REFRESH_INTERVAL_MS: number = 30 * 24 * 60 * 60 * 1000;

export interface SyncResult {
  success: boolean;
  courseCount: number;
  errorMessage: string;
}

export class SnapshotCommitInput {
  courses: Array<CourseInfo> = [];
  semester: SemesterInfo = new SemesterInfo();
  exams: Array<ExamInfo> = [];
  grades: Array<GradeInfo> = [];
  gradeTerms: Array<GradeTermOption> = [];
  gradeTermSummaries: Array<GradeTermSummary> = [];
  profile: StudentProfile = new StudentProfile();
  progress: AcademicProgress = new AcademicProgress();
  calendar: CampusCalendar = CampusCalendar.published20262027();
  moduleRecords: Array<ModuleSyncRecord> = [];
  changeEvents: Array<ChangeEvent> = [];
  replaceCourses: boolean = false;
  courseTermsReplaced: Array<string> = [];
  fullTimetableSyncCompleted: boolean = false;
  replaceExams: boolean = false;
  examTermsReplaced: Array<string> = [];
  replaceGrades: boolean = false;
  replaceGradeTerms: boolean = false;
  replaceGradeTermSummaries: boolean = false;
  replaceProfile: boolean = false;
  replaceProgress: boolean = false;
  replaceCalendar: boolean = false;
  replaceModuleRecords: boolean = false;
  replaceChangeEvents: boolean = false;
  gradeTermsReplaced: Array<string> = [];
  fullGradeSyncCompleted: boolean = false;
  preserveSyncMetadata: boolean = false;
  lastOutcome: string = 'completed';
  errors: Array<string> = [];
  sourcePage: string = '';
}

export class GradeCheckpoint {
  version: number = 0;
  grades: Array<GradeInfo> = [];
  gradeTermSummaries: Array<GradeTermSummary> = [];
  completedTermCodes: Array<string> = [];
  completedTerms: number = 0;
  totalTerms: number = 0;
  updatedAt: number = 0;
}

export class CourseDataStore {
  private static instance: CourseDataStore;
  private store: preferences.Preferences | undefined = undefined;

  private constructor() {
  }

  static getInstance(): CourseDataStore {
    if (CourseDataStore.instance === undefined) {
      CourseDataStore.instance = new CourseDataStore();
    }
    return CourseDataStore.instance;
  }

  init(context: common.Context): void {
    this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  static createForTesting(context: common.Context, storeName: string): CourseDataStore {
    const dataStore: CourseDataStore = new CourseDataStore();
    dataStore.store = preferences.getPreferencesSync(context, { name: storeName });
    return dataStore;
  }

  loadCourses(): Array<CourseInfo> {
    if (this.store === undefined) {
      return [];
    }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const snapshotCourses: Object | undefined = snapshot?.['courses'];
    if (snapshotCourses !== undefined && Array.isArray(snapshotCourses)) {
      return this.parseCourseArray(snapshotCourses as Array<Object>);
    }
    const json: string = this.store.getSync(KEY_COURSES, '') as string;
    if (json.length === 0) {
      return [];
    }
    return this.parseCoursesJson(json);
  }

  loadSyncState(): SyncState {
    if (this.store === undefined) {
      return new SyncState();
    }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const snapshotState: Object | undefined = snapshot?.['syncState'];
    if (snapshotState !== undefined) {
      return this.parseSyncStateObj(snapshotState as Record<string, Object>);
    }
    const json: string = this.store.getSync(KEY_SYNC_STATE, '') as string;
    if (json.length === 0) {
      return new SyncState();
    }
    return this.parseSyncStateJson(json);
  }

  loadSemester(): SemesterInfo {
    if (this.store === undefined) {
      return new SemesterInfo();
    }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const snapshotSemester: Object | undefined = snapshot?.['semester'];
    if (snapshotSemester !== undefined) {
      return this.parseSemesterObj(snapshotSemester as Record<string, Object>);
    }
    const json: string = this.store.getSync(KEY_SEMESTER, '') as string;
    if (json.length === 0) {
      return new SemesterInfo();
    }
    return this.parseSemesterJson(json);
  }

  loadProfile(): StudentProfile {
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const raw: Object | undefined = snapshot?.['profile'];
    return raw !== undefined ? this.parseProfile(raw as Record<string, Object>) : new StudentProfile();
  }

  loadProgress(): AcademicProgress {
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const raw: Object | undefined = snapshot?.['progress'];
    return raw !== undefined ? this.parseProgress(raw as Record<string, Object>) : new AcademicProgress();
  }

  loadCalendar(): CampusCalendar {
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const raw: Object | undefined = snapshot?.['calendar'];
    if (raw !== undefined) {
      const parsed: CampusCalendar = this.parseCalendar(raw as Record<string, Object>);
      if (parsed.events.length > 0) {
        return parsed;
      }
    }
    return CampusCalendar.published20262027();
  }

  loadModuleSyncRecords(): Array<ModuleSyncRecord> {
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const raw: Object | undefined = snapshot?.['moduleRecords'];
    if (raw === undefined || !Array.isArray(raw)) {
      return [];
    }
    const result: Array<ModuleSyncRecord> = [];
    for (let i = 0; i < raw.length; i++) {
      const item: Record<string, Object> = raw[i] as Record<string, Object>;
      const record: ModuleSyncRecord = new ModuleSyncRecord();
      record.target = ((item['target'] as string) ?? SyncTarget.TIMETABLE) as SyncTarget;
      record.outcome = (item['outcome'] as string) ?? 'idle';
      record.updatedAt = (item['updatedAt'] as number) ?? 0;
      record.recordCount = (item['recordCount'] as number) ?? 0;
      record.errorMessage = (item['errorMessage'] as string) ?? '';
      record.sourcePage = (item['sourcePage'] as string) ?? '';
      result.push(record);
    }
    return result;
  }

  loadChangeEvents(): Array<ChangeEvent> {
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const raw: Object | undefined = snapshot?.['changeEvents'];
    if (raw === undefined || !Array.isArray(raw)) {
      return [];
    }
    const result: Array<ChangeEvent> = [];
    for (let i = 0; i < raw.length; i++) {
      const item: Record<string, Object> = raw[i] as Record<string, Object>;
      const event: ChangeEvent = new ChangeEvent();
      event.id = (item['id'] as string) ?? '';
      event.target = ((item['target'] as string) ?? SyncTarget.TIMETABLE) as SyncTarget;
      event.kind = ((item['kind'] as string) ?? ChangeKind.ADDED) as ChangeKind;
      event.businessKey = (item['businessKey'] as string) ?? '';
      event.summary = (item['summary'] as string) ?? '';
      event.createdAt = (item['createdAt'] as number) ?? 0;
      event.acknowledged = (item['acknowledged'] as boolean) ?? false;
      if (event.id.length > 0) {
        result.push(event);
      }
    }
    return result;
  }

  acknowledgeChanges(): boolean {
    const events: Array<ChangeEvent> = this.loadChangeEvents();
    let changed: boolean = false;
    for (let i = 0; i < events.length; i++) {
      if (!events[i].acknowledged) {
        events[i].acknowledged = true;
        changed = true;
      }
    }
    if (!changed) {
      return true;
    }
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.changeEvents = events;
    input.replaceChangeEvents = true;
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  syncAndReplace(rawJson: string, sourcePage: string, semester: SemesterInfo): SyncResult {
    if (this.store === undefined) {
      const result: SyncResult = { success: false, courseCount: 0, errorMessage: '存储未初始化' };
      return result;
    }
    const courses: Array<CourseInfo> = this.parseCoursesJson(rawJson);
    if (courses.length === 0) {
      const result: SyncResult = { success: false, courseCount: 0, errorMessage: '未解析到任何课程数据' };
      return result;
    }
    const validationResult: SyncResult = this.validateCourses(courses);
    if (!validationResult.success) {
      return validationResult;
    }
    this.store.putSync(KEY_COURSES_TEMP, JSON.stringify(courses));
    this.store.putSync(KEY_COURSES, JSON.stringify(courses));
    const syncState: SyncState = new SyncState();
    syncState.lastSyncTime = Date.now();
    syncState.courseCount = courses.length;
    syncState.sourcePage = sourcePage;
    syncState.dataVersion = CURRENT_DATA_VERSION;
    syncState.semester = semester;
    syncState.lastOutcome = 'completed';
    this.store.putSync(KEY_SYNC_STATE, JSON.stringify(syncState));
    this.store.putSync(KEY_SEMESTER, JSON.stringify(semester));
    this.store.putSync(KEY_DATA_VERSION, CURRENT_DATA_VERSION);
    this.store.flushSync();
    const successResult: SyncResult = { success: true, courseCount: courses.length, errorMessage: '' };
    return successResult;
  }

  clearCourses(): boolean {
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.replaceCourses = true;
    input.courses = [];
    input.semester = new SemesterInfo();
    input.preserveSyncMetadata = true;
    const success: boolean = this.commitSnapshot(input).success;
    if (success) {
      this.saveSelectedScheduleTerm('');
    }
    return success;
  }

  clearExams(): boolean {
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.replaceExams = true;
    input.exams = [];
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  clearGrades(): boolean {
    const existing: Array<GradeInfo> = this.loadGrades();
    const terms: Array<string> = [];
    for (let i = 0; i < existing.length; i++) {
      if (terms.find((term: string): boolean => term === existing[i].termCode) === undefined) {
        terms.push(existing[i].termCode);
      }
    }
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.replaceGrades = true;
    input.grades = [];
    input.replaceGradeTerms = true;
    input.replaceGradeTermSummaries = true;
    input.gradeTermsReplaced = terms;
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  clearCampusExtensions(): boolean {
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.replaceProfile = true;
    input.profile = new StudentProfile();
    input.replaceProgress = true;
    input.progress = new AcademicProgress();
    input.replaceModuleRecords = true;
    input.moduleRecords = this.loadModuleSyncRecords().filter(
      (record: ModuleSyncRecord): boolean =>
        record.target !== SyncTarget.PROFILE &&
        record.target !== SyncTarget.PROGRESS &&
        record.target !== SyncTarget.CALENDAR
    );
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  clearMail(): boolean {
    if (this.store === undefined) {
      return false;
    }
    try {
      this.store.putSync(KEY_MAIL_SNAPSHOT_A, '');
      this.store.putSync(KEY_MAIL_SNAPSHOT_B, '');
      this.store.putSync(KEY_ACTIVE_MAIL_SNAPSHOT, '');
      this.store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  clearAll(): boolean {
    if (this.store === undefined) { return false; }
    try {
      this.store.putSync(KEY_COURSES, ''); this.store.putSync(KEY_COURSES_TEMP, '');
      this.store.putSync(KEY_SYNC_STATE, ''); this.store.putSync(KEY_SEMESTER, '');
      this.store.putSync(KEY_DATA_VERSION, 0);
      this.store.putSync('exams_json', ''); this.store.putSync('grades_json', '');
      this.store.putSync(KEY_SNAPSHOT, ''); this.store.putSync(KEY_SNAPSHOT_TEMP, '');
      this.store.putSync(KEY_SNAPSHOT_A, ''); this.store.putSync(KEY_SNAPSHOT_B, '');
      this.store.putSync(KEY_ACTIVE_SNAPSHOT, '');
      this.store.putSync(KEY_GRADE_CHECKPOINT, '');
      this.store.putSync(KEY_SELECTED_SCHEDULE_TERM, '');
      this.store.putSync(KEY_MAIL_SNAPSHOT_A, '');
      this.store.putSync(KEY_MAIL_SNAPSHOT_B, '');
      this.store.putSync(KEY_ACTIVE_MAIL_SNAPSHOT, '');
      this.store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  hasCourses(): boolean {
    if (this.store === undefined) { return false; }
    return (this.store.getSync(KEY_DATA_VERSION, 0) as number) >= 1;
  }

  shouldAutoRefresh(now: number = Date.now()): boolean {
    const state: SyncState = this.loadSyncState();
    return state.hasData() && (state.dataVersion < CURRENT_DATA_VERSION ||
      state.lastSyncTime === 0 ||
      now - state.lastSyncTime >= AUTO_REFRESH_INTERVAL_MS);
  }

  shouldSyncHistoricalGrades(now: number = Date.now()): boolean {
    const state: SyncState = this.loadSyncState();
    return state.lastOutcome !== 'completed' ||
      state.dataVersion < CURRENT_DATA_VERSION ||
      state.lastFullGradeSyncTime === 0 ||
      now - state.lastFullGradeSyncTime >= FULL_GRADE_REFRESH_INTERVAL_MS;
  }

  shouldSyncHistoricalTimetables(now: number = Date.now()): boolean {
    const state: SyncState = this.loadSyncState();
    return state.dataVersion < CURRENT_DATA_VERSION ||
      state.lastFullTimetableSyncTime === 0 ||
      now - state.lastFullTimetableSyncTime >= FULL_TIMETABLE_REFRESH_INTERVAL_MS;
  }

  loadSelectedScheduleTerm(): string {
    if (this.store === undefined) {
      return '';
    }
    return this.store.getSync(KEY_SELECTED_SCHEDULE_TERM, '') as string;
  }

  saveSelectedScheduleTerm(termCode: string): void {
    if (this.store === undefined) {
      return;
    }
    this.store.putSync(KEY_SELECTED_SCHEDULE_TERM, termCode);
    this.store.flushSync();
  }

  resolveUnknownCourseTerms(): boolean {
    const semester: SemesterInfo = this.loadSemester();
    if (semester.termCode.length === 0 || semester.termCode === 'UNKNOWN_TERM') {
      const inferred: GradeInfo | undefined = this.inferCurrentTermFromGrades();
      if (inferred === undefined) {
        return false;
      }
      semester.termCode = inferred.termCode;
      semester.termLabel = inferred.termLabel;
    }
    const courses: Array<CourseInfo> = this.loadCourses();
    let changed: boolean = false;
    for (let i = 0; i < courses.length; i++) {
      if (courses[i].termCode.length === 0 || courses[i].termCode === 'UNKNOWN_TERM') {
        courses[i].termCode = semester.termCode;
        courses[i].termLabel = semester.termLabel;
        courses[i].id = semester.termCode + '|' +
          (courses[i].courseCode.length > 0 ?
            courses[i].courseCode + '|' + courses[i].section :
            courses[i].name + '|' + courses[i].teacher);
        changed = true;
      }
    }
    if (!changed) {
      return false;
    }
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.courses = courses;
    input.semester = semester;
    input.replaceCourses = true;
    input.courseTermsReplaced = ['UNKNOWN_TERM', semester.termCode];
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  private inferCurrentTermFromGrades(): GradeInfo | undefined {
    const now: Date = new Date();
    const month: number = now.getMonth() + 1;
    const startYear: number = month >= 8 ? now.getFullYear() : now.getFullYear() - 1;
    const endYear: number = startYear + 1;
    const semesterNumber: string = month >= 8 || month === 1 ? '1' : '2';
    const academicYear: string = startYear.toString() + '-' + endYear.toString();
    const grades: Array<GradeInfo> = this.loadGrades();
    return grades.find((grade: GradeInfo): boolean => {
      if (grade.termCode.length === 0 || grade.termCode === 'UNKNOWN_TERM' ||
          !grade.termLabel.includes(academicYear)) {
        return false;
      }
      return grade.termLabel.includes('-' + semesterNumber) ||
        (semesterNumber === '1' &&
          (grade.termLabel.includes('第一学期') || grade.termLabel.includes('秋'))) ||
        (semesterNumber === '2' &&
          (grade.termLabel.includes('第二学期') || grade.termLabel.includes('春')));
    });
  }

  saveExams(exams: Array<ExamInfo>): void {
    if (this.store === undefined) { return; }
    this.store.putSync('exams_json', JSON.stringify(exams));
    this.store.flushSync();
  }

  loadExams(): Array<ExamInfo> {
    if (this.store === undefined) { return []; }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const snapshotExams: Object | undefined = snapshot?.['exams'];
    if (snapshotExams !== undefined && Array.isArray(snapshotExams)) {
      return this.parseExamArray(snapshotExams as Array<Object>);
    }
    const j = this.store.getSync('exams_json', '') as string;
    if (j.length === 0) { return []; }
    const raw: Object = JSON.parse(j);
    if (!Array.isArray(raw)) { return []; }
    return this.parseExamArray(raw as Array<Object>);
  }

  private parseExamArray(arr: Array<Object>): Array<ExamInfo> {
    const r: Array<ExamInfo> = [];
    for (let i = 0; i < arr.length; i++) {
      const it: Record<string, Object> = arr[i] as Record<string, Object>;
      const e: ExamInfo = new ExamInfo();
      e.id = (it['id'] as string) ?? ('exam_' + i);
      e.courseName = (it['courseName'] as string) ?? '';
      e.courseCode = (it['courseCode'] as string) ?? '';
      e.examDate = (it['examDate'] as string) ?? '';
      e.examTime = (it['examTime'] as string) ?? '';
      e.scheduleText = (it['scheduleText'] as string) ?? '';
      e.examType = (it['examType'] as string) ?? ''; e.examMode = (it['examMode'] as string) ?? '';
      e.status = (it['status'] as string) ?? ''; e.remark = (it['remark'] as string) ?? '';
      e.registration = (it['registration'] as string) ?? '';
      e.detail = (it['detail'] as string) ?? ''; e.detailPath = (it['detailPath'] as string) ?? '';
      e.rawText = (it['rawText'] as string) ?? '';
      e.termCode = (it['termCode'] as string) ?? ''; e.termLabel = (it['termLabel'] as string) ?? '';
      e.campus = (it['campus'] as string) ?? ''; e.building = (it['building'] as string) ?? '';
      e.classroom = (it['classroom'] as string) ?? '';
      e.locationText = (it['locationText'] as string) ?? e.classroom;
      e.seatNo = (it['seatNo'] as string) ?? ''; e.syncedAt = (it['syncedAt'] as number) ?? Date.now();
      e.sourceUrl = (it['sourceUrl'] as string) ?? '';
      r.push(e);
    }
    return r;
  }

  saveGrades(grades: Array<GradeInfo>): void {
    if (this.store === undefined) { return; }
    this.store.putSync('grades_json', JSON.stringify(grades));
    this.store.flushSync();
  }

  loadGrades(): Array<GradeInfo> {
    if (this.store === undefined) { return []; }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const snapshotGrades: Object | undefined = snapshot?.['grades'];
    if (snapshotGrades !== undefined && Array.isArray(snapshotGrades)) {
      return this.parseGradeArray(snapshotGrades as Array<Object>);
    }
    const j = this.store.getSync('grades_json', '') as string;
    if (j.length === 0) { return []; }
    const raw: Object = JSON.parse(j);
    if (!Array.isArray(raw)) { return []; }
    return this.parseGradeArray(raw as Array<Object>);
  }

  loadGradeTermSummaries(): Array<GradeTermSummary> {
    if (this.store === undefined) { return []; }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const summariesRaw: Object | undefined = snapshot?.['gradeTermSummaries'];
    if (summariesRaw === undefined || !Array.isArray(summariesRaw)) { return []; }
    return this.parseGradeTermSummaries(summariesRaw as Array<Object>);
  }

  loadGradeTerms(): Array<GradeTermOption> {
    if (this.store === undefined) { return []; }
    const snapshot: Record<string, Object> | undefined = this.loadSnapshot();
    const termsRaw: Object | undefined = snapshot?.['gradeTerms'];
    if (termsRaw === undefined || !Array.isArray(termsRaw)) { return []; }
    const terms: Array<GradeTermOption> = [];
    const rawTerms: Array<Object> = termsRaw as Array<Object>;
    for (let i = 0; i < rawTerms.length; i++) {
      const raw: Record<string, Object> = rawTerms[i] as Record<string, Object>;
      const term: GradeTermOption = new GradeTermOption();
      const rawCode: string = (raw['termCode'] as string) ?? '';
      const rawLabel: string = (raw['termLabel'] as string) ?? rawCode;
      term.termCode = GradeTermOrder.canonical(rawCode, rawLabel);
      term.termLabel = GradeTermOrder.normalize(rawLabel.length > 0 ? rawLabel : rawCode);
      term.selected = (raw['selected'] as boolean) ?? false;
      if (term.termCode.length > 0) {
        const existing: GradeTermOption | undefined = terms.find(
          (item: GradeTermOption): boolean => item.termCode === term.termCode);
        if (existing === undefined) {
          terms.push(term);
        } else {
          existing.selected = existing.selected || term.selected;
        }
      }
    }
    return terms;
  }

  private parseGradeArray(arr: Array<Object>): Array<GradeInfo> {
    const r: Array<GradeInfo> = [];
    for (let i = 0; i < arr.length; i++) {
      const it: Record<string, Object> = arr[i] as Record<string, Object>;
      const g: GradeInfo = new GradeInfo();
      g.id = (it['id'] as string) ?? ('grade_' + i); g.courseName = (it['courseName'] as string) ?? '';
      g.courseCode = (it['courseCode'] as string) ?? '';
      g.credit = (it['credit'] as string) ?? ''; g.score = (it['score'] as string) ?? '';
      g.scoreNumeric = (it['scoreNumeric'] as number) ?? -1;
      g.bonusScore = (it['bonusScore'] as string) ?? '';
      g.gradePoint = (it['gradePoint'] as string) ?? ''; g.teacher = (it['teacher'] as string) ?? '';
      g.examType = (it['examType'] as string) ?? ''; g.gradeStatus = (it['gradeStatus'] as string) ?? '';
      g.remark = (it['remark'] as string) ?? ''; g.detail = (it['detail'] as string) ?? '';
      g.detailPath = (it['detailPath'] as string) ?? '';
      g.detailTitle = (it['detailTitle'] as string) ?? '';
      g.detailLoadedAt = (it['detailLoadedAt'] as number) ?? 0;
      const detailFieldsRaw: Object | undefined = it['detailFields'];
      if (detailFieldsRaw !== undefined && Array.isArray(detailFieldsRaw)) {
        const fields: Array<Object> = detailFieldsRaw as Array<Object>;
        for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
          const rawField: Record<string, Object> = fields[fieldIndex] as Record<string, Object>;
          const field: GradeDetailField = new GradeDetailField();
          field.label = (rawField['label'] as string) ?? '';
          field.value = (rawField['value'] as string) ?? '';
          if (field.label.length > 0 && field.value.length > 0) {
            g.detailFields.push(field);
          }
        }
      }
      const detailTablesRaw: Object | undefined = it['detailTables'];
      if (detailTablesRaw !== undefined && Array.isArray(detailTablesRaw)) {
        const tables: Array<Object> = detailTablesRaw as Array<Object>;
        for (let tableIndex = 0; tableIndex < tables.length; tableIndex++) {
          const rawTable: Record<string, Object> = tables[tableIndex] as Record<string, Object>;
          const table: GradeDetailTable = new GradeDetailTable();
          table.title = (rawTable['title'] as string) ?? '';
          const headersRaw: Object | undefined = rawTable['headers'];
          if (headersRaw !== undefined && Array.isArray(headersRaw)) {
            table.headers = headersRaw as Array<string>;
          }
          const rowsRaw: Object | undefined = rawTable['rows'];
          if (rowsRaw !== undefined && Array.isArray(rowsRaw)) {
            const rows: Array<Object> = rowsRaw as Array<Object>;
            for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
              if (Array.isArray(rows[rowIndex])) {
                table.rows.push(rows[rowIndex] as Array<string>);
              }
            }
          }
          if (table.rows.length > 0) {
            g.detailTables.push(table);
          }
        }
      }
      const rawTermCode: string = (it['termCode'] as string) ?? '';
      const rawTermLabel: string = (it['termLabel'] as string) ?? rawTermCode;
      g.termCode = GradeTermOrder.canonical(rawTermCode, rawTermLabel);
      g.termLabel = GradeTermOrder.normalize(rawTermLabel.length > 0 ? rawTermLabel : rawTermCode);
      g.academicYear = (it['academicYear'] as string) ?? '';
      g.semester = (it['semester'] as string) ?? '';
      g.sourceUrl = (it['sourceUrl'] as string) ?? '';
      g.syncedAt = (it['syncedAt'] as number) ?? Date.now();
      const duplicate: GradeInfo | undefined = r.find(
        (item: GradeInfo): boolean => item.getListDedupeKey() === g.getListDedupeKey());
      if (duplicate === undefined) {
        r.push(g);
      } else {
        if (!duplicate.hasDetailData() && g.hasDetailData()) {
          duplicate.detailTitle = g.detailTitle;
          duplicate.detailFields = g.detailFields;
          duplicate.detailTables = g.detailTables;
          duplicate.detailLoadedAt = g.detailLoadedAt;
        }
        if (duplicate.detailPath.length === 0 && g.detailPath.length > 0) {
          duplicate.detailPath = g.detailPath;
        }
      }
    }
    return r;
  }

  private parseGradeTermSummaries(arr: Array<Object>): Array<GradeTermSummary> {
    const result: Array<GradeTermSummary> = [];
    for (let i = 0; i < arr.length; i++) {
      const raw: Record<string, Object> = arr[i] as Record<string, Object>;
      const summary: GradeTermSummary = new GradeTermSummary();
      summary.termCode = (raw['termCode'] as string) ?? '';
      summary.termLabel = (raw['termLabel'] as string) ?? '';
      summary.collegeRank = (raw['collegeRank'] as number) ?? -1;
      summary.collegeTotal = (raw['collegeTotal'] as number) ?? -1;
      summary.collegePercentile = (raw['collegePercentile'] as string) ?? '';
      if (summary.termCode.length > 0 && summary.hasCollegeRanking()) {
        result.push(summary);
      }
    }
    return result;
  }

  loadMailSnapshot(): MailSnapshot {
    if (this.store === undefined) {
      return new MailSnapshot();
    }
    const activeSlot: string = this.store.getSync(KEY_ACTIVE_MAIL_SNAPSHOT, '') as string;
    if (activeSlot === 'A' || activeSlot === 'B') {
      const activeKey: string = activeSlot === 'A' ? KEY_MAIL_SNAPSHOT_A : KEY_MAIL_SNAPSHOT_B;
      const fallbackKey: string = activeSlot === 'A' ? KEY_MAIL_SNAPSHOT_B : KEY_MAIL_SNAPSHOT_A;
      const active: MailSnapshot | undefined = this.loadMailSnapshotKey(activeKey);
      if (active !== undefined) {
        return active;
      }
      const fallback: MailSnapshot | undefined = this.loadMailSnapshotKey(fallbackKey);
      if (fallback !== undefined) {
        return fallback;
      }
    }
    const slotA: MailSnapshot | undefined = this.loadMailSnapshotKey(KEY_MAIL_SNAPSHOT_A);
    if (slotA !== undefined) {
      return slotA;
    }
    const slotB: MailSnapshot | undefined = this.loadMailSnapshotKey(KEY_MAIL_SNAPSHOT_B);
    return slotB !== undefined ? slotB : new MailSnapshot();
  }

  commitMailSnapshot(incoming: MailSnapshot): boolean {
    if (this.store === undefined ||
        (incoming.folders.length === 0 && incoming.messages.length === 0)) {
      return false;
    }
    const previous: MailSnapshot = this.loadMailSnapshot();
    const next: MailSnapshot = new MailSnapshot();
    next.folders = this.mergeMailFolders(previous.folders, incoming.folders);
    next.messages = this.limitMessagesPerFolder(
      this.mergeMailMessages(previous.messages, incoming.messages), 30);
    next.details = previous.details.slice(0, 100);
    next.updatedAt = incoming.updatedAt > 0 ? incoming.updatedAt : Date.now();
    next.sourcePage = incoming.sourcePage;
    try {
      const activeSlot: string = this.store.getSync(KEY_ACTIVE_MAIL_SNAPSHOT, 'A') as string;
      const nextSlot: string = activeSlot === 'A' ? 'B' : 'A';
      const nextKey: string = nextSlot === 'A' ? KEY_MAIL_SNAPSHOT_A : KEY_MAIL_SNAPSHOT_B;
      this.store.putSync(nextKey, JSON.stringify(next));
      this.store.flushSync();
      this.store.putSync(KEY_ACTIVE_MAIL_SNAPSHOT, nextSlot);
      this.store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  saveMailDetail(detail: MailDetail): boolean {
    if (detail.messageKey.length === 0 || !detail.hasContent()) {
      return false;
    }
    const snapshot: MailSnapshot = this.loadMailSnapshot();
    const existingIndex: number = snapshot.details.findIndex(
      (item: MailDetail): boolean => item.messageKey === detail.messageKey);
    if (existingIndex >= 0) {
      snapshot.details[existingIndex] = detail;
    } else {
      snapshot.details.unshift(detail);
    }
    snapshot.details = snapshot.details.slice(0, 100);
    if (this.store === undefined) {
      return false;
    }
    try {
      const activeSlot: string = this.store.getSync(KEY_ACTIVE_MAIL_SNAPSHOT, 'A') as string;
      const nextSlot: string = activeSlot === 'A' ? 'B' : 'A';
      const nextKey: string = nextSlot === 'A' ? KEY_MAIL_SNAPSHOT_A : KEY_MAIL_SNAPSHOT_B;
      this.store.putSync(nextKey, JSON.stringify(snapshot));
      this.store.flushSync();
      this.store.putSync(KEY_ACTIVE_MAIL_SNAPSHOT, nextSlot);
      this.store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  private loadMailSnapshotKey(key: string): MailSnapshot | undefined {
    if (this.store === undefined) {
      return undefined;
    }
    try {
      const json: string = this.store.getSync(key, '') as string;
      if (json.length === 0) {
        return undefined;
      }
      const raw: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (!Array.isArray(raw['folders']) || !Array.isArray(raw['messages']) ||
          !Array.isArray(raw['details'])) {
        return undefined;
      }
      return this.parseMailSnapshot(raw);
    } catch (_) {
      return undefined;
    }
  }

  private limitMessagesPerFolder(messages: Array<MailSummary>, maximum: number): Array<MailSummary> {
    const result: Array<MailSummary> = [];
    const counts: Record<string, number> = {};
    for (let i = 0; i < messages.length; i++) {
      const folderId: string = messages[i].folderId.length > 0 ? messages[i].folderId : 'default';
      const current: number = counts[folderId] ?? 0;
      if (current >= maximum) {
        continue;
      }
      counts[folderId] = current + 1;
      result.push(messages[i]);
    }
    return result;
  }

  private mergeMailFolders(
    previous: Array<MailFolder>,
    incoming: Array<MailFolder>
  ): Array<MailFolder> {
    const result: Array<MailFolder> = incoming.slice(0);
    for (let i = 0; i < previous.length; i++) {
      if (result.find((item: MailFolder): boolean => item.id === previous[i].id) === undefined) {
        result.push(previous[i]);
      }
    }
    return result;
  }

  private mergeMailMessages(
    previous: Array<MailSummary>,
    incoming: Array<MailSummary>
  ): Array<MailSummary> {
    const result: Array<MailSummary> = incoming.slice(0);
    for (let i = 0; i < previous.length; i++) {
      const key: string = previous[i].businessKey();
      if (result.find((item: MailSummary): boolean => item.businessKey() === key) === undefined) {
        result.push(previous[i]);
      }
    }
    return result;
  }

  commitSnapshot(input: SnapshotCommitInput): SyncResult {
    if (this.store === undefined) {
      return { success: false, courseCount: 0, errorMessage: '存储未初始化' };
    }
    const currentCourses: Array<CourseInfo> = this.loadCourses();
    const nextCourses: Array<CourseInfo> = input.replaceCourses ?
      (input.courseTermsReplaced.length > 0 ?
        this.mergeCoursesByTerm(currentCourses, input.courses, input.courseTermsReplaced) : input.courses) :
      currentCourses;
    if (input.replaceCourses) {
      const validation: SyncResult = this.validateCourses(nextCourses);
      if (!validation.success) {
        return validation;
      }
    }
    const nextSemester: SemesterInfo = input.replaceCourses ? input.semester : this.loadSemester();
    const currentExams: Array<ExamInfo> = this.loadExams();
    const nextExams: Array<ExamInfo> = input.replaceExams ?
      (input.examTermsReplaced.length > 0 ?
        this.mergeExamsByTerm(currentExams, input.exams, input.examTermsReplaced) : input.exams) :
      currentExams;
    const currentGrades: Array<GradeInfo> = this.loadGrades();
    const nextGrades: Array<GradeInfo> = input.replaceGrades ?
      this.mergeGradesByTerm(currentGrades, input.grades, input.gradeTermsReplaced) : currentGrades;
    if (input.replaceExams) {
      const validation: SyncResult = this.validateExams(nextExams, nextCourses.length);
      if (!validation.success) {
        return validation;
      }
    }
    if (input.replaceGrades) {
      const validation: SyncResult = this.validateGrades(nextGrades, nextCourses.length);
      if (!validation.success) {
        return validation;
      }
    }
    const currentGradeTermSummaries: Array<GradeTermSummary> = this.loadGradeTermSummaries();
    const nextGradeTermSummaries: Array<GradeTermSummary> = input.replaceGradeTermSummaries ?
      this.mergeGradeTermSummaries(
        currentGradeTermSummaries, input.gradeTermSummaries, input.gradeTermsReplaced) :
      currentGradeTermSummaries;
    const nextGradeTerms: Array<GradeTermOption> = input.replaceGradeTerms ?
      input.gradeTerms : this.loadGradeTerms();
    const nextProfile: StudentProfile = input.replaceProfile ? input.profile : this.loadProfile();
    const nextProgress: AcademicProgress = input.replaceProgress ? input.progress : this.loadProgress();
    const nextCalendar: CampusCalendar = input.replaceCalendar ? input.calendar : this.loadCalendar();
    const nextModuleRecords: Array<ModuleSyncRecord> = input.replaceModuleRecords ?
      input.moduleRecords : this.loadModuleSyncRecords();
    const previousState: SyncState = this.loadSyncState();
    const currentEvents: Array<ChangeEvent> = input.replaceChangeEvents ?
      input.changeEvents : this.loadChangeEvents();
    const generatedEvents: Array<ChangeEvent> = previousState.hasData() ?
      this.buildChangeEvents(
        currentCourses,
        nextCourses,
        currentExams,
        nextExams,
        currentGrades,
        nextGrades,
        input
      ) : [];
    const nextEvents: Array<ChangeEvent> = input.replaceChangeEvents ?
      currentEvents.slice(0, 100) : generatedEvents.concat(currentEvents).slice(0, 100);
    const syncState: SyncState = new SyncState();
    syncState.courseCount = nextCourses.length;
    syncState.examCount = nextExams.length;
    syncState.gradeCount = nextGrades.length;
    syncState.sourcePage = input.preserveSyncMetadata ? previousState.sourcePage : input.sourcePage;
    syncState.dataVersion = CURRENT_DATA_VERSION;
    syncState.semester = nextSemester;
    syncState.lastSyncTime = input.preserveSyncMetadata ? previousState.lastSyncTime : Date.now();
    syncState.lastFullTimetableSyncTime = input.preserveSyncMetadata ?
      previousState.lastFullTimetableSyncTime :
      (input.fullTimetableSyncCompleted ? Date.now() : previousState.lastFullTimetableSyncTime);
    syncState.lastFullGradeSyncTime = input.preserveSyncMetadata ?
      previousState.lastFullGradeSyncTime :
      (input.fullGradeSyncCompleted ? Date.now() : previousState.lastFullGradeSyncTime);
    syncState.lastOutcome = input.preserveSyncMetadata ? previousState.lastOutcome : input.lastOutcome;
    syncState.lastErrors = input.preserveSyncMetadata ? previousState.lastErrors : input.errors.slice(0);
    const snapshot: Record<string, Object> = {
      'version': CURRENT_DATA_VERSION,
      'committedAt': Date.now(),
      'courses': nextCourses,
      'semester': nextSemester,
      'exams': nextExams,
      'grades': nextGrades,
      'gradeTerms': nextGradeTerms,
      'gradeTermSummaries': nextGradeTermSummaries,
      'profile': nextProfile,
      'progress': nextProgress,
      'calendar': nextCalendar,
      'moduleRecords': nextModuleRecords,
      'changeEvents': nextEvents,
      'syncState': syncState
    };
    try {
      const json: string = JSON.stringify(snapshot);
      const activeSlot: string = this.store.getSync(KEY_ACTIVE_SNAPSHOT, 'A') as string;
      const nextSlot: string = activeSlot === 'A' ? 'B' : 'A';
      const nextKey: string = nextSlot === 'A' ? KEY_SNAPSHOT_A : KEY_SNAPSHOT_B;
      this.store.putSync(nextKey, json);
      this.store.flushSync();
      this.store.putSync(KEY_ACTIVE_SNAPSHOT, nextSlot);
      this.store.flushSync();
      this.store.putSync(KEY_SNAPSHOT, '');
      this.store.putSync(KEY_SNAPSHOT_TEMP, '');
      this.store.putSync(KEY_GRADE_CHECKPOINT, '');
      this.store.putSync(KEY_DATA_VERSION, CURRENT_DATA_VERSION);
      this.store.flushSync();
      return { success: true, courseCount: nextCourses.length, errorMessage: '' };
    } catch (_) {
      return { success: false, courseCount: currentCourses.length, errorMessage: '本地快照提交失败，已保留旧数据' };
    }
  }

  saveGradeDetail(gradeId: string, detail: GradeDetailData): boolean {
    if (gradeId.length === 0 || !detail.hasContent()) {
      return false;
    }
    const grades: Array<GradeInfo> = this.loadGrades();
    let updated: boolean = false;
    const terms: Array<string> = [];
    for (let i = 0; i < grades.length; i++) {
      if (terms.find((term: string): boolean => term === grades[i].termCode) === undefined) {
        terms.push(grades[i].termCode);
      }
      if (grades[i].id === gradeId) {
        grades[i].detailTitle = detail.title;
        grades[i].detailFields = detail.fields;
        grades[i].detailTables = detail.tables;
        grades[i].detailLoadedAt = Date.now();
        updated = true;
      }
    }
    if (!updated) {
      return false;
    }
    const input: SnapshotCommitInput = new SnapshotCommitInput();
    input.replaceGrades = true;
    input.grades = grades;
    input.gradeTermsReplaced = terms;
    input.preserveSyncMetadata = true;
    return this.commitSnapshot(input).success;
  }

  saveGradeCheckpoint(
    grades: Array<GradeInfo>,
    completedTermCodes: Array<string>,
    completedTerms: number,
    totalTerms: number,
    gradeTermSummaries: Array<GradeTermSummary> = []
  ): boolean {
    if (this.store === undefined) {
      return false;
    }
    try {
      const checkpoint: Record<string, Object> = {
        'version': GRADE_CHECKPOINT_VERSION,
        'grades': grades,
        'gradeTermSummaries': gradeTermSummaries,
        'completedTermCodes': completedTermCodes,
        'completedTerms': completedTerms,
        'totalTerms': totalTerms,
        'updatedAt': Date.now()
      };
      this.store.putSync(KEY_GRADE_CHECKPOINT, JSON.stringify(checkpoint));
      this.store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  loadGradeCheckpoint(): GradeCheckpoint | undefined {
    if (this.store === undefined) {
      return undefined;
    }
    try {
      const json: string = this.store.getSync(KEY_GRADE_CHECKPOINT, '') as string;
      if (json.length === 0) {
        return undefined;
      }
      const raw: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (((raw['version'] as number) ?? 0) !== GRADE_CHECKPOINT_VERSION) {
        return undefined;
      }
      const checkpoint: GradeCheckpoint = new GradeCheckpoint();
      checkpoint.version = GRADE_CHECKPOINT_VERSION;
      const gradesRaw: Object | undefined = raw['grades'];
      if (gradesRaw !== undefined && Array.isArray(gradesRaw)) {
        checkpoint.grades = this.parseGradeArray(gradesRaw as Array<Object>);
      }
      const summariesRaw: Object | undefined = raw['gradeTermSummaries'];
      if (summariesRaw !== undefined && Array.isArray(summariesRaw)) {
        checkpoint.gradeTermSummaries = this.parseGradeTermSummaries(summariesRaw as Array<Object>);
      }
      const codesRaw: Object | undefined = raw['completedTermCodes'];
      if (codesRaw !== undefined && Array.isArray(codesRaw)) {
        checkpoint.completedTermCodes = codesRaw as Array<string>;
      }
      checkpoint.completedTerms = (raw['completedTerms'] as number) ?? 0;
      checkpoint.totalTerms = (raw['totalTerms'] as number) ?? 0;
      checkpoint.updatedAt = (raw['updatedAt'] as number) ?? 0;
      return checkpoint;
    } catch (_) {
      return undefined;
    }
  }

  private parseCoursesJson(json: string): Array<CourseInfo> {
    const raw: Object = JSON.parse(json);
    if (Array.isArray(raw)) {
      const arr: Array<Object> = raw as Array<Object>;
      return this.parseCourseArray(arr);
    }
    const wrapper: Record<string, Object> = raw as Record<string, Object>;
    const coursesArr: Object | undefined = wrapper['courses'];
    if (coursesArr !== undefined && Array.isArray(coursesArr)) {
      return this.parseCourseArray(coursesArr as Array<Object>);
    }
    return [];
  }

  private parseCourseArray(arr: Array<Object>): Array<CourseInfo> {
    const result: Array<CourseInfo> = [];
    for (let i = 0; i < arr.length; i++) {
      const item: Record<string, Object> = arr[i] as Record<string, Object>;
      const course: CourseInfo = new CourseInfo();
      course.id = (item['id'] as string) ?? ('c_' + i);
      course.name = (item['name'] as string) ?? '';
      course.courseCode = (item['courseCode'] as string) ?? '';
      course.section = (item['section'] as string) ?? '';
      course.teacher = (item['teacher'] as string) ?? '';
      course.courseType = (item['courseType'] as string) ?? (item['type'] as string) ?? '';
      course.isTemporary = (item['isTemporary'] as boolean) ?? false;
      course.isCancelled = (item['isCancelled'] as boolean) ?? false;
      course.termCode = (item['termCode'] as string) ?? '';
      course.termLabel = (item['termLabel'] as string) ?? '';
      course.sourceUrl = (item['sourceUrl'] as string) ?? '';
      course.syncedAt = (item['syncedAt'] as number) ?? (item['updateTime'] as number) ?? 0;
      course.updateTime = (item['updateTime'] as number) ?? Date.now();
      const sessionsRaw: Object | undefined = item['sessions'];
      if (sessionsRaw !== undefined && Array.isArray(sessionsRaw)) {
        const sessionsArr: Array<Object> = sessionsRaw as Array<Object>;
        for (let j = 0; j < sessionsArr.length; j++) {
          course.sessions.push(this.parseSession(sessionsArr[j] as Record<string, Object>));
        }
      }
      result.push(course);
    }
    return result;
  }

  private parseSession(sItem: Record<string, Object>): CourseSession {
    const session: CourseSession = new CourseSession();
    session.dayOfWeek = (sItem['dayOfWeek'] as number) ?? 0;
    session.startPeriod = (sItem['startPeriod'] as number) ?? 0;
    session.endPeriod = (sItem['endPeriod'] as number) ?? 0;
    session.startWeek = (sItem['startWeek'] as number) ?? 0;
    session.endWeek = (sItem['endWeek'] as number) ?? 0;
    session.weekType = (sItem['weekType'] as string) ?? 'every';
    const weekNumbersRaw: Object | undefined = sItem['weekNumbers'];
    if (weekNumbersRaw !== undefined && Array.isArray(weekNumbersRaw)) {
      session.weekNumbers = weekNumbersRaw as Array<number>;
    }
    session.discontinuousWeeks = (sItem['discontinuousWeeks'] as string) ?? '';
    session.classroom = (sItem['classroom'] as string) ?? (sItem['locationText'] as string) ?? '';
    session.campus = (sItem['campus'] as string) ?? '';
    session.building = (sItem['building'] as string) ?? '';
    session.room = (sItem['room'] as string) ?? '';
    session.locationText = (sItem['locationText'] as string) ?? '';
    session.timeRange = (sItem['timeRange'] as string) ?? '';
    session.weeksRaw = (sItem['weeksRaw'] as string) ?? '';
    return session;
  }

  private parseSyncStateJson(json: string): SyncState {
    const raw: Object = JSON.parse(json);
    return this.parseSyncStateObj(raw as Record<string, Object>);
  }

  private parseSyncStateObj(item: Record<string, Object>): SyncState {
    const state: SyncState = new SyncState();
    state.lastSyncTime = (item['lastSyncTime'] as number) ?? 0;
    state.courseCount = (item['courseCount'] as number) ?? 0;
    state.examCount = (item['examCount'] as number) ?? 0;
    state.gradeCount = (item['gradeCount'] as number) ?? 0;
    state.sourcePage = (item['sourcePage'] as string) ?? '';
    state.dataVersion = (item['dataVersion'] as number) ?? 1;
    state.lastFullTimetableSyncTime = (item['lastFullTimetableSyncTime'] as number) ?? 0;
    state.lastFullGradeSyncTime = (item['lastFullGradeSyncTime'] as number) ?? 0;
    state.lastOutcome = (item['lastOutcome'] as string) ?? '';
    const errorsRaw: Object | undefined = item['lastErrors'];
    if (errorsRaw !== undefined && Array.isArray(errorsRaw)) {
      state.lastErrors = (errorsRaw as Array<string>).slice(0);
    }
    const semRaw: Object | undefined = item['semester'];
    if (semRaw !== undefined) {
      state.semester = this.parseSemesterObj(semRaw as Record<string, Object>);
    }
    return state;
  }

  private loadSnapshot(): Record<string, Object> | undefined {
    if (this.store === undefined) {
      return undefined;
    }
    const activeSlot: string = this.store.getSync(KEY_ACTIVE_SNAPSHOT, '') as string;
    if (activeSlot === 'A' || activeSlot === 'B') {
      const activeKey: string = activeSlot === 'A' ? KEY_SNAPSHOT_A : KEY_SNAPSHOT_B;
      const fallbackKey: string = activeSlot === 'A' ? KEY_SNAPSHOT_B : KEY_SNAPSHOT_A;
      const active: Record<string, Object> | undefined = this.loadSnapshotKey(activeKey);
      if (active !== undefined) {
        return active;
      }
      const fallback: Record<string, Object> | undefined = this.loadSnapshotKey(fallbackKey);
      if (fallback !== undefined) {
        return fallback;
      }
    } else {
      const slotA: Record<string, Object> | undefined = this.loadSnapshotKey(KEY_SNAPSHOT_A);
      const slotB: Record<string, Object> | undefined = this.loadSnapshotKey(KEY_SNAPSHOT_B);
      if (slotA !== undefined && slotB !== undefined) {
        const timeA: number = (slotA['committedAt'] as number) ?? 0;
        const timeB: number = (slotB['committedAt'] as number) ?? 0;
        return timeA >= timeB ? slotA : slotB;
      }
      if (slotA !== undefined) {
        return slotA;
      }
      if (slotB !== undefined) {
        return slotB;
      }
    }
    return this.loadSnapshotKey(KEY_SNAPSHOT);
  }

  private loadSnapshotKey(key: string): Record<string, Object> | undefined {
    if (this.store === undefined) {
      return undefined;
    }
    try {
      const json: string = this.store.getSync(key, '') as string;
      if (json.length === 0) {
        return undefined;
      }
      const snapshot: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if ((key === KEY_SNAPSHOT_A || key === KEY_SNAPSHOT_B) &&
          !this.isSnapshotStructurallyValid(snapshot)) {
        return undefined;
      }
      return snapshot;
    } catch (_) {
      return undefined;
    }
  }

  private isSnapshotStructurallyValid(snapshot: Record<string, Object>): boolean {
    return typeof snapshot['version'] === 'number' &&
      typeof snapshot['committedAt'] === 'number' &&
      Array.isArray(snapshot['courses']) &&
      Array.isArray(snapshot['exams']) &&
      Array.isArray(snapshot['grades']) &&
      Array.isArray(snapshot['gradeTerms']) &&
      Array.isArray(snapshot['gradeTermSummaries']) &&
      snapshot['semester'] !== undefined &&
      snapshot['syncState'] !== undefined;
  }

  private parseSemesterJson(json: string): SemesterInfo {
    const raw: Object = JSON.parse(json);
    return this.parseSemesterObj(raw as Record<string, Object>);
  }

  private parseSemesterObj(raw: Record<string, Object>): SemesterInfo {
    const semester: SemesterInfo = new SemesterInfo();
    semester.academicYear = (raw['academicYear'] as string) ?? '';
    semester.semester = (raw['semester'] as string) ?? '';
    semester.startDate = (raw['startDate'] as string) ?? '';
    semester.currentTeachingWeek = (raw['currentTeachingWeek'] as number) ?? 0;
    semester.totalWeeks = (raw['totalWeeks'] as number) ?? 20;
    semester.termCode = (raw['termCode'] as string) ?? '';
    semester.termLabel = (raw['termLabel'] as string) ?? '';
    return semester;
  }

  private parseProfile(raw: Record<string, Object>): StudentProfile {
    const profile: StudentProfile = new StudentProfile();
    profile.studentName = (raw['studentName'] as string) ?? '';
    profile.college = (raw['college'] as string) ?? '';
    profile.major = (raw['major'] as string) ?? '';
    profile.className = (raw['className'] as string) ?? '';
    profile.educationLevel = (raw['educationLevel'] as string) ?? '';
    profile.studentStatus = (raw['studentStatus'] as string) ?? '';
    profile.enrollmentYear = (raw['enrollmentYear'] as string) ?? '';
    profile.expectedGraduation = (raw['expectedGraduation'] as string) ?? '';
    profile.trainingMode = (raw['trainingMode'] as string) ?? '';
    profile.syncedAt = (raw['syncedAt'] as number) ?? 0;
    profile.sourcePage = (raw['sourcePage'] as string) ?? '';
    profile.fields = this.parseProfileFields(raw['fields']);
    return profile;
  }

  private parseProgress(raw: Record<string, Object>): AcademicProgress {
    const progress: AcademicProgress = new AcademicProgress();
    progress.requiredCredits = (raw['requiredCredits'] as number) ?? -1;
    progress.earnedCredits = (raw['earnedCredits'] as number) ?? -1;
    progress.failedCourseCount = (raw['failedCourseCount'] as number) ?? 0;
    progress.officialSummary = (raw['officialSummary'] as boolean) ?? false;
    progress.syncedAt = (raw['syncedAt'] as number) ?? 0;
    progress.sourcePage = (raw['sourcePage'] as string) ?? '';
    progress.fields = this.parseProfileFields(raw['fields']).filter(
      (field: ProfileField): boolean => this.isAcademicProgressField(field));
    const coursesRaw: Object | undefined = raw['courses'];
    if (coursesRaw !== undefined && Array.isArray(coursesRaw)) {
      const courses: Array<Object> = coursesRaw as Array<Object>;
      for (let i = 0; i < courses.length; i++) {
        const item: Record<string, Object> = courses[i] as Record<string, Object>;
        const course: ProgressCourse = new ProgressCourse();
        course.courseName = (item['courseName'] as string) ?? '';
        course.credit = (item['credit'] as number) ?? 0;
        course.score = (item['score'] as string) ?? '';
        course.status = (item['status'] as string) ?? '';
        course.category = (item['category'] as string) ?? '';
        if (course.courseName.length > 0) {
          progress.courses.push(course);
        }
      }
    }
    return progress;
  }

  private parseProfileFields(raw: Object | undefined): Array<ProfileField> {
    const result: Array<ProfileField> = [];
    if (raw === undefined || !Array.isArray(raw)) {
      return result;
    }
    const fields: Array<Object> = raw as Array<Object>;
    for (let i = 0; i < fields.length; i++) {
      const item: Record<string, Object> = fields[i] as Record<string, Object>;
      const field: ProfileField = new ProfileField();
      field.label = (item['label'] as string) ?? '';
      field.value = (item['value'] as string) ?? '';
      field.group = (item['group'] as string) ?? '';
      if (field.label.length > 0 && field.value.length > 0 &&
          !this.isSensitiveProfileField(field.label)) {
        result.push(field);
      }
    }
    return result;
  }

  private isSensitiveProfileField(label: string): boolean {
    const sensitive: Array<string> = [
      '学号', '身份证', '证件', '电话', '手机', '邮箱', '住址', '地址', '家庭', '照片'
    ];
    return sensitive.find((item: string): boolean => label.includes(item)) !== undefined;
  }

  private isAcademicProgressField(field: ProfileField): boolean {
    if (field.label.match(new RegExp('^\\d+$')) !== null) {
      return false;
    }
    const text: string = field.label + ' ' + field.group;
    const keywords: Array<string> = [
      '学分', '培养', '课程', '模块', '类别', '性质', '要求', '完成', '通过', '修读', '学时'
    ];
    return keywords.find((item: string): boolean => text.includes(item)) !== undefined;
  }

  private parseCalendar(raw: Record<string, Object>): CampusCalendar {
    const calendar: CampusCalendar = new CampusCalendar();
    calendar.academicYear = (raw['academicYear'] as string) ?? '';
    calendar.sourceLabel = (raw['sourceLabel'] as string) ?? '';
    calendar.sourceUrl = (raw['sourceUrl'] as string) ?? '';
    calendar.publishedAt = (raw['publishedAt'] as string) ?? '';
    calendar.syncedAt = (raw['syncedAt'] as number) ?? 0;
    const eventsRaw: Object | undefined = raw['events'];
    if (eventsRaw !== undefined && Array.isArray(eventsRaw)) {
      const events: Array<Object> = eventsRaw as Array<Object>;
      for (let i = 0; i < events.length; i++) {
        const item: Record<string, Object> = events[i] as Record<string, Object>;
        const event: CalendarEvent = new CalendarEvent();
        event.title = (item['title'] as string) ?? '';
        event.startDate = (item['startDate'] as string) ?? '';
        event.endDate = (item['endDate'] as string) ?? '';
        event.eventType = (item['eventType'] as string) ?? '';
        event.note = (item['note'] as string) ?? '';
        if (event.title.length > 0 && event.startDate.length > 0) {
          calendar.events.push(event);
        }
      }
    }
    return calendar;
  }

  private parseMailSnapshot(raw: Record<string, Object>): MailSnapshot {
    const snapshot: MailSnapshot = new MailSnapshot();
    snapshot.updatedAt = (raw['updatedAt'] as number) ?? 0;
    snapshot.sourcePage = (raw['sourcePage'] as string) ?? '';
    const foldersRaw: Object | undefined = raw['folders'];
    if (foldersRaw !== undefined && Array.isArray(foldersRaw)) {
      const folders: Array<Object> = foldersRaw as Array<Object>;
      for (let i = 0; i < folders.length; i++) {
        const item: Record<string, Object> = folders[i] as Record<string, Object>;
        const folder: MailFolder = new MailFolder();
        folder.id = (item['id'] as string) ?? '';
        folder.name = (item['name'] as string) ?? '';
        folder.unreadCount = (item['unreadCount'] as number) ?? 0;
        folder.messageCount = (item['messageCount'] as number) ?? 0;
        if (folder.id.length > 0 && folder.name.length > 0) {
          snapshot.folders.push(folder);
        }
      }
    }
    const messagesRaw: Object | undefined = raw['messages'];
    if (messagesRaw !== undefined && Array.isArray(messagesRaw)) {
      const messages: Array<Object> = messagesRaw as Array<Object>;
      for (let i = 0; i < messages.length; i++) {
        const item: Record<string, Object> = messages[i] as Record<string, Object>;
        const message: MailSummary = new MailSummary();
        message.id = (item['id'] as string) ?? '';
        message.folderId = (item['folderId'] as string) ?? '';
        message.subject = (item['subject'] as string) ?? '';
        message.sender = (item['sender'] as string) ?? '';
        message.receivedAt = (item['receivedAt'] as string) ?? '';
        message.preview = (item['preview'] as string) ?? '';
        message.unread = (item['unread'] as boolean) ?? false;
        message.hasAttachment = (item['hasAttachment'] as boolean) ?? false;
        message.syncedAt = (item['syncedAt'] as number) ?? 0;
        if (message.subject.length > 0) {
          snapshot.messages.push(message);
        }
      }
    }
    const detailsRaw: Object | undefined = raw['details'];
    if (detailsRaw !== undefined && Array.isArray(detailsRaw)) {
      const details: Array<Object> = detailsRaw as Array<Object>;
      for (let i = 0; i < details.length; i++) {
        const item: Record<string, Object> = details[i] as Record<string, Object>;
        const detail: MailDetail = new MailDetail();
        detail.messageKey = (item['messageKey'] as string) ?? '';
        detail.subject = (item['subject'] as string) ?? '';
        detail.sender = (item['sender'] as string) ?? '';
        detail.recipients = (item['recipients'] as string) ?? '';
        detail.receivedAt = (item['receivedAt'] as string) ?? '';
        detail.bodyText = (item['bodyText'] as string) ?? '';
        detail.cachedAt = (item['cachedAt'] as number) ?? 0;
        if (detail.messageKey.length > 0 && detail.hasContent()) {
          snapshot.details.push(detail);
        }
      }
    }
    return snapshot;
  }

  private validateCourses(courses: Array<CourseInfo>): SyncResult {
    if (courses.length === 0) {
      return { success: true, courseCount: 0, errorMessage: '' };
    }
    if (courses.length < MIN_COURSE_COUNT) {
      const result: SyncResult = {
        success: false,
        courseCount: courses.length,
        errorMessage: `课程数量过少 (${courses.length})，可能未完整读取，已保留原有数据`
      };
      return result;
    }
    if (courses.length > MAX_COURSE_COUNT) {
      const result: SyncResult = {
        success: false,
        courseCount: courses.length,
        errorMessage: `课程数量过多 (${courses.length})，可能存在数据异常，已保留原有数据`
      };
      return result;
    }
    let emptyNameCount: number = 0;
    let invalidDayCount: number = 0;
    let invalidPeriodCount: number = 0;
    for (let i = 0; i < courses.length; i++) {
      const course: CourseInfo = courses[i];
      if (course.name.length === 0) {
        emptyNameCount++;
      }
      if (course.sessions.length === 0) {
        continue;
      }
      for (let j = 0; j < course.sessions.length; j++) {
        const session: CourseSession = course.sessions[j];
        if (session.dayOfWeek < 1 || session.dayOfWeek > 7) {
          invalidDayCount++;
        }
        if (session.startPeriod < 1 || session.endPeriod > 16 || session.startPeriod > session.endPeriod) {
          invalidPeriodCount++;
        }
      }
    }
    if (emptyNameCount > courses.length * 0.5) {
      const result: SyncResult = {
        success: false,
        courseCount: courses.length,
        errorMessage: `超过半数课程名称为空，字段映射可能错误，已保留原有数据`
      };
      return result;
    }
    if (invalidDayCount > courses.length * 0.3) {
      const result: SyncResult = {
        success: false,
        courseCount: courses.length,
        errorMessage: `星期字段异常比例过高，字段映射可能错误，已保留原有数据`
      };
      return result;
    }
    if (invalidPeriodCount > courses.length * 0.3) {
      const result: SyncResult = {
        success: false,
        courseCount: courses.length,
        errorMessage: `节次字段异常比例过高，字段映射可能错误，已保留原有数据`
      };
      return result;
    }
    const successResult: SyncResult = { success: true, courseCount: courses.length, errorMessage: '' };
    return successResult;
  }

  private validateExams(exams: Array<ExamInfo>, courseCount: number): SyncResult {
    for (let i = 0; i < exams.length; i++) {
      if (exams[i].courseName.length === 0 || exams[i].termCode.length === 0 ||
          exams[i].termCode === 'UNKNOWN_TERM' || exams[i].rawText.length === 0) {
        return {
          success: false,
          courseCount: courseCount,
          errorMessage: '考试数据缺少课程、学期或原始信息，已保留原有数据'
        };
      }
    }
    return { success: true, courseCount: courseCount, errorMessage: '' };
  }

  private validateGrades(grades: Array<GradeInfo>, courseCount: number): SyncResult {
    for (let i = 0; i < grades.length; i++) {
      if (grades[i].courseName.length === 0 || grades[i].termCode.length === 0 ||
          grades[i].termCode === 'UNKNOWN_TERM') {
        return {
          success: false,
          courseCount: courseCount,
          errorMessage: '成绩数据缺少课程或学期，已保留原有数据'
        };
      }
    }
    return { success: true, courseCount: courseCount, errorMessage: '' };
  }

  private buildChangeEvents(
    currentCourses: Array<CourseInfo>,
    nextCourses: Array<CourseInfo>,
    currentExams: Array<ExamInfo>,
    nextExams: Array<ExamInfo>,
    currentGrades: Array<GradeInfo>,
    nextGrades: Array<GradeInfo>,
    input: SnapshotCommitInput
  ): Array<ChangeEvent> {
    const events: Array<ChangeEvent> = [];
    if (input.replaceCourses) {
      for (let i = 0; i < input.courses.length; i++) {
        const incoming: CourseInfo = input.courses[i];
        const key: string = this.courseDedupeKey(incoming);
        const previous: CourseInfo | undefined = currentCourses.find(
          (item: CourseInfo): boolean => this.courseDedupeKey(item) === key);
        if (previous === undefined) {
          events.push(this.makeChangeEvent(SyncTarget.TIMETABLE, ChangeKind.ADDED, key, incoming.name));
        } else if (this.courseSignature(previous) !== this.courseSignature(incoming)) {
          events.push(this.makeChangeEvent(SyncTarget.TIMETABLE, ChangeKind.MODIFIED, key, incoming.name));
        }
      }
      if (input.fullTimetableSyncCompleted) {
        for (let i = 0; i < currentCourses.length; i++) {
          const key: string = this.courseDedupeKey(currentCourses[i]);
          if (nextCourses.find((item: CourseInfo): boolean =>
            this.courseDedupeKey(item) === key) === undefined) {
            events.push(this.makeChangeEvent(
              SyncTarget.TIMETABLE, ChangeKind.REMOVED, key, currentCourses[i].name));
          }
        }
      }
    }
    if (input.replaceExams) {
      for (let i = 0; i < input.exams.length; i++) {
        const incoming: ExamInfo = input.exams[i];
        const key: string = this.examDedupeKey(incoming);
        const previous: ExamInfo | undefined = currentExams.find(
          (item: ExamInfo): boolean => this.examDedupeKey(item) === key);
        if (previous === undefined) {
          events.push(this.makeChangeEvent(
            SyncTarget.EXAMS, ChangeKind.ADDED, key, incoming.getDisplayCourseName()));
        } else if (this.examSignature(previous) !== this.examSignature(incoming)) {
          events.push(this.makeChangeEvent(
            SyncTarget.EXAMS, ChangeKind.MODIFIED, key, incoming.getDisplayCourseName()));
        }
      }
      for (let i = 0; i < currentExams.length; i++) {
        if (input.examTermsReplaced.length > 0 &&
            input.examTermsReplaced.find((term: string): boolean =>
              term === currentExams[i].termCode) === undefined) {
          continue;
        }
        const key: string = this.examDedupeKey(currentExams[i]);
        if (nextExams.find((item: ExamInfo): boolean => this.examDedupeKey(item) === key) === undefined) {
          events.push(this.makeChangeEvent(
            SyncTarget.EXAMS, ChangeKind.REMOVED, key, currentExams[i].getDisplayCourseName()));
        }
      }
    }
    if (input.replaceGrades) {
      for (let i = 0; i < input.grades.length; i++) {
        const incoming: GradeInfo = input.grades[i];
        const key: string = incoming.getListDedupeKey();
        const previous: GradeInfo | undefined = currentGrades.find(
          (item: GradeInfo): boolean => item.getListDedupeKey() === key);
        if (previous === undefined) {
          events.push(this.makeChangeEvent(
            SyncTarget.GRADES, ChangeKind.ADDED, key, incoming.courseName + ' ' + incoming.score));
        } else if (this.gradeSignature(previous) !== this.gradeSignature(incoming)) {
          events.push(this.makeChangeEvent(
            SyncTarget.GRADES, ChangeKind.MODIFIED, key, incoming.courseName + ' ' + incoming.score));
        }
      }
      if (input.fullGradeSyncCompleted) {
        for (let i = 0; i < currentGrades.length; i++) {
          const key: string = currentGrades[i].getListDedupeKey();
          if (nextGrades.find((item: GradeInfo): boolean =>
            item.getListDedupeKey() === key) === undefined) {
            events.push(this.makeChangeEvent(
              SyncTarget.GRADES, ChangeKind.REMOVED, key, currentGrades[i].courseName));
          }
        }
      }
    }
    return events;
  }

  private makeChangeEvent(
    target: SyncTarget,
    kind: ChangeKind,
    businessKey: string,
    summary: string
  ): ChangeEvent {
    const event: ChangeEvent = new ChangeEvent();
    event.target = target;
    event.kind = kind;
    event.businessKey = businessKey;
    event.summary = summary;
    event.createdAt = Date.now();
    event.id = target + '|' + kind + '|' + businessKey + '|' + event.createdAt.toString();
    return event;
  }

  private courseSignature(course: CourseInfo): string {
    return JSON.stringify({
      'teacher': course.teacher,
      'courseType': course.courseType,
      'sessions': course.sessions,
      'cancelled': course.isCancelled
    });
  }

  private examDedupeKey(exam: ExamInfo): string {
    return exam.termCode + '|' +
      (exam.courseCode.length > 0 ? exam.courseCode : exam.courseName) + '|' +
      exam.examDate + '|' + exam.examTime + '|' + exam.examType;
  }

  private examSignature(exam: ExamInfo): string {
    return exam.scheduleText + '|' + exam.locationText + '|' + exam.classroom + '|' +
      exam.seatNo + '|' + exam.status + '|' + exam.remark;
  }

  private gradeSignature(grade: GradeInfo): string {
    return grade.score + '|' + grade.bonusScore + '|' + grade.gradePoint + '|' +
      grade.gradeStatus + '|' + grade.remark;
  }

  private mergeExamsByTerm(
    current: Array<ExamInfo>,
    incoming: Array<ExamInfo>,
    replacedTerms: Array<string>
  ): Array<ExamInfo> {
    const merged: Array<ExamInfo> = current.filter((item: ExamInfo): boolean =>
      replacedTerms.find((term: string): boolean => term === item.termCode) === undefined);
    for (let i = 0; i < incoming.length; i++) {
      const key: string = this.examDedupeKey(incoming[i]);
      if (merged.find((item: ExamInfo): boolean => this.examDedupeKey(item) === key) === undefined) {
        merged.push(incoming[i]);
      }
    }
    return merged;
  }

  private mergeGradesByTerm(
    current: Array<GradeInfo>,
    incoming: Array<GradeInfo>,
    replacedTerms: Array<string>
  ): Array<GradeInfo> {
    const merged: Array<GradeInfo> = [];
    for (let i = 0; i < current.length; i++) {
      if (replacedTerms.find((term: string): boolean => term === current[i].termCode) === undefined) {
        merged.push(current[i]);
      }
    }
    for (let i = 0; i < incoming.length; i++) {
      const key: string = incoming[i].getListDedupeKey();
      if (merged.find((item: GradeInfo): boolean => item.getListDedupeKey() === key) === undefined) {
        merged.push(incoming[i]);
      }
    }
    return merged;
  }

  private mergeGradeTermSummaries(
    current: Array<GradeTermSummary>,
    incoming: Array<GradeTermSummary>,
    replacedTerms: Array<string>
  ): Array<GradeTermSummary> {
    const merged: Array<GradeTermSummary> = [];
    for (let i = 0; i < current.length; i++) {
      if (replacedTerms.find((term: string): boolean => term === current[i].termCode) === undefined) {
        merged.push(current[i]);
      }
    }
    for (let i = 0; i < incoming.length; i++) {
      if (incoming[i].termCode.length > 0 && incoming[i].hasCollegeRanking() &&
          merged.find((item: GradeTermSummary): boolean =>
            item.termCode === incoming[i].termCode) === undefined) {
        merged.push(incoming[i]);
      }
    }
    return merged;
  }

  private mergeCoursesByTerm(
    current: Array<CourseInfo>,
    incoming: Array<CourseInfo>,
    replacedTerms: Array<string>
  ): Array<CourseInfo> {
    const merged: Array<CourseInfo> = [];
    for (let i = 0; i < current.length; i++) {
      if (replacedTerms.find((term: string): boolean => term === current[i].termCode) === undefined) {
        merged.push(current[i]);
      }
    }
    for (let i = 0; i < incoming.length; i++) {
      const key: string = this.courseDedupeKey(incoming[i]);
      if (merged.find((item: CourseInfo): boolean => this.courseDedupeKey(item) === key) === undefined) {
        merged.push(incoming[i]);
      }
    }
    return merged;
  }

  private courseDedupeKey(course: CourseInfo): string {
    if (course.id.length > 0) {
      return course.id;
    }
    return course.termCode + '|' + course.courseCode + '|' + course.section + '|' +
      course.name + '|' + course.teacher;
  }
}
