import { AcademicCalendar } from './AcademicCalendar';

export class CourseInfo {
  id: string = '';
  name: string = '';
  courseCode: string = '';
  section: string = '';
  teacher: string = '';
  courseType: string = '';
  sessions: Array<CourseSession> = [];
  isTemporary: boolean = false;
  isCancelled: boolean = false;
  termCode: string = '';
  termLabel: string = '';
  sourceUrl: string = '';
  syncedAt: number = 0;
  updateTime: number = 0;

  static filterByTerm(
    courses: Array<CourseInfo>,
    termCode: string,
    termLabel: string = ''
  ): Array<CourseInfo> {
    if (termCode.length === 0 || termCode === 'UNKNOWN_TERM') {
      return CourseInfo.latestUnambiguousTerm(courses);
    }
    const normalizedTerm: string = AcademicCalendar.normalizeTerm(termCode, termLabel);
    const matched: Array<CourseInfo> = courses.filter((course: CourseInfo): boolean => {
      if (course.termCode === termCode) {
        return true;
      }
      if (normalizedTerm.length === 0) {
        return false;
      }
      return AcademicCalendar.normalizeTerm(course.termCode, course.termLabel) === normalizedTerm;
    });
    if (matched.length > 0) {
      return matched;
    }

    // The current timetable endpoint stores only one term. Older snapshots may
    // retain a different opaque term code or an older term group. Prefer the
    // single cached term, otherwise use only the uniquely newest synced group;
    // never mix historical terms.
    return CourseInfo.latestUnambiguousTerm(courses);
  }

  private static latestUnambiguousTerm(courses: Array<CourseInfo>): Array<CourseInfo> {
    let onlyTerm: string = '';
    let newestTerm: string = '';
    let newestTime: number = -1;
    let newestTied: boolean = false;
    for (let i = 0; i < courses.length; i++) {
      const normalizedCourseTerm: string =
        AcademicCalendar.normalizeTerm(courses[i].termCode, courses[i].termLabel);
      const identity: string = normalizedCourseTerm.length > 0 ?
        normalizedCourseTerm :
        (courses[i].termCode.length > 0 ? courses[i].termCode : 'UNKNOWN_TERM');
      if (onlyTerm.length === 0) {
        onlyTerm = identity;
      } else if (onlyTerm !== identity) {
        onlyTerm = '*';
      }
      const courseTime: number = courses[i].syncedAt > 0 ?
        courses[i].syncedAt : courses[i].updateTime;
      if (courseTime > newestTime) {
        newestTime = courseTime;
        newestTerm = identity;
        newestTied = false;
      } else if (courseTime === newestTime && newestTerm !== identity) {
        newestTied = true;
      }
    }
    if (onlyTerm.length > 0 && onlyTerm !== '*') {
      return courses;
    }
    if (newestTime <= 0 || newestTerm.length === 0 || newestTied) {
      return [];
    }
    return courses.filter((course: CourseInfo): boolean => {
      const normalizedCourseTerm: string =
        AcademicCalendar.normalizeTerm(course.termCode, course.termLabel);
      const identity: string = normalizedCourseTerm.length > 0 ?
        normalizedCourseTerm :
        (course.termCode.length > 0 ? course.termCode : 'UNKNOWN_TERM');
      return identity === newestTerm;
    });
  }

  getSessionsForDay(dayOfWeek: number): Array<CourseSession> {
    const result: Array<CourseSession> = [];
    for (let i = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].dayOfWeek === dayOfWeek) {
        result.push(this.sessions[i]);
      }
    }
    return result;
  }

  getSessionsForWeek(week: number): Array<CourseSession> {
    const result: Array<CourseSession> = [];
    for (let i = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].containsWeek(week)) {
        result.push(this.sessions[i]);
      }
    }
    return result;
  }
}

export class CourseSession {
  dayOfWeek: number = 0;
  startPeriod: number = 0;
  endPeriod: number = 0;
  startWeek: number = 0;
  endWeek: number = 0;
  weekType: string = 'every';
  weekNumbers: Array<number> = [];
  discontinuousWeeks: string = '';
  classroom: string = '';
  campus: string = '';
  building: string = '';
  room: string = '';
  locationText: string = '';
  timeRange: string = '';
  weeksRaw: string = '';

  containsWeek(week: number): boolean {
    if (week < this.startWeek || week > this.endWeek) {
      return false;
    }
    if (this.weekType === 'odd' && week % 2 === 0) {
      return false;
    }
    if (this.weekType === 'even' && week % 2 !== 0) {
      return false;
    }
    if (this.weekNumbers.length > 0) {
      const found = this.weekNumbers.find((w: number): boolean => w === week);
      if (found === undefined) {
        return false;
      }
    }
    return true;
  }

  parseDiscontinuousWeeks(): Array<number> {
    const result: Array<number> = [];
    if (this.discontinuousWeeks.length === 0) {
      return result;
    }
    const normalized: string = this.discontinuousWeeks
      .replace(new RegExp('第', 'g'), '')
      .replace(new RegExp('周', 'g'), '')
      .replace(new RegExp('，', 'g'), ',');
    const parts: Array<string> = normalized.split(',');
    for (let i = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      if (part.length === 0) {
        continue;
      }
      if (part.includes('-') || part.includes('~')) {
        const range: Array<string> = part.split(new RegExp('[-~]'));
        if (range.length === 2) {
          const start: number = parseInt(range[0]);
          const end: number = parseInt(range[1]);
          if (!isNaN(start) && !isNaN(end)) {
            for (let w = start; w <= end; w++) {
              result.push(w);
            }
          }
        }
      } else {
        const single: number = parseInt(part);
        if (!isNaN(single)) {
          result.push(single);
        }
      }
    }
    return result;
  }
}
