import { GradeInfo } from './GradeInfo';

export class GradeMetricsResult {
  averageScore: number = -1;
  gpa: number = -1;
  includedCredits: number = 0;
  includedCourses: number = 0;

  hasAverage(): boolean {
    return this.averageScore >= 0;
  }

  hasGpa(): boolean {
    return this.gpa >= 0;
  }
}

export class GradeMetrics {
  static calculate(grades: Array<GradeInfo>): GradeMetricsResult {
    const result: GradeMetricsResult = new GradeMetricsResult();
    let weightedScore: number = 0;
    let weightedPoint: number = 0;
    let credits: number = 0;
    const includedKeys: Array<string> = [];
    for (let i = 0; i < grades.length; i++) {
      const key: string = grades[i].getListDedupeKey();
      if (includedKeys.find((item: string): boolean => item === key) !== undefined) {
        continue;
      }
      const credit: number = Number(grades[i].credit);
      const score: number = GradeMetrics.scoreValue(grades[i].score);
      const point: number = GradeMetrics.pointValue(grades[i]);
      if (!isFinite(credit) || credit <= 0 || score < 0 || point < 0) {
        continue;
      }
      weightedScore += score * credit;
      weightedPoint += point * credit;
      credits += credit;
      includedKeys.push(key);
      result.includedCourses++;
    }
    if (credits > 0) {
      result.averageScore = weightedScore / credits;
      result.gpa = weightedPoint / credits;
      result.includedCredits = credits;
    }
    return result;
  }

  static scoreValue(raw: string): number {
    const score: string = raw.trim().toUpperCase();
    const numeric: number = Number(score);
    if (score.length > 0 && isFinite(numeric) && numeric >= 0 && numeric <= 100) {
      return numeric;
    }
    const values: Record<string, number> = {
      'A': 95, 'A-': 87, 'B+': 83, 'B': 79, 'B-': 76,
      'C+': 73, 'C': 69, 'C-': 66, 'D+': 63, 'D': 60, 'F': 30
    };
    const value: number | undefined = values[score];
    return value === undefined ? -1 : value;
  }

  static pointValue(grade: GradeInfo): number {
    const stored: number = Number(grade.gradePoint.trim());
    if (grade.gradePoint.trim().length > 0 && isFinite(stored) && stored >= 0 && stored <= 4) {
      return stored;
    }
    const score: string = grade.score.trim().toUpperCase();
    const letterPoints: Record<string, number> = {
      'A': 4.0, 'A-': 3.7, 'B+': 3.3, 'B': 3.0, 'B-': 2.7,
      'C+': 2.3, 'C': 2.0, 'C-': 1.7, 'D+': 1.3, 'D': 1.0, 'F': 0
    };
    const letterPoint: number | undefined = letterPoints[score];
    if (letterPoint !== undefined) {
      return letterPoint;
    }
    const numeric: number = Number(score);
    if (!isFinite(numeric) || numeric < 0 || numeric > 100) {
      return -1;
    }
    if (numeric >= 90) { return 4.0; }
    if (numeric >= 85) { return 3.7; }
    if (numeric >= 81) { return 3.3; }
    if (numeric >= 78) { return 3.0; }
    if (numeric >= 75) { return 2.7; }
    if (numeric >= 71) { return 2.3; }
    if (numeric >= 68) { return 2.0; }
    if (numeric >= 65) { return 1.7; }
    if (numeric >= 61) { return 1.3; }
    if (numeric >= 60) { return 1.0; }
    return 0;
  }
}
