import { CourseInfo, CourseSession } from '../model/CourseInfo';
import { SemesterInfo } from '../model/SemesterInfo';
import { AcademicCalendar } from '../model/AcademicCalendar';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class ParsedWeekInfo {
  startWeek: number = 1;
  endWeek: number = 16;
  weekType: string = 'every';
  weekNumbers: Array<number> = [];
  discontinuousWeeks: string = '';
}

export class CourseParser {

  static buildInspectScript(): string {
    return `
(function() {
  var r = {
    url: (window.location.hostname || '') + (window.location.pathname || ''),
    title: document.title || '',
    tables: [],
    iframes: [],
    semesterSelect: null
  };

  var semSelect = document.querySelector('select[name="zxjxjhh"], select#zxjxjhh');
  if (semSelect) {
    var opts = [];
    for (var i = 0; i < semSelect.options.length; i++) {
      var o = semSelect.options[i];
      opts.push({ value: o.value || '', text: (o.textContent || '').trim(), selected: o.selected });
    }
    r.semesterSelect = { name: semSelect.name || semSelect.id || '', options: opts };
  }

  var tables = document.querySelectorAll('table');
  for (var t = 0; t < tables.length && t < 15; t++) {
    var table = tables[t];
    var headers = [];
    var ths = table.querySelectorAll('tr:first-child > *, thead tr:first-child > *');
    for (var h = 0; h < ths.length && h < 20; h++) {
      headers.push((ths[h].textContent || '').trim().substring(0, 40));
    }
    var rows = table.querySelectorAll('tr');
    r.tables.push({
      headerCount: ths.length,
      headers: headers,
      rowCount: rows.length,
      className: (table.className || '').substring(0, 60),
      id: (table.id || '').substring(0, 60)
    });
  }

  var iframes = document.querySelectorAll('iframe');
  for (var m = 0; m < iframes.length && m < 5; m++) {
    r.iframes.push({ src: safeUrlPath(iframes[m].src || ''), id: iframes[m].id || '' });
  }

  function safeUrlPath(raw) {
    if (!raw) return '';
    try {
      var parsed = new URL(raw, window.location.origin);
      return parsed.hostname + parsed.pathname;
    } catch (_) {
      return '';
    }
  }

  return JSON.stringify(r);
})();
`;
  }

