export enum SyncTarget {
  TIMETABLE = 'timetable',
  EXAMS = 'exams',
  GRADES = 'grades',
  PROFILE = 'profile',
  PROGRESS = 'progress',
  CALENDAR = 'calendar',
  MAIL = 'mail'
}

export class SyncRequest {
  targets: Array<SyncTarget> = [
    SyncTarget.TIMETABLE,
    SyncTarget.EXAMS,
    SyncTarget.GRADES,
    SyncTarget.PROFILE,
    SyncTarget.PROGRESS,
    SyncTarget.CALENDAR,
    SyncTarget.MAIL
  ];
  forceRefresh: boolean = false;
  includeHistoricalGrades: boolean = false;
  termCode: string = '';

  includes(target: SyncTarget): boolean {
    return this.targets.find((item: SyncTarget): boolean => item === target) !== undefined;
  }
}

export class ModuleSyncRecord {
  target: SyncTarget = SyncTarget.TIMETABLE;
  outcome: string = 'idle';
  updatedAt: number = 0;
  recordCount: number = 0;
  errorMessage: string = '';
  sourcePage: string = '';

  hasData(): boolean {
    return this.recordCount > 0 || this.updatedAt > 0;
  }
}

export enum ChangeKind {
  ADDED = 'added',
  MODIFIED = 'modified',
  REMOVED = 'removed'
}

export class ChangeEvent {
  id: string = '';
  target: SyncTarget = SyncTarget.TIMETABLE;
  kind: ChangeKind = ChangeKind.ADDED;
  businessKey: string = '';
  summary: string = '';
  createdAt: number = 0;
  acknowledged: boolean = false;
}

export class ProfileField {
  label: string = '';
  value: string = '';
  group: string = '';
}

export class StudentProfile {
  studentName: string = '';
  college: string = '';
  major: string = '';
  className: string = '';
  educationLevel: string = '';
  studentStatus: string = '';
  enrollmentYear: string = '';
  expectedGraduation: string = '';
  trainingMode: string = '';
  fields: Array<ProfileField> = [];
  syncedAt: number = 0;
  sourcePage: string = '';

  hasData(): boolean {
    return this.studentName.length > 0 || this.college.length > 0 ||
      this.major.length > 0 || this.fields.length > 0;
  }
}

export class ProgressCourse {
  courseName: string = '';
  credit: number = 0;
  score: string = '';
  status: string = '';
  category: string = '';

  needsAttention(): boolean {
    const normalized: string = this.status.toLowerCase();
    return normalized.includes('不及格') || normalized.includes('未通过') ||
      normalized.includes('重修') || normalized.includes('failed');
  }
}

export class AcademicProgress {
  requiredCredits: number = -1;
  earnedCredits: number = -1;
  failedCourseCount: number = 0;
  officialSummary: boolean = false;
  fields: Array<ProfileField> = [];
  courses: Array<ProgressCourse> = [];
  syncedAt: number = 0;
  sourcePage: string = '';

  hasData(): boolean {
    return this.requiredCredits >= 0 || this.earnedCredits >= 0 ||
      this.fields.length > 0 || this.courses.length > 0;
  }
}

export class CalendarEvent {
  title: string = '';
  startDate: string = '';
  endDate: string = '';
  eventType: string = '';
  note: string = '';
}

export class CampusCalendar {
  academicYear: string = '';
  sourceLabel: string = '';
  sourceUrl: string = '';
  publishedAt: string = '';
  events: Array<CalendarEvent> = [];
  syncedAt: number = 0;

  static published20262027(): CampusCalendar {
    const calendar: CampusCalendar = new CampusCalendar();
    calendar.academicYear = '2026-2027';
    calendar.sourceLabel = '北京交通大学 2026-2027 学年校历';
    calendar.sourceUrl = 'https://bksy.bjtu.edu.cn/Semester.html';
    calendar.publishedAt = '2026';
    calendar.events = [
      CampusCalendar.event('秋季学期开始上课', '2026-09-07', '2026-09-07', 'teaching'),
      CampusCalendar.event('中秋节', '2026-09-25', '2026-09-25', 'holiday'),
      CampusCalendar.event('国庆节', '2026-10-01', '2026-10-01', 'holiday'),
      CampusCalendar.event('元旦', '2027-01-01', '2027-01-01', 'holiday'),
      CampusCalendar.event('学生寒假', '2027-01-18', '2027-02-28', 'vacation'),
      CampusCalendar.event('春季学期开始上课', '2027-03-01', '2027-03-01', 'teaching'),
      CampusCalendar.event('清明节', '2027-04-05', '2027-04-05', 'holiday'),
      CampusCalendar.event('劳动节', '2027-05-01', '2027-05-01', 'holiday'),
      CampusCalendar.event('端午节', '2027-06-09', '2027-06-09', 'holiday'),
      CampusCalendar.event('夏季学期开始', '2027-07-05', '2027-07-05', 'teaching'),
      CampusCalendar.event('学生暑假', '2027-07-26', '2027-09-05', 'vacation')
    ];
    return calendar;
  }

  private static event(
    title: string,
    startDate: string,
    endDate: string,
    eventType: string
  ): CalendarEvent {
    const item: CalendarEvent = new CalendarEvent();
    item.title = title;
    item.startDate = startDate;
    item.endDate = endDate;
    item.eventType = eventType;
    return item;
  }
}
