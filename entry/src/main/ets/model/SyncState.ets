import { SemesterInfo } from './SemesterInfo';

export class SyncState {
  lastSyncTime: number = 0;
  courseCount: number = 0;
  examCount: number = 0;
  gradeCount: number = 0;
  sourcePage: string = '';
  dataVersion: number = 1;
  lastFullTimetableSyncTime: number = 0;
  lastFullGradeSyncTime: number = 0;
  lastOutcome: string = '';
  lastErrors: Array<string> = [];
  semester: SemesterInfo = new SemesterInfo();

  static of(
    lastSyncTime: number,
    courseCount: number,
    sourcePage: string,
    dataVersion: number,
    semester: SemesterInfo
  ): SyncState {
    const s = new SyncState();
    s.lastSyncTime = lastSyncTime;
    s.courseCount = courseCount;
    s.sourcePage = sourcePage;
    s.dataVersion = dataVersion;
    s.semester = semester;
    return s;
  }

  hasData(): boolean {
    return this.courseCount > 0 || this.examCount > 0 || this.gradeCount > 0 ||
      this.lastSyncTime > 0;
  }

  getSyncTimeText(): string {
    if (this.lastSyncTime === 0) {
      return '未同步';
    }
    const date: Date = new Date(this.lastSyncTime);
    const month: string = this.pad(date.getMonth() + 1);
    const day: string = this.pad(date.getDate());
    const hour: string = this.pad(date.getHours());
    const minute: string = this.pad(date.getMinutes());
    return `${month}-${day} ${hour}:${minute}`;
  }

  getOutcomeText(): string {
    if (this.lastOutcome === 'partial_success') {
      return '部分成功';
    }
    if (this.lastOutcome === 'completed' || this.lastOutcome === 'success') {
      return '同步完成';
    }
    return this.hasData() ? '本地数据可用' : '尚未同步';
  }

  private pad(num: number): string {
    if (num < 10) {
      return '0' + num;
    }
    return num.toString();
  }
}