  static buildExtractScript(): string {
    return `
(function() {
  var result = {
    courses: [],
    termCode: '',
    termLabel: '',
    currentTeachingWeek: 0,
    semesterStartDate: '',
    recognized: false
  };

  var semSelect = document.querySelector('select[name="zxjxjhh"], select#zxjxjhh');
  if (semSelect) {
    var selOpt = semSelect.options[semSelect.selectedIndex];
    if (selOpt) {
      result.termCode = selOpt.value || '';
      result.termLabel = (selOpt.textContent || '').trim();
    }
  }
  if (!result.termCode) {
    var queryTerm = new URLSearchParams(window.location.search).get('zxjxjhh');
    if (queryTerm) result.termCode = queryTerm;
  }
  if (!result.termLabel) {
    var headingText = '';
    var heading = document.querySelector('h1, h2, h3, .page-title, .panel-title');
    if (heading) headingText = (heading.textContent || '').trim();
    var termMatch = headingText.match(/20\\d{2}\\s*[-~至]\\s*20\\d{2}[^\\n]{0,16}学期/);
    if (termMatch) result.termLabel = termMatch[0];
  }
  var weekFeature = document.querySelector(
    '[data-current-week], #currentWeek, .current-week, [name="currentWeek"]'
  );
  var weekFeatureText = weekFeature ?
    ((weekFeature.getAttribute('data-current-week') || weekFeature.value ||
      weekFeature.textContent || '') + '') : '';
  var pageText = document.body && document.body.innerText ? document.body.innerText : '';
  var weekMatch = weekFeatureText.match(/\\d{1,2}/) ||
    pageText.match(/(?:当前教学周|当前周次|本周为)\\s*[:：]?\\s*第?\\s*(\\d{1,2})\\s*周/);
  if (weekMatch) {
    var parsedWeek = parseInt(weekMatch.length > 1 ? weekMatch[1] : weekMatch[0]);
    if (parsedWeek >= 1 && parsedWeek <= 30) result.currentTeachingWeek = parsedWeek;
  }
  var startFeature = document.querySelector(
    '[data-semester-start], #semesterStartDate, [name="semesterStartDate"], [name="xqksrq"]'
  );
  if (startFeature) {
    var startText = (startFeature.getAttribute('data-semester-start') ||
      startFeature.value || startFeature.textContent || '') + '';
    var startMatch = startText.match(/20\\d{2}[-\\/.]\\d{1,2}[-\\/.]\\d{1,2}/);
    if (startMatch) result.semesterStartDate = startMatch[0].replace(/[\\/.]/g, '-');
  }

  var tables = document.querySelectorAll('table');
  var bestTable = null;
  var bestDayMap = null;
  var bestScore = 0;

  for (var t = 0; t < tables.length; t++) {
    var dayMap = buildDayMap(tables[t]);
    if (dayMap === null) continue;
    var score = scoreTable(tables[t], dayMap);
    if (score > bestScore) {
      bestScore = score;
      bestTable = tables[t];
      bestDayMap = dayMap;
    }
  }

  if (bestTable === null || bestDayMap === null) {
    return JSON.stringify(result);
  }
  result.recognized = true;

  var courses = {};
  var rows = bestTable.querySelectorAll('tr');

  for (var r = 0; r < rows.length; r++) {
    var cells = rows[r].children;
    if (cells.length <= 1) continue;

    var periodInfo = parsePeriod(cells[0]);
    if (periodInfo === null) continue;

    for (var c = 1; c < cells.length; c++) {
      var dayOfWeek = bestDayMap[c];
      if (dayOfWeek === undefined || dayOfWeek === 0) continue;

      var cell = cells[c];
      var courseBlocks = findCourseBlocks(cell);
      if (courseBlocks.length === 0) continue;

      for (var b = 0; b < courseBlocks.length; b++) {
        var block = courseBlocks[b];
        var course = parseCourseBlock(block, dayOfWeek, periodInfo);
        if (course === null) continue;

        var key = '';
        if (course.courseCode) {
          key = result.termCode + '|' + course.courseCode + '|' + (course.section || '');
        } else {
          key = result.termCode + '|' + (course.name || '') + '|' + (course.teacher || '');
        }
        if (key === '|') key = 'c' + r + '_' + c;

        if (courses[key] !== undefined && courses[key].teacher !== course.teacher) {
          key += '|' + (course.teacher || 'UNKNOWN_TEACHER');
        }
        if (courses[key] === undefined) {
          courses[key] = course;
          courses[key].sessions = [];
        }
        var session = makeSession(dayOfWeek, periodInfo, course);
        courses[key].sessions.push(session);
      }
    }
  }

  var list = [];
  var keys = Object.keys(courses);
  for (var k = 0; k < keys.length; k++) {
    var cr = courses[keys[k]];
    cr.termCode = result.termCode || 'UNKNOWN_TERM';
    cr.termLabel = result.termLabel || '';
    list.push(cr);
  }
  result.courses = list;
  return JSON.stringify(result);

  function buildDayMap(table) {
    var firstRow = table.querySelector('tr');
    if (!firstRow) return null;
    var cells = firstRow.children;
    if (cells.length < 3) return null;
    var map = {};
    var dayCount = 0;
    for (var i = 0; i < cells.length; i++) {
      var txt = (cells[i].textContent || '').trim();
      if (txt.indexOf('一') >= 0) { map[i] = 1; dayCount++; }
      else if (txt.indexOf('二') >= 0) { map[i] = 2; dayCount++; }
      else if (txt.indexOf('三') >= 0) { map[i] = 3; dayCount++; }
      else if (txt.indexOf('四') >= 0) { map[i] = 4; dayCount++; }
      else if (txt.indexOf('五') >= 0) { map[i] = 5; dayCount++; }
      else if (txt.indexOf('六') >= 0) { map[i] = 6; dayCount++; }
      else if (txt.indexOf('日') >= 0) { map[i] = 7; dayCount++; }
    }
    if (dayCount < 5) return null;
    return map;
  }

  function scoreTable(table, dayMap) {
    var score = 0;
    score += Object.keys(dayMap).length * 5;
    var rows = table.querySelectorAll('tr');
    var periodCount = 0;
    var timeCount = 0;
    var courseCellCount = 0;
    var codeCount = 0;
    var weekCount = 0;
    var teacherCount = 0;
    var locationCount = 0;
    for (var rr = 0; rr < rows.length; rr++) {
      var cells = rows[rr].children;
      if (cells.length <= 1) continue;
      var parsedPeriod = parsePeriod(cells[0]);
      if (parsedPeriod !== null) {
        periodCount++;
        if (parsedPeriod.timeStart && parsedPeriod.timeEnd) timeCount++;
      }
      for (var cc = 1; cc < cells.length; cc++) {
        if (dayMap[cc] === undefined) continue;
        var blocks = findCourseBlocks(cells[cc]);
        if (blocks.length > 0) {
          courseCellCount++;
          for (var featureIndex = 0; featureIndex < blocks.length; featureIndex++) {
            var featureBlock = blocks[featureIndex];
            var featureText = (featureBlock.textContent || '').trim();
            if (/[A-Z]\\d{6}[A-Z]?/.test(featureText)) codeCount++;
            if (/第?\\s*\\d{1,2}[^\\n]{0,24}周|单周|双周/.test(featureText)) weekCount++;
            if (featureBlock.querySelector('i, .teacher, [data-teacher]')) teacherCount++;
            if (featureBlock.querySelector('span.text-muted, .location, [data-location]') ||
                /校区|教学楼|教室|馆/.test(featureText)) locationCount++;
          }
        }
      }
    }
    score += periodCount * 3;
    score += timeCount * 2;
    score += courseCellCount * 4;
    score += codeCount * 2;
    score += weekCount * 2;
    score += teacherCount;
    score += locationCount;
    return score;
  }

  function parsePeriod(cell) {
    if (!cell) return null;
    var txt = (cell.textContent || '').trim();
    if (txt.length === 0) return null;
    var numMatch = txt.match(/\\d+/);
    if (!numMatch) return null;
    var period = parseInt(numMatch[0]);
    if (period < 1 || period > 16) return null;
    var timeStart = '';
    var timeEnd = '';
    var timeMatch = txt.match(/(\\d{1,2}:\\d{2})\\s*[-~\\u2013\\u2014]\\s*(\\d{1,2}:\\d{2})/);
    if (timeMatch) {
      timeStart = timeMatch[1];
      timeEnd = timeMatch[2];
    }
    return { period: period, timeStart: timeStart, timeEnd: timeEnd };
  }

  function findCourseBlocks(cell) {
    var blocks = [];
    var children = cell.children;
    if (children.length > 0) {
      for (var i = 0; i < children.length; i++) {
        var ch = children[i];
        if (isSemanticBlock(ch)) blocks.push(ch);
      }
    } else {
      if (isSemanticBlock(cell)) blocks.push(cell);
    }
    return blocks;
  }

  function isSemanticBlock(el) {
    var html = (el.innerHTML || '').trim();
    var txt = (el.textContent || '').trim();
    if (html.length === 0 && txt.length === 0) return false;
    var hasCode = /[A-Z]\\d{6}/.test(txt);
    var hasDigit = /\\d/.test(txt);
    var hasClass = html.indexOf('max-width') >= 0 || html.indexOf('text-muted') >= 0;
    var hasBr = html.indexOf('<br') >= 0;
    return (hasCode || hasClass || hasBr || txt.length > 6) && hasDigit;
  }

  function parseCourseBlock(el, dayOfWeek, periodInfo) {
    var html = el.innerHTML || '';
    var txt = (el.textContent || '').trim();

    var codeAndSection = '';
    var nameText = '';
    var section = '';

    var brParts = html.split(/<br\\s*\\/?>/i);
    if (brParts.length >= 2) {
      var div1 = document.createElement('div');
      div1.innerHTML = brParts[0];
      codeAndSection = (div1.textContent || '').trim();

      var div2 = document.createElement('div');
      div2.innerHTML = brParts[1];
      var nameSpan = div2.querySelector('span');
      nameText = nameSpan ? (nameSpan.textContent || '').trim() : (div2.textContent || '').trim();
    } else {
      nameText = txt.substring(0, 80);
    }

    var sectionMatch = codeAndSection.match(/\\[(\\d+)\\]/);
    if (sectionMatch) section = sectionMatch[1];

    var courseCode = codeAndSection.replace(/\\[\\d+\\]/g, '').replace(/\\s+/g, ' ').trim();

    var timeText = '';
    var timeEl = el.querySelector('div[style*="max-width"]');
    if (timeEl) timeText = (timeEl.textContent || '').trim();

    var teacher = '';
    var teacherEl = el.querySelector('i');
    if (teacherEl) teacher = (teacherEl.textContent || '').trim();

    var locationText = '';
    var locEl = el.querySelector('span.text-muted');
    if (locEl) locationText = (locEl.textContent || '').trim();

    var courseType = '';
    var typeEl = el.querySelector('[data-course-type], [data-course-nature], .course-type, .course-nature');
    if (typeEl) {
      courseType = (typeEl.getAttribute('data-course-type') ||
        typeEl.getAttribute('data-course-nature') || typeEl.textContent || '').trim();
    }
    if (!courseType) {
      var typeMatch = txt.match(/(?:课程)?(?:性质|类型)\\s*[:：]\\s*([^\\n,，;；]{1,24})/);
      if (typeMatch) courseType = (typeMatch[1] || '').trim();
    }

    var weekInfo = parseWeeks(timeText);

    return {
      courseCode: courseCode,
      section: section,
      name: nameText || courseCode,
      teacher: teacher,
      type: courseType,
      weekInfo: weekInfo,
      locationText: locationText,
      timeRange: timeText,
      isTemporary: false,
      isCancelled: false
    };
  }

  function parseWeeks(text) {
    var info = { startWeek: 1, endWeek: 16, weekType: 'every', weekNumbers: [], discontinuousWeeks: '' };
    if (!text) return info;

    if (text.indexOf('单') >= 0) info.weekType = 'odd';
    if (text.indexOf('双') >= 0) info.weekType = 'even';

    var clean = text.replace(/[０-９]/g, function(ch) {
        return String.fromCharCode(ch.charCodeAt(0) - 65248);
      })
      .replace(/第/g, '').replace(/周/g, '').replace(/单/g, '').replace(/双/g, '')
      .replace(/（/g, '(').replace(/）/g, ')').replace(/，/g, ',').replace(/\\uff0c/g, ',')
      .replace(/[、；;]/g, ',').replace(/\\uff0d/g, '-').replace(/\\u2013/g, '-')
      .replace(/\\u2014/g, '-').replace(/[()]/g, '').replace(/\\s+/g, '');

    var weeks = [];
    var parts = clean.split(',');
    for (var p = 0; p < parts.length; p++) {
      var part = parts[p].trim();
      if (part.length === 0) continue;
      var rangeParts = part.split(/[-~]/);
      if (rangeParts.length === 2) {
        var s = parseInt(rangeParts[0]);
        var e = parseInt(rangeParts[1]);
        if (!isNaN(s) && !isNaN(e) && s >= 1 && s <= 30 && e >= s) {
          for (var w = s; w <= e; w++) weeks.push(w);
        }
      } else {
        var single = parseInt(part);
        if (!isNaN(single) && single >= 1 && single <= 30) weeks.push(single);
      }
    }

    if (weeks.length > 0) {
      weeks.sort(function(a, b) { return a - b; });
      weeks = weeks.filter(function(value, index, arr) {
        return index === 0 || value !== arr[index - 1];
      });
      if (info.weekType === 'odd') {
        weeks = weeks.filter(function(value) { return value % 2 === 1; });
      } else if (info.weekType === 'even') {
        weeks = weeks.filter(function(value) { return value % 2 === 0; });
      }
      if (weeks.length === 0) return info;
      info.startWeek = weeks[0];
      info.endWeek = weeks[weeks.length - 1];
      info.weekNumbers = weeks;
      if (weeks.length < info.endWeek - info.startWeek + 1) {
        info.discontinuousWeeks = weeks.join(',');
      }
    }
    return info;
  }

  function makeSession(dayOfWeek, periodInfo, course) {
    var locationParts = (course.locationText || '').split(/[,，]/);
    var campus = locationParts.length > 0 ? locationParts[0].trim() : '';
    var building = locationParts.length > 1 ? locationParts[1].trim() : '';
    var room = locationParts.length > 2 ? locationParts.slice(2).join(',').trim() : '';
    return {
      dayOfWeek: dayOfWeek,
      startPeriod: periodInfo.period,
      endPeriod: periodInfo.period,
      startWeek: course.weekInfo.startWeek,
      endWeek: course.weekInfo.endWeek,
      weekType: course.weekInfo.weekType,
      weekNumbers: course.weekInfo.weekNumbers,
      discontinuousWeeks: course.weekInfo.discontinuousWeeks,
      classroom: course.locationText,
      campus: campus,
      building: building,
      room: room,
      locationText: course.locationText,
      timeRange: periodInfo.timeStart && periodInfo.timeEnd ?
        periodInfo.timeStart + '-' + periodInfo.timeEnd : '',
      weeksRaw: course.timeRange
    };
  }

})();
`;
  }

