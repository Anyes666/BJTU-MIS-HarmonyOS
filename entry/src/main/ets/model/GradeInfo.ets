export const FIRST_GRADE_TERM: string = '2025-2026-1';

export class GradeInfo {
  id: string = '';
  courseName: string = '';
  courseCode: string = '';
  credit: string = '';
  score: string = '';
  scoreNumeric: number = -1;
  bonusScore: string = '';
  gradePoint: string = '';
  teacher: string = '';
  examType: string = '';
  gradeStatus: string = '';
  remark: string = '';
  detail: string = '';
  detailPath: string = '';
  detailTitle: string = '';
  detailFields: Array<GradeDetailField> = [];
  detailTables: Array<GradeDetailTable> = [];
  detailLoadedAt: number = 0;
  termCode: string = '';
  termLabel: string = '';
  academicYear: string = '';
  semester: string = '';
  sourceUrl: string = '';
  syncedAt: number = 0;

  getDedupeKey(): string {
    return this.termCode + '|' + this.courseName + '|' + this.credit + '|' + this.score + '|' +
      this.teacher + '|' + this.bonusScore + '|' + this.examType + '|' + this.gradeStatus + '|' +
      this.remark + '|' + this.detailPath;
  }

  getListDedupeKey(): string {
    const term: string = GradeTermOrder.canonical(this.termCode, this.termLabel);
    const course: string = this.courseName.replace(new RegExp('\\s+', 'g'), '').toLowerCase();
    const teacher: string = this.teacher.replace(new RegExp('\\s+', 'g'), '').toLowerCase();
    return term + '|' + course + '|' + this.credit.trim() + '|' +
      this.score.trim().toUpperCase() + '|' + teacher;
  }

  hasDetailData(): boolean {
    return this.detailFields.length > 0 || this.detailTables.length > 0;
  }

  getDisplayCourseName(): string {
    const normalized: string = this.courseName.replace(new RegExp('\\s+', 'g'), ' ').trim();
    if (this.courseCode.length > 0 && normalized.startsWith(this.courseCode + ' ')) {
      return normalized.substring(this.courseCode.length).trim();
    }
    const combined: RegExpMatchArray | null =
      normalized.match(new RegExp('^[A-Za-z][A-Za-z0-9]{5,}\\s+(.+)$'));
    return combined !== null && combined.length > 1 ? combined[1].trim() : normalized;
  }
}

export class GradeDetailField {
  label: string = '';
  value: string = '';
}

export class GradeDetailTable {
  title: string = '';
  headers: Array<string> = [];
  rows: Array<Array<string>> = [];
}

export class GradeDetailData {
  title: string = '';
  fields: Array<GradeDetailField> = [];
  tables: Array<GradeDetailTable> = [];

  hasContent(): boolean {
    return this.fields.length > 0 || this.tables.length > 0;
  }
}

export class GradeSyncState {
  termCode: string = '';
  termLabel: string = '';
  gradeCount: number = 0;
  lastSyncTime: number = 0;
  sourceUrl: string = '';
  success: boolean = true;
  errorMessage: string = '';
}

export class GradeTermOption {
  termCode: string = '';
  termLabel: string = '';
  selected: boolean = false;
}

export class GradeTermSummary {
  termCode: string = '';
  termLabel: string = '';
  collegeRank: number = -1;
  collegeTotal: number = -1;
  collegePercentile: string = '';

  hasCollegeRanking(): boolean {
    return this.collegeRank > 0 || this.collegePercentile.length > 0;
  }
}

export class GradeTermOrder {
  static canonical(code: string, label: string): string {
    const normalizedLabel: string = GradeTermOrder.normalize(label);
    if (normalizedLabel.match(new RegExp('^20\\d{2}-20\\d{2}-[123]$')) !== null) {
      return normalizedLabel;
    }
    return GradeTermOrder.normalize(code.length > 0 ? code : label);
  }

  static normalize(label: string): string {
    const compact: string = label.replace(new RegExp('\\s+', 'g'), '')
      .replace(new RegExp('[—–－_~～至]', 'g'), '-');
    const yearMatch: RegExpMatchArray | null =
      compact.match(new RegExp('(20\\d{2})-(20\\d{2})'));
    if (yearMatch === null || yearMatch.length < 3) {
      return compact;
    }
    let semester: string = '';
    const digitMatch: RegExpMatchArray | null =
      compact.match(new RegExp('(?:第)?([123])(?:学期)?$'));
    if (digitMatch !== null && digitMatch.length > 1) {
      semester = digitMatch[1];
    } else if (compact.endsWith('第一学期')) {
      semester = '1';
    } else if (compact.endsWith('第二学期')) {
      semester = '2';
    } else if (compact.endsWith('第三学期')) {
      semester = '3';
    }
    return semester.length > 0 ?
      yearMatch[1] + '-' + yearMatch[2] + '-' + semester : compact;
  }

  static compare(first: string, second: string): number {
    const normalizedFirst: string = GradeTermOrder.normalize(first);
    const normalizedSecond: string = GradeTermOrder.normalize(second);
    const firstParts: Array<number> = GradeTermOrder.parts(normalizedFirst);
    const secondParts: Array<number> = GradeTermOrder.parts(normalizedSecond);
    if (firstParts[0] !== secondParts[0]) {
      return firstParts[0] - secondParts[0];
    }
    if (firstParts[1] !== secondParts[1]) {
      return firstParts[1] - secondParts[1];
    }
    if (firstParts[2] !== secondParts[2]) {
      return firstParts[2] - secondParts[2];
    }
    return normalizedFirst.localeCompare(normalizedSecond);
  }

  static isAtOrAfter(label: string, firstTerm: string): boolean {
    return GradeTermOrder.compare(label, firstTerm) >= 0;
  }

  private static parts(label: string): Array<number> {
    const yearMatch: RegExpMatchArray | null = label.match(/(\d{4})\s*[-—]\s*(\d{4})/);
    const termMatch: RegExpMatchArray | null =
      label.match(/[-—_]\s*([123])(?:\s*学期)?\s*$/);
    return [
      yearMatch !== null ? Number(yearMatch[1]) : 9999,
      yearMatch !== null ? Number(yearMatch[2]) : 9999,
      termMatch !== null ? Number(termMatch[1]) : 9
    ];
  }
}
