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

  static filterByTerm(courses: Array<CourseInfo>, termCode: string): Array<CourseInfo> {
    if (termCode.length === 0 || termCode === 'UNKNOWN_TERM') {
      return [];
    }
    return courses.filter((course: CourseInfo): boolean => course.termCode === termCode);
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