  static parseCourseJson(jsonStr: string): Array<CourseInfo> {
    const result: Array<CourseInfo> = [];
    if (jsonStr.length === 0) {
      return result;
    }
    const raw: Object = JSON.parse(ScriptResultDecoder.unwrap(jsonStr));
    if (!Array.isArray(raw)) {
      const wrapper: Record<string, Object> = raw as Record<string, Object>;
      const coursesArr: Object | undefined = wrapper['courses'];
      if (coursesArr === undefined || !Array.isArray(coursesArr)) {
        return result;
      }
      const arr: Array<Object> = coursesArr as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const item: Record<string, Object> = arr[i] as Record<string, Object>;
        const course: CourseInfo = CourseParser.parseSingleCourse(item);
        result.push(course);
      }
      return result;
    }
    const arr: Array<Object> = raw as Array<Object>;
    for (let i = 0; i < arr.length; i++) {
      const item: Record<string, Object> = arr[i] as Record<string, Object>;
      const course: CourseInfo = CourseParser.parseSingleCourse(item);
      result.push(course);
    }
    return result;
  }

  static parseWeeksText(text: string): ParsedWeekInfo {
    const info: ParsedWeekInfo = new ParsedWeekInfo();
    if (text.trim().length === 0) {
      return info;
    }
    if (text.includes('单')) {
      info.weekType = 'odd';
    } else if (text.includes('双')) {
      info.weekType = 'even';
    }
    const fullWidthDigits: string = '０１２３４５６７８９';
    let normalized: string = '';
    for (let i = 0; i < text.length; i++) {
      const index: number = fullWidthDigits.indexOf(text[i]);
      normalized += index >= 0 ? index.toString() : text[i];
    }
    normalized = normalized
      .replace(new RegExp('[第周单双（）()]', 'g'), '')
      .replace(new RegExp('[，、；;]', 'g'), ',')
      .replace(new RegExp('[－–—~～]', 'g'), '-')
      .replace(new RegExp('\\s+', 'g'), '');
    const numbers: Array<number> = [];
    const parts: Array<string> = normalized.split(',');
    for (let i = 0; i < parts.length; i++) {
      const part: string = parts[i];
      if (part.length === 0) {
        continue;
      }
      const range: Array<string> = part.split('-');
      if (range.length === 2) {
        const start: number = parseInt(range[0]);
        const end: number = parseInt(range[1]);
        if (!isNaN(start) && !isNaN(end) && start >= 1 && end >= start && end <= 30) {
          for (let week = start; week <= end; week++) {
            numbers.push(week);
          }
        }
      } else {
        const week: number = parseInt(part);
        if (!isNaN(week) && week >= 1 && week <= 30) {
          numbers.push(week);
        }
      }
    }
    numbers.sort((a: number, b: number): number => a - b);
    for (let i = 0; i < numbers.length; i++) {
      const week: number = numbers[i];
      if (info.weekType === 'odd' && week % 2 === 0) {
        continue;
      }
      if (info.weekType === 'even' && week % 2 !== 0) {
        continue;
      }
      if (info.weekNumbers.length === 0 || info.weekNumbers[info.weekNumbers.length - 1] !== week) {
        info.weekNumbers.push(week);
      }
    }
    if (info.weekNumbers.length > 0) {
      info.startWeek = info.weekNumbers[0];
      info.endWeek = info.weekNumbers[info.weekNumbers.length - 1];
      if (info.weekNumbers.length < info.endWeek - info.startWeek + 1) {
        info.discontinuousWeeks = info.weekNumbers.join(',');
      }
    }
    return info;
  }

  static parseSemesterFromResult(extractResultJson: string): SemesterInfo {
    const semester: SemesterInfo = new SemesterInfo();
    if (extractResultJson.length === 0) {
      return semester;
    }
    const raw: Object = JSON.parse(ScriptResultDecoder.unwrap(extractResultJson));
    const item: Record<string, Object> = raw as Record<string, Object>;
    const termCode: string = (item['termCode'] as string) ?? '';
    const termLabel: string = (item['termLabel'] as string) ?? '';
    semester.currentTeachingWeek = (item['currentTeachingWeek'] as number) ?? 0;
    semester.startDate = (item['semesterStartDate'] as string) ?? '';
    if (termCode.length > 0) {
      semester.termCode = termCode;
    }
    if (termLabel.length > 0) {
      semester.termLabel = termLabel;
      const yearMatch: RegExpMatchArray | null = termLabel.match(new RegExp('(\\d{4})\\s*[-~至]\\s*(\\d{4})'));
      if (yearMatch !== null && yearMatch.length >= 3) {
        semester.academicYear = yearMatch[1] + '-' + yearMatch[2];
      }
      if (termLabel.includes('第一学期') || termLabel.includes('秋')) {
        semester.semester = '1';
      } else if (termLabel.includes('第二学期') || termLabel.includes('春')) {
        semester.semester = '2';
      } else if (termLabel.includes('第三学期') || termLabel.includes('夏')) {
        semester.semester = '3';
      }
    }
    if (semester.startDate.length === 0) {
      semester.startDate = AcademicCalendar.knownStartDate(semester.termCode, semester.termLabel);
    }
    const calendarWeeks: number =
      AcademicCalendar.knownTotalWeeks(semester.termCode, semester.termLabel);
    if (calendarWeeks > 0) {
      semester.totalWeeks = calendarWeeks;
    }
    if (semester.startDate.length === 0 && semester.currentTeachingWeek > 0) {
      const now: Date = new Date();
      const mondayOffset: number = now.getDay() === 0 ? 6 : now.getDay() - 1;
      const start: Date = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() - mondayOffset - (semester.currentTeachingWeek - 1) * 7
      );
      const month: string = start.getMonth() + 1 < 10 ?
        '0' + (start.getMonth() + 1).toString() : (start.getMonth() + 1).toString();
      const day: string = start.getDate() < 10 ?
        '0' + start.getDate().toString() : start.getDate().toString();
      semester.startDate = start.getFullYear().toString() + '-' + month + '-' + day;
    }
    return semester;
  }

  private static parseSingleCourse(item: Record<string, Object>): CourseInfo {
    const course: CourseInfo = new CourseInfo();
    course.courseCode = (item['courseCode'] as string) ?? '';
    course.section = (item['section'] as string) ?? '';
    course.name = (item['name'] as string) ?? '';
    course.teacher = (item['teacher'] as string) ?? '';
    course.courseType = (item['type'] as string) ?? (item['courseType'] as string) ?? '';
    course.isTemporary = (item['isTemporary'] as boolean) ?? false;
    course.isCancelled = (item['isCancelled'] as boolean) ?? false;
    course.termCode = (item['termCode'] as string) ?? '';
    course.termLabel = (item['termLabel'] as string) ?? '';
    course.id = course.termCode + '|' +
      (course.courseCode.length > 0 ? course.courseCode + '|' + course.section :
        course.name + '|' + course.teacher);
    course.syncedAt = Date.now();
    course.updateTime = course.syncedAt;

    const sessionsRaw: Object | undefined = item['sessions'];
    if (sessionsRaw !== undefined && Array.isArray(sessionsRaw)) {
      const sessionsArr: Array<Object> = sessionsRaw as Array<Object>;
      for (let j = 0; j < sessionsArr.length; j++) {
        const sItem: Record<string, Object> = sessionsArr[j] as Record<string, Object>;
        const session: CourseSession = new CourseSession();
        session.dayOfWeek = (sItem['dayOfWeek'] as number) ?? 0;
        session.startPeriod = (sItem['startPeriod'] as number) ?? 0;
        session.endPeriod = (sItem['endPeriod'] as number) ?? 0;
        session.startWeek = (sItem['startWeek'] as number) ?? 0;
        session.endWeek = (sItem['endWeek'] as number) ?? 0;
        session.weekType = (sItem['weekType'] as string) ?? 'every';
        const weekNumbersRaw: Object | undefined = sItem['weekNumbers'];
        if (weekNumbersRaw !== undefined && Array.isArray(weekNumbersRaw)) {
          session.weekNumbers = weekNumbersRaw as Array<number>;
        }
        session.discontinuousWeeks = (sItem['discontinuousWeeks'] as string) ?? '';
        session.classroom = (sItem['classroom'] as string) ?? (sItem['locationText'] as string) ?? '';
        session.locationText = (sItem['locationText'] as string) ?? '';
        session.campus = (sItem['campus'] as string) ?? '';
        session.building = (sItem['building'] as string) ?? '';
        session.room = (sItem['room'] as string) ?? '';
        session.timeRange = (sItem['timeRange'] as string) ?? '';
        session.weeksRaw = (sItem['weeksRaw'] as string) ?? '';
        course.sessions.push(session);
      }
    }
    course.sessions = CourseParser.mergeCompatibleSessions(course.sessions);
    return course;
  }

  static mergeCompatibleSessions(sessions: Array<CourseSession>): Array<CourseSession> {
    if (sessions.length <= 1) {
      return sessions;
    }
    const sorted: Array<CourseSession> = sessions.slice(0).sort(
      (first: CourseSession, second: CourseSession): number => {
        if (first.dayOfWeek !== second.dayOfWeek) {
          return first.dayOfWeek - second.dayOfWeek;
        }
        return first.startPeriod - second.startPeriod;
      }
    );
    const merged: Array<CourseSession> = [sorted[0]];
    for (let i = 1; i < sorted.length; i++) {
      const previous: CourseSession = merged[merged.length - 1];
      const current: CourseSession = sorted[i];
      if (CourseParser.canMergeSessions(previous, current)) {
        previous.endPeriod = current.endPeriod;
        previous.timeRange = CourseParser.mergeTimeRange(previous.timeRange, current.timeRange);
      } else {
        merged.push(current);
      }
    }
    return merged;
  }

  private static canMergeSessions(first: CourseSession, second: CourseSession): boolean {
    return first.dayOfWeek === second.dayOfWeek &&
      second.startPeriod === first.endPeriod + 1 &&
      first.startWeek === second.startWeek && first.endWeek === second.endWeek &&
      first.weekType === second.weekType &&
      first.discontinuousWeeks === second.discontinuousWeeks &&
      first.weekNumbers.join(',') === second.weekNumbers.join(',') &&
      first.locationText === second.locationText && first.classroom === second.classroom &&
      first.campus === second.campus && first.building === second.building && first.room === second.room;
  }

  private static mergeTimeRange(first: string, second: string): string {
    const firstMatch: RegExpMatchArray | null = first.match(
      new RegExp('(\\d{1,2}:\\d{2})\\s*[-~—–至]\\s*(\\d{1,2}:\\d{2})'));
    const secondMatch: RegExpMatchArray | null = second.match(
      new RegExp('(\\d{1,2}:\\d{2})\\s*[-~—–至]\\s*(\\d{1,2}:\\d{2})'));
    if (firstMatch !== null && secondMatch !== null) {
      return firstMatch[1] + '-' + secondMatch[2];
    }
    return first.length > 0 ? first : second;
  }
}
