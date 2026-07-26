import { ExamInfo } from './ExamInfo';

export class ExamTimeline {
  static startTimestamp(exam: ExamInfo): number {
    const source: string = (exam.examDate + ' ' + exam.examTime + ' ' + exam.scheduleText).trim();
    const dateMatch: RegExpMatchArray | null = source.match(
      new RegExp('(20\\d{2})\\s*[-年/.]\\s*(\\d{1,2})\\s*[-月/.]\\s*(\\d{1,2})')
    );
    if (dateMatch === null || dateMatch.length < 4) {
      return Number.MAX_SAFE_INTEGER;
    }
    const timeMatch: RegExpMatchArray | null = source.match(new RegExp('(\\d{1,2}):(\\d{2})'));
    const hour: number = timeMatch !== null && timeMatch.length >= 3 ? parseInt(timeMatch[1]) : 23;
    const minute: number = timeMatch !== null && timeMatch.length >= 3 ? parseInt(timeMatch[2]) : 59;
    return new Date(parseInt(dateMatch[1]), parseInt(dateMatch[2]) - 1,
      parseInt(dateMatch[3]), hour, minute).getTime();
  }

  static endTimestamp(exam: ExamInfo): number {
    const start: number = ExamTimeline.startTimestamp(exam);
    if (start === Number.MAX_SAFE_INTEGER) {
      return start;
    }
    const source: string = (exam.examTime + ' ' + exam.scheduleText).trim();
    const rangeMatch: RegExpMatchArray | null = source.match(
      new RegExp('(\\d{1,2}):(\\d{2})\\s*[-~—–至]\\s*(\\d{1,2}):(\\d{2})')
    );
    if (rangeMatch === null || rangeMatch.length < 5) {
      return source.includes(':') ? start + 2 * 60 * 60 * 1000 : start;
    }
    const startDate: Date = new Date(start);
    return new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate(),
      parseInt(rangeMatch[3]), parseInt(rangeMatch[4])).getTime();
  }

  static isPast(exam: ExamInfo, now: number = Date.now()): boolean {
    const end: number = ExamTimeline.endTimestamp(exam);
    return end !== Number.MAX_SAFE_INTEGER && now > end;
  }

  static nextUpcoming(exams: Array<ExamInfo>, now: number = Date.now()): ExamInfo | undefined {
    let best: ExamInfo | undefined = undefined;
    let bestStart: number = Number.MAX_SAFE_INTEGER;
    for (let i = 0; i < exams.length; i++) {
      const start: number = ExamTimeline.startTimestamp(exams[i]);
      const end: number = ExamTimeline.endTimestamp(exams[i]);
      if (start === Number.MAX_SAFE_INTEGER || end < now) {
        continue;
      }
      if (start < bestStart) {
        best = exams[i];
        bestStart = start;
      }
    }
    return best;
  }
}
