import {
  AcademicProgress,
  ProfileField,
  ProgressCourse,
  StudentProfile
} from '../model/CampusInfo';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class CampusParser {
  static buildProfileScript(): string {
    return `
(function() {
  function clean(value) {
    return (value || '').replace(/\\s+/g, ' ').trim();
  }
  var fields = [];
  function add(label, value, group) {
    label = clean(label).replace(/[：:]$/, '');
    value = clean(value);
    if (!label || !value || value.length > 300) return;
    if (/学号|身份证|证件|电话|手机|邮箱|住址|地址|家庭|照片/.test(label)) return;
    if (fields.some(function(item) { return item.label === label && item.value === value; })) return;
    fields.push({ label: label, value: value, group: clean(group) });
  }
  Array.prototype.slice.call(document.querySelectorAll('table')).forEach(function(table) {
    var group = clean(table.querySelector('caption, thead') && table.querySelector('caption, thead').innerText);
    Array.prototype.slice.call(table.querySelectorAll('tr')).forEach(function(row) {
      var cells = Array.prototype.slice.call(row.querySelectorAll('th,td'))
        .map(function(cell) { return clean(cell.innerText); }).filter(Boolean);
      for (var i = 0; i + 1 < cells.length; i += 2) add(cells[i], cells[i + 1], group);
    });
  });
  Array.prototype.slice.call(document.querySelectorAll('dl')).forEach(function(dl) {
    var labels = Array.prototype.slice.call(dl.querySelectorAll('dt'));
    var values = Array.prototype.slice.call(dl.querySelectorAll('dd'));
    for (var i = 0; i < Math.min(labels.length, values.length); i++) {
      add(labels[i].innerText, values[i].innerText, '');
    }
  });
  return JSON.stringify({
    recognized: fields.length > 0,
    title: document.title || '',
    fields: fields.slice(0, 160)
  });
})();
`;
  }

  static buildProgressScript(): string {
    return `
(function() {
  function clean(value) {
    return (value || '').replace(/\\s+/g, ' ').trim();
  }
  var fields = [];
  var courses = [];
  function addField(label, value, group) {
    label = clean(label).replace(/[：:]$/, '');
    value = clean(value);
    if (!label || !value || value.length > 300) return;
    if (!/学分|培养|课程|模块|类别|性质|要求|完成|通过|修读|学时/.test(label + ' ' + group)) return;
    if (!fields.some(function(item) { return item.label === label && item.value === value; })) {
      fields.push({ label: label, value: value, group: clean(group) });
    }
  }
  Array.prototype.slice.call(document.querySelectorAll('table')).forEach(function(table) {
    var headers = Array.prototype.slice.call(table.querySelectorAll('tr:first-child th, tr:first-child td'))
      .map(function(cell) { return clean(cell.innerText); });
    var headerText = headers.join('|');
    var group = clean(table.querySelector('caption') && table.querySelector('caption').innerText);
    Array.prototype.slice.call(table.querySelectorAll('tr')).slice(1).forEach(function(row) {
      var cells = Array.prototype.slice.call(row.querySelectorAll('th,td'))
        .map(function(cell) { return clean(cell.innerText); });
      if (cells.length < 2) return;
      if (/课程|科目/.test(headerText) && /学分|成绩|状态/.test(headerText)) {
        function at(pattern) {
          var index = headers.findIndex(function(value) { return pattern.test(value); });
          return index >= 0 ? (cells[index] || '') : '';
        }
        var name = at(/课程|科目|环节/);
        if (name) {
          courses.push({
            courseName: name,
            credit: at(/学分/),
            score: at(/成绩|分数/),
            status: at(/状态|通过|修读/),
            category: at(/类别|性质|模块/)
          });
          return;
        }
      }
      for (var i = 0; i + 1 < cells.length; i += 2) addField(cells[i], cells[i + 1], group);
    });
  });
  Array.prototype.slice.call(document.querySelectorAll('.row, dl')).forEach(function(block) {
    var text = clean(block.innerText);
    var match = text.match(/^([^：:]{2,20})[：:]\\s*(.+)$/);
    if (match) addField(match[1], match[2], '');
  });
  return JSON.stringify({
    recognized: fields.length > 0 || courses.length > 0,
    fields: fields.slice(0, 160),
    courses: courses.slice(0, 500)
  });
})();
`;
  }

  static parseProfile(result: string, sourcePage: string): StudentProfile {
    const profile: StudentProfile = new StudentProfile();
    const raw: Record<string, Object> = CampusParser.decode(result);
    const fields: Object | undefined = raw['fields'];
    if (fields === undefined || !Array.isArray(fields)) {
      return profile;
    }
    for (let i = 0; i < fields.length; i++) {
      const item: Record<string, Object> = fields[i] as Record<string, Object>;
      const field: ProfileField = new ProfileField();
      field.label = (item['label'] as string) ?? '';
      field.value = (item['value'] as string) ?? '';
      field.group = (item['group'] as string) ?? '';
      if (field.label.length === 0 || field.value.length === 0 ||
          CampusParser.isSensitiveField(field.label)) {
        continue;
      }
      profile.fields.push(field);
      CampusParser.assignProfileField(profile, field);
    }
    if (profile.hasData()) {
      profile.syncedAt = Date.now();
      profile.sourcePage = sourcePage;
    }
    return profile;
  }

  static parseProgress(result: string, sourcePage: string): AcademicProgress {
    const progress: AcademicProgress = new AcademicProgress();
    const raw: Record<string, Object> = CampusParser.decode(result);
    const fields: Object | undefined = raw['fields'];
    if (fields !== undefined && Array.isArray(fields)) {
      for (let i = 0; i < fields.length; i++) {
        const item: Record<string, Object> = fields[i] as Record<string, Object>;
        const field: ProfileField = new ProfileField();
        field.label = (item['label'] as string) ?? '';
        field.value = (item['value'] as string) ?? '';
        field.group = (item['group'] as string) ?? '';
        if (field.label.length === 0 || field.value.length === 0 ||
            !CampusParser.isAcademicProgressField(field)) {
          continue;
        }
        progress.fields.push(field);
        const value: number = CampusParser.firstNumber(field.value);
        if (field.label.includes('要求') && field.label.includes('学分') && value >= 0) {
          progress.requiredCredits = value;
          progress.officialSummary = true;
        } else if ((field.label.includes('已获') || field.label.includes('获得') ||
                    field.label.includes('完成')) && field.label.includes('学分') && value >= 0) {
          progress.earnedCredits = value;
          progress.officialSummary = true;
        }
      }
    }
    const courses: Object | undefined = raw['courses'];
    if (courses !== undefined && Array.isArray(courses)) {
      for (let i = 0; i < courses.length; i++) {
        const item: Record<string, Object> = courses[i] as Record<string, Object>;
        const course: ProgressCourse = new ProgressCourse();
        course.courseName = (item['courseName'] as string) ?? '';
        course.credit = CampusParser.firstNumber((item['credit'] as string) ?? '');
        course.score = (item['score'] as string) ?? '';
        course.status = (item['status'] as string) ?? '';
        course.category = (item['category'] as string) ?? '';
        if (course.courseName.length === 0) {
          continue;
        }
        progress.courses.push(course);
        if (course.needsAttention()) {
          progress.failedCourseCount++;
        }
      }
    }
    if (progress.hasData()) {
      progress.syncedAt = Date.now();
      progress.sourcePage = sourcePage;
    }
    return progress;
  }

  static isRecognized(result: string): boolean {
    return (CampusParser.decode(result)['recognized'] as boolean) ?? false;
  }

  private static decode(result: string): Record<string, Object> {
    try {
      return JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
    } catch (_) {
      return {};
    }
  }

  private static assignProfileField(profile: StudentProfile, field: ProfileField): void {
    const label: string = field.label;
    if ((label.includes('姓名') || label === '学生') && profile.studentName.length === 0) {
      profile.studentName = field.value;
    } else if ((label.includes('学院') || label.includes('院系')) && profile.college.length === 0) {
      profile.college = field.value;
    } else if (label.includes('专业') && profile.major.length === 0) {
      profile.major = field.value;
    } else if (label.includes('班级') && profile.className.length === 0) {
      profile.className = field.value;
    } else if ((label.includes('培养层次') || label.includes('学历层次')) &&
               profile.educationLevel.length === 0) {
      profile.educationLevel = field.value;
    } else if (label.includes('学籍状态') && profile.studentStatus.length === 0) {
      profile.studentStatus = field.value;
    } else if ((label.includes('入学') || label.includes('年级')) &&
               profile.enrollmentYear.length === 0) {
      profile.enrollmentYear = field.value;
    } else if (label.includes('预计毕业') && profile.expectedGraduation.length === 0) {
      profile.expectedGraduation = field.value;
    } else if (label.includes('培养方式') && profile.trainingMode.length === 0) {
      profile.trainingMode = field.value;
    }
  }

  private static isSensitiveField(label: string): boolean {
    const sensitive: Array<string> = [
      '学号', '身份证', '证件', '电话', '手机', '邮箱', '住址', '地址', '家庭', '照片'
    ];
    return sensitive.find((item: string): boolean => label.includes(item)) !== undefined;
  }

  private static isAcademicProgressField(field: ProfileField): boolean {
    if (CampusParser.isSensitiveField(field.label) ||
        field.label.match(new RegExp('^\\d+$')) !== null) {
      return false;
    }
    const text: string = field.label + ' ' + field.group;
    const keywords: Array<string> = [
      '学分', '培养', '课程', '模块', '类别', '性质', '要求', '完成', '通过', '修读', '学时'
    ];
    return keywords.find((item: string): boolean => text.includes(item)) !== undefined;
  }

  private static firstNumber(text: string): number {
    const match: RegExpMatchArray | null = text.match(new RegExp('-?\\d+(?:\\.\\d+)?'));
    if (match === null) {
      return -1;
    }
    const value: number = parseFloat(match[0]);
    return isNaN(value) ? -1 : value;
  }
}
