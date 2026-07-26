export class SemesterInfo {
  academicYear: string = '';
  semester: string = '';
  startDate: string = '';
  currentTeachingWeek: number = 0;
  totalWeeks: number = 20;
  termCode: string = '';
  termLabel: string = '';

  static of(
    academicYear: string,
    semester: string,
    startDate: string,
    currentTeachingWeek: number,
    totalWeeks: number
  ): SemesterInfo {
    const s = new SemesterInfo();
    s.academicYear = academicYear;
    s.semester = semester;
    s.startDate = startDate;
    s.currentTeachingWeek = currentTeachingWeek;
    s.totalWeeks = totalWeeks;
    return s;
  }

  calculateCurrentWeek(): number {
    if (this.startDate.length === 0) {
      return 0;
    }
    const startDateObj: Date = new Date(this.startDate);
    const now: Date = new Date();
    const diffMs: number = now.getTime() - startDateObj.getTime();
    const diffDays: number = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    if (diffDays < 0) {
      return 0;
    }
    const week: number = Math.floor(diffDays / 7) + 1;
    return week;
  }
}
