export class ExamInfo {
  id: string = '';
  courseName: string = '';
  courseCode: string = '';
  examDate: string = '';
  examTime: string = '';
  scheduleText: string = '';
  examMode: string = '';
  examType: string = '';
  status: string = '';
  remark: string = '';
  registration: string = '';
  detail: string = '';
  detailPath: string = '';
  rawText: string = '';
  campus: string = '';
  building: string = '';
  classroom: string = '';
  locationText: string = '';
  seatNo: string = '';
  termCode: string = '';
  termLabel: string = '';
  sourceUrl: string = '';
  syncedAt: number = 0;

  getDisplayCourseName(): string {
    const normalized: string = this.courseName.replace(new RegExp('\\s+', 'g'), ' ').trim();
    if (this.courseCode.length > 0 && normalized.startsWith(this.courseCode + ' ')) {
      return normalized.substring(this.courseCode.length).trim();
    }
    return normalized;
  }
}

export class ExamSyncState {
  termCode: string = '';
  examCount: number = 0;
  lastSyncTime: number = 0;
  sourceUrl: string = '';
  success: boolean = true;
  errorMessage: string = '';
}
