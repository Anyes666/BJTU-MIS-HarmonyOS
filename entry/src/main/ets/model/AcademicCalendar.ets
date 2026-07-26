export class AcademicWeekRange {
  start: Date;
  end: Date;

  constructor(start: Date, end: Date) {
    this.start = start;
    this.end = end;
  }
}

export class AcademicCalendar {
  static normalizeTerm(termCode: string, termLabel: string = ''): string {
    const candidates: Array<string> = [termCode, termLabel];
    for (let i = 0; i < candidates.length; i++) {
      const text: string = candidates[i]
        .replace(new RegExp('[－—–~至]', 'g'), '-')
        .replace(new RegExp('\\s', 'g'), '');
      const compact: string = text.replace(new RegExp('\\D', 'g'), '');
      if (compact.length === 10) {
        const termNumber: number = parseInt(compact.substring(8, 10));
        if (termNumber >= 1 && termNumber <= 3) {
          return compact.substring(0, 4) + '-' + compact.substring(4, 8) + '-' + termNumber;
        }
      }
      const years: RegExpMatchArray | null =
        text.match(new RegExp('(20\\d{2})-(20\\d{2})'));
      if (years === null || years.length < 3) {
        continue;
      }
      let term: number = 0;
      const tail: string = text.substring(years.index! + years[0].length);
      const numeric: RegExpMatchArray | null = tail.match(new RegExp('[123]'));
      if (numeric !== null) {
        term = parseInt(numeric[0]);
      } else if (text.includes('第一学期') || text.includes('秋')) {
        term = 1;
      } else if (text.includes('第二学期') || text.includes('春')) {
        term = 2;
      } else if (text.includes('第三学期') || text.includes('夏')) {
        term = 3;
      }
      if (term >= 1 && term <= 3) {
        return years[1] + '-' + years[2] + '-' + term;
      }
    }
    return '';
  }

  static knownStartDate(termCode: string, termLabel: string = ''): string {
    switch (AcademicCalendar.normalizeTerm(termCode, termLabel)) {
      case '2025-2026-1':
        return '2025-09-08';
      case '2025-2026-2':
        return '2026-03-02';
      case '2026-2027-1':
        return '2026-09-07';
      case '2026-2027-2':
        return '2027-03-01';
      case '2026-2027-3':
        return '2027-07-05';
      default:
        return '';
    }
  }

  static knownTotalWeeks(termCode: string, termLabel: string = ''): number {
    const normalized: string = AcademicCalendar.normalizeTerm(termCode, termLabel);
    if (normalized === '2026-2027-3') {
      return 9;
    }
    if (normalized === '2025-2026-1' || normalized === '2025-2026-2' ||
        normalized === '2026-2027-1' || normalized === '2026-2027-2') {
      return 18;
    }
    return 0;
  }

  static weekRange(
    termCode: string,
    termLabel: string,
    week: number,
    preferredStartDate: string = ''
  ): AcademicWeekRange | undefined {
    if (week < 1) {
      return undefined;
    }
    const startText: string = preferredStartDate.length > 0 ?
      preferredStartDate : AcademicCalendar.knownStartDate(termCode, termLabel);
    if (startText.length === 0) {
      return undefined;
    }
    const termStart: Date = new Date(startText);
    if (isNaN(termStart.getTime())) {
      return undefined;
    }
    const dayMs: number = 24 * 60 * 60 * 1000;
    const monday: Date = new Date(termStart.getTime() + (week - 1) * 7 * dayMs);
    return new AcademicWeekRange(monday, new Date(monday.getTime() + 6 * dayMs));
  }

  static teachingWeek(
    termCode: string,
    termLabel: string,
    now: Date,
    preferredStartDate: string = '',
    maximumWeeks: number = 0
  ): number {
    const range: AcademicWeekRange | undefined =
      AcademicCalendar.weekRange(termCode, termLabel, 1, preferredStartDate);
    if (range === undefined) {
      return 0;
    }
    const diffDays: number = Math.floor(
      (now.getTime() - range.start.getTime()) / (24 * 60 * 60 * 1000)
    );
    if (diffDays < 0) {
      return 0;
    }
    const week: number = Math.floor(diffDays / 7) + 1;
    return maximumWeeks > 0 && week > maximumWeeks ? 0 : week;
  }
}
