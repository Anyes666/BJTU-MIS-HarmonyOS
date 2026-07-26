import { describe, expect, it } from '@ohos/hypium';
import { webview } from '@kit.ArkWeb';
import { CourseParser, ParsedWeekInfo } from '../../../main/ets/parser/CourseParser';
import { ExamParser, ExamParseResult } from '../../../main/ets/parser/ExamParser';
import { GradeParser, GradeParseResult } from '../../../main/ets/parser/GradeParser';
import { GradeDetailParser } from '../../../main/ets/parser/GradeDetailParser';
import { PageInspector } from '../../../main/ets/parser/PageInspector';
import { ScriptResultDecoder } from '../../../main/ets/parser/ScriptResultDecoder';
import { CourseInfo, CourseSession } from '../../../main/ets/model/CourseInfo';
import { ExamInfo } from '../../../main/ets/model/ExamInfo';
import { ExamTimeline } from '../../../main/ets/model/ExamTimeline';
import { FIRST_GRADE_TERM, GradeInfo, GradeTermOrder } from '../../../main/ets/model/GradeInfo';
import { GradeMetrics } from '../../../main/ets/model/GradeMetrics';
import { LoginState, loginStateLabel } from '../../../main/ets/model/LoginState';
import { SyncCoordinator } from '../../../main/ets/manager/SyncCoordinator';
import { SyncPhase, SyncStatus } from '../../../main/ets/model/SyncStatus';
import { AcademicCalendar, AcademicWeekRange } from '../../../main/ets/model/AcademicCalendar';
import { CampusParser } from '../../../main/ets/parser/CampusParser';
import { MailParser } from '../../../main/ets/parser/MailParser';
import { AcademicProgress, CampusCalendar, StudentProfile } from '../../../main/ets/model/CampusInfo';

export default function parserTest(): void {
  describe('CourseParserFixtureTest', () => {
    it('normalCourseAndMultipleSessions', 0, () => {
      const fixture: string =
        '{"recognized":true,"termCode":"2025-2026-1","termLabel":"2025-2026学年第一学期",' +
        '"courses":[{"courseCode":"A123456","section":"01","name":"脱敏课程甲","teacher":"教师甲",' +
        '"type":"专业必修",' +
        '"termCode":"2025-2026-1","sessions":[' +
        '{"dayOfWeek":1,"startPeriod":1,"endPeriod":2,"startWeek":1,"endWeek":16,' +
        '"weekNumbers":[1,2,3,4],"weekType":"every","locationText":"主校区,楼甲,101",' +
        '"timeRange":"08:00-09:35","weeksRaw":"第1-4周"},' +
        '{"dayOfWeek":3,"startPeriod":5,"endPeriod":6,"startWeek":9,"endWeek":16,' +
        '"weekNumbers":[9,10,11,12,13,14,15,16],"weekType":"every",' +
        '"locationText":"主校区,楼乙,202","weeksRaw":"9-16周"}]}]}';
      const courses: Array<CourseInfo> = CourseParser.parseCourseJson(fixture);
      expect(courses.length).assertEqual(1);
      expect(courses[0].sessions.length).assertEqual(2);
      expect(courses[0].sessions[1].weekNumbers[0]).assertEqual(9);
      expect(courses[0].sessions[0].weeksRaw).assertEqual('第1-4周');
      expect(courses[0].courseType).assertEqual('专业必修');
    });

    it('multipleCoursesInOneCellRemainDistinct', 0, () => {
      const fixture: string =
        '{"courses":[{"courseCode":"A123456","section":"01","name":"课程甲","teacher":"教师甲",' +
        '"termCode":"T1","sessions":[{"dayOfWeek":2,"startPeriod":1,"endPeriod":2}]},' +
        '{"courseCode":"B123456","section":"02","name":"课程乙","teacher":"教师乙",' +
        '"termCode":"T1","sessions":[{"dayOfWeek":2,"startPeriod":1,"endPeriod":2}]}]}';
      const courses: Array<CourseInfo> = CourseParser.parseCourseJson(fixture);
      expect(courses.length).assertEqual(2);
      expect(courses[0].courseCode === courses[1].courseCode).assertFalse();
    });

    it('continuousSessionsMergeOnlyWhenWeeksAndLocationMatch', 0, () => {
      const first: CourseSession = new CourseSession();
      first.dayOfWeek = 1; first.startPeriod = 1; first.endPeriod = 1;
      first.startWeek = 1; first.endWeek = 16; first.weekNumbers = [1, 2, 3, 4];
      first.locationText = '主校区,楼甲,101'; first.classroom = first.locationText;
      first.campus = '主校区'; first.building = '楼甲'; first.room = '101';
      first.timeRange = '08:00-09:35';
      const second: CourseSession = new CourseSession();
      second.dayOfWeek = 1; second.startPeriod = 2; second.endPeriod = 2;
      second.startWeek = 1; second.endWeek = 16; second.weekNumbers = [1, 2, 3, 4];
      second.locationText = first.locationText; second.classroom = first.classroom;
      second.campus = first.campus; second.building = first.building; second.room = first.room;
      second.timeRange = '09:50-11:25';
      const differentRoom: CourseSession = new CourseSession();
      differentRoom.dayOfWeek = 1; differentRoom.startPeriod = 3; differentRoom.endPeriod = 3;
      differentRoom.startWeek = 1; differentRoom.endWeek = 16; differentRoom.weekNumbers = [1, 2, 3, 4];
      differentRoom.locationText = '主校区,楼甲,102'; differentRoom.classroom = differentRoom.locationText;
      differentRoom.campus = '主校区'; differentRoom.building = '楼甲'; differentRoom.room = '102';
      const merged: Array<CourseSession> = CourseParser.mergeCompatibleSessions(
        [differentRoom, second, first]);
      expect(merged.length).assertEqual(2);
      expect(merged[0].startPeriod).assertEqual(1);
      expect(merged[0].endPeriod).assertEqual(2);
      expect(merged[0].timeRange).assertEqual('08:00-11:25');
    });

    it('currentTermFilterExcludesHistoricalTimetables', 0, () => {
      const current: CourseInfo = new CourseInfo(); current.termCode = 'T2';
      const historical: CourseInfo = new CourseInfo(); historical.termCode = 'T1';
      const filtered: Array<CourseInfo> = CourseInfo.filterByTerm([historical, current], 'T2');
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].termCode).assertEqual('T2');
      expect(CourseInfo.filterByTerm([historical, current], '').length).assertEqual(0);
      expect(CourseInfo.filterByTerm([historical, current], 'UNKNOWN_TERM').length).assertEqual(0);
    });

    it('currentTermFilterNormalizesOfficialTermVariants', 0, () => {
      const current: CourseInfo = new CourseInfo();
      current.termCode = '2025-2026-02';
      current.termLabel = '2025-2026 学年第二学期';
      const historical: CourseInfo = new CourseInfo();
      historical.termCode = '2025-2026-1';
      const filtered: Array<CourseInfo> = CourseInfo.filterByTerm(
        [historical, current],
        '2025—2026-2',
        '2025-2026 学年第二学期'
      );
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].termCode).assertEqual('2025-2026-02');
    });

    it('currentTermFilterUsesUnambiguousCurrentTimetableCache', 0, () => {
      const first: CourseInfo = new CourseInfo(); first.termCode = 'opaque-current';
      const second: CourseInfo = new CourseInfo(); second.termCode = 'opaque-current';
      expect(CourseInfo.filterByTerm(
        [first, second],
        '2025-2026-2'
      ).length).assertEqual(2);
    });

    it('currentTermFilterUsesNewestOfficialTimetableSnapshot', 0, () => {
      const historical: CourseInfo = new CourseInfo();
      historical.termCode = '2025-2026-1';
      historical.syncedAt = 100;
      const current: CourseInfo = new CourseInfo();
      current.termCode = 'opaque-current';
      current.syncedAt = 200;
      const filtered: Array<CourseInfo> = CourseInfo.filterByTerm(
        [historical, current],
        'UNKNOWN_TERM'
      );
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].termCode).assertEqual('opaque-current');
    });

    it('currentTermFilterKeepsSingleUnknownLegacySnapshot', 0, () => {
      const course: CourseInfo = new CourseInfo();
      course.termCode = 'UNKNOWN_TERM';
      expect(CourseInfo.filterByTerm(
        [course],
        'UNKNOWN_TERM'
      ).length).assertEqual(1);
    });

    it('parsesContinuousAndNineToSixteenWeeks', 0, () => {
      const full: ParsedWeekInfo = CourseParser.parseWeeksText('第01-16周');
      const late: ParsedWeekInfo = CourseParser.parseWeeksText('9-16周');
      expect(full.weekNumbers.length).assertEqual(16);
      expect(late.startWeek).assertEqual(9);
      expect(late.endWeek).assertEqual(16);
    });

    it('parsesOddWeeksWithFullWidthCharacters', 0, () => {
      const info: ParsedWeekInfo = CourseParser.parseWeeksText('第０１－１６周（单周）');
      expect(info.weekType).assertEqual('odd');
      expect(info.weekNumbers.join(',')).assertEqual('1,3,5,7,9,11,13,15');
    });

    it('parsesEvenWeeks', 0, () => {
      const info: ParsedWeekInfo = CourseParser.parseWeeksText('第02—16周（双周）');
      expect(info.weekType).assertEqual('even');
      expect(info.weekNumbers.join(',')).assertEqual('2,4,6,8,10,12,14,16');
    });

    it('parsesDiscontinuousWeeksAndChineseSeparators', 0, () => {
      const info: ParsedWeekInfo = CourseParser.parseWeeksText('1-4、7-12周；15周');
      expect(info.weekNumbers.join(',')).assertEqual('1,2,3,4,7,8,9,10,11,12,15');
      expect(info.discontinuousWeeks.length > 0).assertTrue();
    });

    it('containsOnlyExplicitWeeks', 0, () => {
      const session: CourseSession = new CourseSession();
      session.startWeek = 1;
      session.endWeek = 8;
      session.weekNumbers = [1, 3, 6, 8];
      expect(session.containsWeek(3)).assertTrue();
      expect(session.containsWeek(4)).assertFalse();
    });

    it('emptyScheduleIsLegalParsedFixture', 0, () => {
      const courses: Array<CourseInfo> = CourseParser.parseCourseJson(
        '{"recognized":true,"courses":[]}'
      );
      expect(courses.length).assertEqual(0);
    });

    it('scriptScoresMultipleTablesAndHandlesDomVariation', 0, () => {
      const script: string = CourseParser.buildExtractScript();
      expect(script.includes("querySelectorAll('table')")).assertTrue();
      expect(script.includes('scoreTable')).assertTrue();
      expect(script.includes('bestScore')).assertTrue();
      expect(script.includes('teacherCount')).assertTrue();
      expect(script.includes('locationCount')).assertTrue();
      expect(script.includes('rows[r].children')).assertTrue();
      expect(script.includes('findCourseBlocks')).assertTrue();
      expect(script.includes('[data-course-nature]')).assertTrue();
      expect(script.includes('cr.sessions = mergeSessions')).assertFalse();
    });

    it('pageInspectorRecognizesExpiredAndForbiddenAuthPages', 0, () => {
      const script: string = PageInspector.buildPageStateScript();
      expect(script.includes('会话已过期')).assertTrue();
      expect(script.includes('找回密码')).assertTrue();
      expect(script.includes('二次认证')).assertTrue();
      expect(script.includes('var hasLoginForm = !!passwordInput || !!loginForm;')).assertTrue();
      expect(script.includes('校园信息门户')).assertTrue();
    });

    it('unwrapsArkWebStringEncodedJsonResults', 0, () => {
      const inner: string = '{"recognized":true,"courses":[]}';
      expect(ScriptResultDecoder.unwrap(JSON.stringify(inner))).assertEqual(inner);
      expect(ScriptResultDecoder.unwrap(inner)).assertEqual(inner);
    });

    it('semesterFixtureCarriesTeachingWeekAndStartDate', 0, () => {
      const semester = CourseParser.parseSemesterFromResult(
        '{"termCode":"T1","termLabel":"2025-2026学年第一学期",' +
        '"currentTeachingWeek":6,"semesterStartDate":"2025-09-01"}'
      );
      expect(semester.currentTeachingWeek).assertEqual(6);
      expect(semester.startDate).assertEqual('2025-09-01');
    });

    it('academicCalendarNormalizesMisTerms', 0, () => {
      expect(AcademicCalendar.normalizeTerm('2025202601')).assertEqual('2025-2026-1');
      expect(AcademicCalendar.normalizeTerm('', '2026-2027学年第二学期'))
        .assertEqual('2026-2027-2');
      expect(AcademicCalendar.normalizeTerm('2026－2027－3')).assertEqual('2026-2027-3');
    });

    it('academicCalendarUsesPublishedNextYearStarts', 0, () => {
      expect(AcademicCalendar.knownStartDate('2026-2027-1')).assertEqual('2026-09-07');
      expect(AcademicCalendar.knownStartDate('2026-2027-2')).assertEqual('2027-03-01');
      expect(AcademicCalendar.knownStartDate('2026-2027-3')).assertEqual('2027-07-05');
      expect(AcademicCalendar.knownTotalWeeks('2026-2027-3')).assertEqual(9);
    });

    it('academicCalendarCalculatesWeekDateRange', 0, () => {
      const range: AcademicWeekRange | undefined =
        AcademicCalendar.weekRange('2026-2027-1', '', 2);
      expect(range !== undefined).assertTrue();
      expect(range !== undefined ? range.start.getDate() : 0).assertEqual(14);
      expect(range !== undefined ? range.end.getDate() : 0).assertEqual(20);
      expect(AcademicCalendar.teachingWeek(
        '2026-2027-2', '', new Date(2027, 2, 14)
      )).assertEqual(2);
      expect(AcademicCalendar.teachingWeek(
        '2025-2026-1', '', new Date(2026, 6, 26), '', 18
      )).assertEqual(0);
    });

    it('semesterFallsBackToPublishedCalendarWithoutOverridingMisDate', 0, () => {
      const calendarSemester = CourseParser.parseSemesterFromResult(
        '{"termCode":"2026-2027-1","termLabel":"2026-2027学年第一学期"}'
      );
      expect(calendarSemester.startDate).assertEqual('2026-09-07');
      expect(calendarSemester.totalWeeks).assertEqual(18);
      const misSemester = CourseParser.parseSemesterFromResult(
        '{"termCode":"2026-2027-1","termLabel":"2026-2027学年第一学期",' +
        '"semesterStartDate":"2026-09-14"}'
      );
      expect(misSemester.startDate).assertEqual('2026-09-14');
    });
  });

  describe('ExamParserFixtureTest', () => {
    it('normalExamPreservesMixedScheduleText', 0, () => {
      const parsed: ExamParseResult = ExamParser.parseResult(
        '{"recognized":true,"exams":[{"termCode":"T1","termLabel":"当前学期",' +
        '"courseName":"脱敏课程甲","scheduleText":"2026-01-10 09:00-11:00 教学楼甲101 座位12",' +
        '"examMode":"闭卷","remark":"携带证件","registration":"已报名","status":"正常"}]}',
        'https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/', 100);
      expect(parsed.recognized).assertTrue();
      expect(parsed.termCode).assertEqual('T1');
      expect(parsed.termLabel).assertEqual('当前学期');
      expect(parsed.exams.length).assertEqual(1);
      expect(parsed.exams[0].scheduleText.includes('座位12')).assertTrue();
      expect(parsed.exams[0].examDate).assertEqual('2026-01-10');
      expect(parsed.exams[0].examTime).assertEqual('09:00-11:00');
      expect(parsed.exams[0].locationText).assertEqual('教学楼甲101');
      expect(parsed.exams[0].seatNo).assertEqual('12');
      expect(parsed.exams[0].syncedAt).assertEqual(100);
    });

    it('noExamIsLegalEmptyResult', 0, () => {
      const parsed: ExamParseResult = ExamParser.parseResult(
        '{"recognized":true,"exams":[]}', '', 100
      );
      expect(parsed.recognized).assertTrue();
      expect(parsed.exams.length).assertEqual(0);
      const publicEmpty: ExamParseResult = ExamParser.parseResult(
        '{"termCode":"T1","tables":[{"headers":' +
        '["序号","考试类型","课程名称","考试时间","考试状态","考试详情"],"rows":[]}]}', '', 100
      );
      expect(publicEmpty.recognized).assertTrue();
      expect(publicEmpty.exams.length).assertEqual(0);
    });

    it('examScriptUsesSemanticHeadersAndTermSelection', 0, () => {
      const script: string = ExamParser.buildExtractScript();
      expect(script.includes('buildExamColMap')).assertTrue();
      expect(script.includes("includes('时间')")).assertTrue();
      expect(ExamParser.buildListTermsScript().includes('zxjxjhh')).assertTrue();
      expect(SyncCoordinator.doesExamTermMatch('T1', 'T1')).assertTrue();
      expect(SyncCoordinator.doesExamTermMatch('T1', 'T2')).assertFalse();
      expect(SyncCoordinator.doesExamTermMatch('T1', '')).assertFalse();
      expect(SyncCoordinator.doesExamTermMatch('UNKNOWN_TERM', 'T2')).assertTrue();
      expect(SyncCoordinator.doesExamTermMatch('UNKNOWN_TERM', '')).assertFalse();
      expect(script.includes('detailPath: detailPathFromCell(rawCell)')).assertTrue();
      expect(script.includes('rawLink.href')).assertFalse();
      expect(script.includes('https?:///')).assertFalse();
      expect(script.includes('isLegalEmptyExamPage')).assertTrue();
      expect(script.includes('firstDataCells.length >= 6')).assertTrue();
      expect(ExamParser.normalizeDetailPath('https://aa.bjtu.edu.cn/exam/1?id=2'))
        .assertEqual('/exam/1?id=2');
      expect(ExamParser.normalizeDetailPath('https://evil.example/exam/1')).assertEqual('');
    });

    it('reorderedExamHeadersUseProductionSemanticMapping', 0, () => {
      const parsed: ExamParseResult = ExamParser.parseResult(
        '{"termCode":"T1","termLabel":"当前学期","tables":[{"headers":' +
        '["状态","考试时间与地点","课程名称","考试方式","操作"],"rows":[[' +
        '{"text":"正常"},{"text":"2026-01-10 教学楼甲101"},{"text":"课程甲"},' +
        '{"text":"闭卷"},{"text":"详情","onclick":"openDetail(\\\"/exam/1\\\")"}]]}]}',
        'https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/', 100
      );
      expect(parsed.recognized).assertTrue();
      expect(parsed.exams[0].courseName).assertEqual('课程甲');
      expect(parsed.exams[0].scheduleText.includes('教学楼甲101')).assertTrue();
      expect(parsed.exams[0].examDate).assertEqual('2026-01-10');
      expect(parsed.exams[0].locationText).assertEqual('教学楼甲101');
      expect(parsed.exams[0].detailPath).assertEqual('/exam/1');
    });

    it('separateExamColumnsKeepRoomSeatAndRawRow', 0, () => {
      const parsed: ExamParseResult = ExamParser.parseResult(
        '{"termCode":"T1","termLabel":"当前学期","tables":[{"headers":' +
        '["课程代码","课程名称","考试日期","考试时间","考场","座位号","状态"],"rows":[[' +
        '{"text":"C100"},{"text":"课程乙"},{"text":"2026年06月23日"},' +
        '{"text":"09:00至11:00"},{"text":"逸夫楼 A101"},{"text":"12"},{"text":"正常"}]]}]}',
        'https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/', 100
      );
      expect(parsed.recognized).assertTrue();
      expect(parsed.exams[0].courseCode).assertEqual('C100');
      expect(parsed.exams[0].examDate).assertEqual('2026-06-23');
      expect(parsed.exams[0].examTime).assertEqual('09:00-11:00');
      expect(parsed.exams[0].locationText).assertEqual('逸夫楼 A101');
      expect(parsed.exams[0].seatNo).assertEqual('12');
      expect(parsed.exams[0].rawText.includes('逸夫楼 A101')).assertTrue();
    });

    it('examParserSelectsStrongestSemanticTable', 0, () => {
      const parsed: ExamParseResult = ExamParser.parseResult(
        '{"termCode":"T1","tables":[' +
        '{"headers":["课程名称"],"rows":[[{"text":"干扰项"}]]},' +
        '{"headers":["课程名称","考试时间","考场"],"rows":[[' +
        '{"text":"目标课程"},{"text":"2026-06-23 09:00-11:00"},{"text":"逸夫楼 A101"}]]}]}',
        'https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/', 100
      );
      expect(parsed.exams.length).assertEqual(1);
      expect(parsed.exams[0].courseName).assertEqual('目标课程');
    });

    it('examTimelineChoosesOngoingThenNearestFuture', 0, () => {
      const ended: ExamInfo = new ExamInfo();
      ended.courseName = '已结束考试';
      ended.examDate = '2026-01-10';
      ended.examTime = '07:00-08:00';
      const ongoing: ExamInfo = new ExamInfo();
      ongoing.courseName = '进行中考试';
      ongoing.examDate = '2026-01-10';
      ongoing.examTime = '09:00-11:00';
      const future: ExamInfo = new ExamInfo();
      future.courseName = '未来考试';
      future.scheduleText = '2026-01-10 13:00-15:00 教学楼甲101';
      const unknown: ExamInfo = new ExamInfo();
      unknown.courseName = '时间未知考试';
      const tenOClock: number = new Date(2026, 0, 10, 10, 0).getTime();
      const noon: number = new Date(2026, 0, 10, 12, 0).getTime();
      const first: ExamInfo | undefined =
        ExamTimeline.nextUpcoming([ended, future, unknown, ongoing], tenOClock);
      const second: ExamInfo | undefined =
        ExamTimeline.nextUpcoming([ended, future, unknown, ongoing], noon);
      expect(first !== undefined ? first.courseName : '').assertEqual('进行中考试');
      expect(second !== undefined ? second.courseName : '').assertEqual('未来考试');
      expect(ExamTimeline.isPast(ended, tenOClock)).assertTrue();
    });
  });

  describe('GradeParserFixtureTest', () => {
    it('parsesNumericLetterBonusAndStatuses', 0, () => {
      const parsed: GradeParseResult = GradeParser.parseResult(
        '{"recognized":true,"grades":[' +
        '{"termCode":"T1","courseName":"课程甲","credit":"2","score":"90","bonusScore":"3",' +
        '"teacher":"教师甲","detailPath":"/detail/1"},' +
        '{"termCode":"T1","courseName":"课程乙","credit":"1","score":"优秀",' +
        '"teacher":"教师乙","gradeStatus":"缓考"},' +
        '{"termCode":"T1","courseName":"课程丙","credit":"1","score":"缺考",' +
        '"teacher":"教师丙","gradeStatus":"缺考"}]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200);
      expect(parsed.grades.length).assertEqual(3);
      expect(parsed.grades[0].bonusScore).assertEqual('3');
      expect(parsed.grades[1].score).assertEqual('优秀');
      expect(parsed.grades[2].gradeStatus).assertEqual('缺考');
    });

    it('dedupeKeyKeepsRetakeAndDifferentTeachers', 0, () => {
      const first: GradeInfo = new GradeInfo();
      first.termCode = 'T1'; first.courseName = '课程甲'; first.credit = '2';
      first.score = '60'; first.teacher = '教师甲';
      const duplicate: GradeInfo = new GradeInfo();
      duplicate.termCode = 'T1'; duplicate.courseName = '课程甲'; duplicate.credit = '2';
      duplicate.score = '60'; duplicate.teacher = '教师甲';
      const sameTermRetake: GradeInfo = new GradeInfo();
      sameTermRetake.termCode = 'T1'; sameTermRetake.courseName = '课程甲'; sameTermRetake.credit = '2';
      sameTermRetake.score = '60'; sameTermRetake.teacher = '教师甲'; sameTermRetake.gradeStatus = '重修';
      const retake: GradeInfo = new GradeInfo();
      retake.termCode = 'T2'; retake.courseName = '课程甲'; retake.credit = '2';
      retake.score = '90'; retake.teacher = '教师乙';
      expect(first.getDedupeKey() === duplicate.getDedupeKey()).assertTrue();
      expect(first.getDedupeKey() === sameTermRetake.getDedupeKey()).assertFalse();
      expect(first.getDedupeKey() === retake.getDedupeKey()).assertFalse();
    });

    it('gradeScriptSupportsHrefDataAndOnclickDetails', 0, () => {
      const script: string = GradeParser.buildExtractScript();
      expect(script.includes("table.querySelector('thead tr')")).assertTrue();
      expect(script.includes('firstDataRow')).assertTrue();
      expect(script.includes("getAttribute('data-url')")).assertTrue();
      expect(script.includes("getAttribute('data-href')")).assertTrue();
      expect(script.includes("getAttribute('onclick')")).assertTrue();
      expect(script.includes("[name=\"ctype\"]")).assertTrue();
      expect(script.includes('li.active a[href*="ctype=ln"]')).assertTrue();
      expect(script.includes('排名)?s*')).assertFalse();
      expect(script.includes('cell.innerHTML')).assertFalse();
      expect(GradeParser.buildListTermsScript().includes('selected')).assertTrue();
    });

    it('termSwitchWaitsForSubmittedPageBeforeParsing', 0, () => {
      const source: string = SyncCoordinator.buildTermSwitchScriptForTesting('T1');
      expect(source.includes('sel.onchange(changed)')).assertFalse();
      expect(source.includes("window.jQuery(sel).trigger('change')")).assertFalse();
      expect(source.includes("document.querySelectorAll('select')")).assertTrue();
      expect(source.includes('var scoreType = "ln"')).assertTrue();
      expect(source.includes('ctypeInput.value = scoreType')).assertTrue();
      expect(source.includes('form.requestSubmit(submitter)')).assertTrue();
      expect(source.includes('sel.value === target && sel.selectedIndex === i')).assertFalse();
      expect(SyncCoordinator.didTermSwitchSucceed('{"changed":true}')).assertTrue();
      expect(SyncCoordinator.didTermSwitchSucceed('"{\\"changed\\":true}"')).assertTrue();
      expect(SyncCoordinator.didTermSwitchSucceed('{"changed":false}')).assertFalse();
      expect(SyncCoordinator.didTermSwitchSucceed('not-json')).assertFalse();
      expect(SyncCoordinator.isTermReadyWithoutReload('{"changed":true,"ready":true}')).assertTrue();
      expect(SyncCoordinator.isTermReadyWithoutReload('{"changed":true,"ready":false}')).assertFalse();
      expect(SyncCoordinator.buildTermSwitchScriptForTesting('T2', 'lr')
        .includes('var scoreType = "lr"')).assertTrue();
      const parsedHistory: GradeParseResult = GradeParser.parseResult(
        '{"recognized":true,"termCode":"T1","ctype":"ln","grades":[]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/?ctype=ln'
      );
      expect(parsedHistory.ctype).assertEqual('ln');
    });

    it('retriesEmptyScoreTermDiscoveryWithinBound', 0, () => {
      expect(SyncCoordinator.shouldRetryScoreTermDiscovery(1, 0, 0)).assertTrue();
      expect(SyncCoordinator.shouldRetryScoreTermDiscovery(5, 0, 0)).assertTrue();
      expect(SyncCoordinator.shouldRetryScoreTermDiscovery(12, 0, 0)).assertFalse();
      expect(SyncCoordinator.shouldRetryScoreTermDiscovery(1, 1, 1)).assertTrue();
      expect(SyncCoordinator.shouldRetryScoreTermDiscovery(2, 1, 2)).assertFalse();
    });

    it('rejectsOnlyAuthoritativeAllEmptyGradeAggregate', 0, () => {
      expect(SyncCoordinator.shouldRejectEmptyGradeAggregate(6, 6, 0)).assertTrue();
      expect(SyncCoordinator.shouldRejectEmptyGradeAggregate(6, 5, 0)).assertFalse();
      expect(SyncCoordinator.shouldRejectEmptyGradeAggregate(6, 6, 1)).assertFalse();
      expect(SyncCoordinator.shouldRejectEmptyGradeAggregate(0, 0, 0)).assertFalse();
    });

    it('waitsForTargetScoreTermWithinBound', 0, () => {
      expect(SyncCoordinator.shouldRetryScoreTermPage(1, false)).assertTrue();
      expect(SyncCoordinator.shouldRetryScoreTermPage(4, false)).assertTrue();
      expect(SyncCoordinator.shouldRetryScoreTermPage(5, false)).assertFalse();
      expect(SyncCoordinator.shouldRetryScoreTermPage(1, true)).assertFalse();
    });

    it('gradeTermsOrderByActualSemesterSuffix', 0, () => {
      expect(GradeTermOrder.compare('2025-2026-1', '2025-2026-2') < 0).assertTrue();
      expect(GradeTermOrder.compare('2024-2025-2', '2025-2026-1') < 0).assertTrue();
      expect(GradeTermOrder.normalize('2025-2026学年第一学期')).assertEqual('2025-2026-1');
      expect(GradeTermOrder.normalize('2025－2026－1 学期')).assertEqual('2025-2026-1');
      expect(GradeTermOrder.canonical('history-source-code', '2025-2026-1')).assertEqual('2025-2026-1');
      expect(GradeParser.isFutureAcademicTerm('2022-2023-1', new Date(2026, 6, 26))).assertFalse();
      expect(GradeParser.currentAcademicTermCode(new Date(2026, 6, 26)))
        .assertEqual('2025-2026-2');
      expect(GradeParser.currentAcademicTermCode(new Date(2026, 8, 1)))
        .assertEqual('2026-2027-1');
    });

    it('reorderedGradeHeadersAndDetailLinksUseProductionMapping', 0, () => {
      const parsed: GradeParseResult = GradeParser.parseResult(
        '{"termCode":"T1","termLabel":"当前学期","tables":[{"headers":' +
        '["教师","加分成绩","课程名称","成绩","学分","详细信息"],"rows":[[' +
        '{"text":"教师甲"},{"text":"2"},{"text":"课程甲"},{"text":"95"},' +
        '{"text":"3"},{"text":"查看","dataHref":"/grade/1"}]]}]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(parsed.recognized).assertTrue();
      expect(parsed.grades[0].courseName).assertEqual('课程甲');
      expect(parsed.grades[0].bonusScore).assertEqual('2');
      expect(parsed.grades[0].detailPath).assertEqual('/grade/1');
    });

    it('aggregateGradeRowsCarryTheirOwnAcademicTerms', 0, () => {
      const parsed: GradeParseResult = GradeParser.parseResult(
        '{"ctype":"ln","tables":[{"headers":' +
        '["序号","学年学期","课程","学分","成绩","加分成绩","上课教师","详细信息"],"rows":[[' +
        '{"text":"1"},{"text":"2024-2025-2"},{"text":"课程甲"},{"text":"3"},' +
        '{"text":"88"},{"text":""},{"text":"教师甲"},{"text":"查看"}],[' +
        '{"text":"2"},{"text":"2025-2026-1"},{"text":"课程乙"},{"text":"2"},' +
        '{"text":"优秀"},{"text":""},{"text":"教师乙"},{"text":"查看"}]]}]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(parsed.recognized).assertTrue();
      expect(parsed.grades.length).assertEqual(2);
      expect(parsed.grades[0].termCode).assertEqual('2024-2025-2');
      expect(parsed.grades[1].termCode).assertEqual('2025-2026-1');
      expect(parsed.grades[0].courseName).assertEqual('课程甲');
    });

    it('aggregateGradeContractUsesHistoryAndCurrentLists', 0, () => {
      const source: string = SyncCoordinator.gradeListContractForTesting();
      expect(source.includes('page=1&perpage=500&ctype=ln')).assertTrue();
      expect(source.includes('page=1&perpage=500&ctype=lr')).assertTrue();
      expect(SyncCoordinator.isAggregateGradePhase(SyncPhase.DISCOVERING_SCORE_TERMS)).assertTrue();
      expect(SyncCoordinator.isAggregateGradePhase(SyncPhase.LOADING_SCORE_TERM)).assertTrue();
      expect(SyncCoordinator.isAggregateGradePhase(SyncPhase.LOADING_TIMETABLE)).assertFalse();
      expect(SyncCoordinator.isHistoricalGradeTermPhase(true, 0)).assertTrue();
      expect(SyncCoordinator.isHistoricalGradeTermPhase(true, 1)).assertFalse();
      expect(SyncCoordinator.isHistoricalGradeTermPhase(false, 0)).assertFalse();
      expect(SyncCoordinator.shouldReloadEmptyScoreTermDiscovery(0, 0)).assertTrue();
      expect(SyncCoordinator.shouldReloadEmptyScoreTermDiscovery(1, 0)).assertFalse();
      expect(SyncCoordinator.shouldReloadEmptyScoreTermDiscovery(0, 2)).assertFalse();
      const script: string = GradeParser.buildExtractScript();
      expect(GradeParser.buildListTermsScript().includes("document.querySelectorAll('select')")).assertTrue();
      expect(script.includes("document.querySelectorAll('select')")).assertTrue();
      expect(script.includes("ctype === 'ln' || ctype === 'lr'")).assertTrue();
      expect(script.includes('colMap.term = 1')).assertTrue();
      expect(script.includes('colMap.name = 2')).assertTrue();
    });

    it('findsMisDetailButtonWithoutDependingOnDetailHeader', 0, () => {
      const parsed: GradeParseResult = GradeParser.parseResult(
        '{"termCode":"T1","termLabel":"当前学期","tables":[{"headers":' +
        '["课程名称","成绩","附加信息"],"rows":[[' +
        '{"text":"课程甲"},{"text":"95"},{"text":"查看",' +
        '"onclick":"showScore(\\\"/score/scores/stu/detail/1001/?term=T1\\\")"}]]}]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(parsed.grades[0].detailPath)
        .assertEqual('/score/scores/stu/detail/1001/?term=T1');
    });

    it('historyTermsPutCurrentSelectionFirst', 0, () => {
      const options = GradeParser.parseTermOptions(
        '[{"termCode":"T0","termLabel":"历史学期","selected":false},' +
        '{"termCode":"T1","termLabel":"当前学期","selected":true}]'
      );
      expect(options.length).assertEqual(2);
      expect(options[0].termCode).assertEqual('T1');
      const july: Date = new Date(2026, 6, 17);
      expect(GradeParser.isFutureAcademicTerm('2026-2027-2', july)).assertTrue();
      expect(GradeParser.isFutureAcademicTerm('2025-2026-2', july)).assertFalse();
      expect(GradeParser.isFutureAcademicTerm('未知学期', july)).assertFalse();
      const emptyTerm: GradeParseResult = GradeParser.parseResult(
        '{"termCode":"T0","tables":[{"headers":["课程名称","成绩"],"rows":[]}]}', '', 200
      );
      expect(emptyTerm.recognized).assertTrue();
      expect(emptyTerm.grades.length).assertEqual(0);
    });

    it('sortsMisAcademicTermsFromFirstSemester', 0, () => {
      expect(GradeTermOrder.compare('2025-2026-1 学期', '2025-2026-2 学期') < 0).assertTrue();
      expect(GradeTermOrder.compare('2025-2026-2 学期', '2025-2026-1 学期')).assertLarger(0);
      expect(GradeTermOrder.isAtOrAfter('2025-2026-1 学期', FIRST_GRADE_TERM)).assertTrue();
      expect(GradeTermOrder.isAtOrAfter('2024-2025-2', FIRST_GRADE_TERM)).assertFalse();
    });

    it('keepsCollegeRankingOnlyWhenMisReturnsIt', 0, () => {
      const ranked: GradeParseResult = GradeParser.parseResult(
        '{"recognized":true,"termCode":"T1","termLabel":"2025-2026-1 学期",' +
        '"collegeRanking":{"rank":12,"total":100,"percentile":"12%"},"grades":[]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(ranked.termSummary.hasCollegeRanking()).assertTrue();
      expect(ranked.termSummary.collegeTotal).assertEqual(100);
      const unranked: GradeParseResult = GradeParser.parseResult(
        '{"recognized":true,"termCode":"T1","grades":[]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(unranked.termSummary.hasCollegeRanking()).assertFalse();
    });

    it('normalizesDirectAndJavascriptScoreDetailPaths', 0, () => {
      expect(GradeParser.normalizeDetailPath(
        '/score/scores/stu/detail/1001/?term=T1'
      )).assertEqual('/score/scores/stu/detail/1001/?term=T1');
      expect(GradeParser.normalizeDetailPath(
        'https://aa.bjtu.edu.cn/score/scores/stu/detail/1001/?term=T1'
      )).assertEqual('/score/scores/stu/detail/1001/?term=T1');
      expect(GradeParser.normalizeDetailPath(
        "javascript:showScore('/score/scores/stu/detail/1002/?term=T1')"
      )).assertEqual('/score/scores/stu/detail/1002/?term=T1');
      expect(GradeParser.normalizeDetailPath(
        'https://evil.example/score/detail/1'
      )).assertEqual('');
    });

    it('parsesMisScoreCompositionFieldsAndTables', 0, () => {
      const result: string =
        '{"title":"脱敏课程成绩详情","fields":[{"label":"课程","value":"脱敏课程"},' +
        '{"label":"总评","value":"86"}],"tables":[{"title":"分项成绩",' +
        '"headers":["项目","比例","成绩"],"rows":[["平时","40%","88"],["期末","60%","85"]]}]}';
      const detail = GradeDetailParser.parseResult(JSON.stringify(result));
      expect(detail.fields.length).assertEqual(2);
      expect(detail.tables.length).assertEqual(1);
      expect(detail.tables[0].rows[0][0]).assertEqual('平时');
      expect(detail.tables[0].rows[1][0]).assertEqual('期末');
    });

    it('keepsInlineMisCompositionFromScoreList', 0, () => {
      const parsed: GradeParseResult = GradeParser.parseResult(
        '{"recognized":true,"grades":[{"termCode":"T1","courseName":"课程甲",' +
        '"credit":"2","score":"88","detailFields":[' +
        '{"label":"平时成绩(0.4)","value":"91"},' +
        '{"label":"期末成绩(0.6)","value":"86"}]}]}',
        'https://aa.bjtu.edu.cn/score/scores/stu/view/', 200
      );
      expect(parsed.grades[0].hasDetailData()).assertTrue();
      expect(parsed.grades[0].detailFields[1].label).assertEqual('期末成绩(0.6)');
    });

    it('calculatesOfficialWeightedAverageAndGpa', 0, () => {
      const numeric: GradeInfo = new GradeInfo();
      numeric.credit = '2'; numeric.score = '90';
      const letter: GradeInfo = new GradeInfo();
      letter.credit = '1'; letter.score = 'B+';
      const excluded: GradeInfo = new GradeInfo();
      excluded.credit = '1'; excluded.score = 'P';
      const metrics = GradeMetrics.calculate([numeric, letter, excluded]);
      expect(metrics.averageScore.toFixed(2)).assertEqual('87.67');
      expect(metrics.gpa.toFixed(2)).assertEqual('3.77');
      expect(metrics.includedCourses).assertEqual(2);
    });

    it('gradeMetricsIgnoreCrossSourceDuplicates', 0, () => {
      const history: GradeInfo = new GradeInfo();
      history.termCode = 'history-source-code';
      history.termLabel = '2025-2026-1';
      history.courseName = '课程甲';
      history.credit = '3';
      history.score = '90';
      history.teacher = '教师甲';
      const current: GradeInfo = new GradeInfo();
      current.termCode = 'current-source-code';
      current.termLabel = '2025-2026-1';
      current.courseName = '课程甲';
      current.credit = '3';
      current.score = '90';
      current.teacher = '教师甲';
      const metrics = GradeMetrics.calculate([history, current]);
      expect(metrics.includedCourses).assertEqual(1);
      expect(metrics.includedCredits).assertEqual(3);
      expect(metrics.averageScore).assertEqual(90);
    });

    it('cumulativeWeightedAverageCombinesAllAcademicTerms', 0, () => {
      const previous: GradeInfo = new GradeInfo();
      previous.termCode = '2024-2025-2';
      previous.courseName = '课程甲';
      previous.credit = '2';
      previous.score = '80';
      const current: GradeInfo = new GradeInfo();
      current.termCode = '2025-2026-1';
      current.courseName = '课程乙';
      current.credit = '3';
      current.score = '90';
      const metrics = GradeMetrics.calculate([previous, current]);
      expect(metrics.includedCourses).assertEqual(2);
      expect(metrics.includedCredits).assertEqual(5);
      expect(metrics.averageScore.toFixed(1)).assertEqual('86.0');
      expect(metrics.gpa.toFixed(2)).assertEqual('3.60');
    });

    it('usesReadableOfflineAndCourseLabels', 0, () => {
      expect(loginStateLabel(LoginState.UNKNOWN, true)).assertEqual('本地数据可用');
      expect(loginStateLabel(LoginState.UNKNOWN, false)).assertEqual('状态未知');
      const combined: GradeInfo = new GradeInfo();
      combined.courseName = 'A032001B\n脱敏课程 [15]';
      expect(combined.getDisplayCourseName()).assertEqual('脱敏课程 [15]');
      const plain: GradeInfo = new GradeInfo();
      plain.courseName = '脱敏课程乙';
      expect(plain.getDisplayCourseName()).assertEqual('脱敏课程乙');
      const exam: ExamInfo = new ExamInfo();
      exam.courseCode = 'M108001B';
      exam.courseName = 'M108001B\n大学物理（A）I\n[18]';
      expect(exam.getDisplayCourseName()).assertEqual('大学物理（A）I [18]');
    });

    it('networkFailureStopsRefreshAndKeepsOfflineMessage', 0, () => {
      let loginState: LoginState = LoginState.UNKNOWN;
      let finishedStatus: SyncStatus = new SyncStatus();
      const coordinator: SyncCoordinator = new SyncCoordinator(
        new webview.WebviewController(),
        (): void => {
        },
        (state: LoginState): void => {
          loginState = state;
        },
        (status: SyncStatus): void => {
          finishedStatus = status;
        }
      );
      coordinator.start();
      coordinator.onNetworkError();
      const status: SyncStatus = coordinator.getStatus();
      expect(loginState).assertEqual(LoginState.NETWORK_ERROR);
      expect(status.phase).assertEqual(SyncPhase.NETWORK_ERROR);
      expect(status.running).assertFalse();
      expect(status.message.includes('已保留本地数据')).assertTrue();
      expect(finishedStatus.phase).assertEqual(SyncPhase.NETWORK_ERROR);
    });

    it('parsesRedactedProfileAndTrainingProgress', 0, () => {
      const profileFixture: string =
        '{"recognized":true,"fields":[' +
        '{"label":"姓名","value":"脱敏学生","group":"基本信息"},' +
        '{"label":"学院","value":"脱敏学院","group":"学籍信息"},' +
        '{"label":"专业","value":"脱敏专业","group":"学籍信息"},' +
        '{"label":"学号","value":"00000000","group":"基本信息"}]}';
      const profile: StudentProfile = CampusParser.parseProfile(profileFixture, 'https://aa.bjtu.edu.cn/path');
      expect(profile.studentName).assertEqual('脱敏学生');
      expect(profile.college).assertEqual('脱敏学院');
      expect(profile.fields.length).assertEqual(3);
      const progressFixture: string =
        '{"recognized":true,"fields":[' +
        '{"label":"培养要求学分","value":"160.0","group":"汇总"},' +
        '{"label":"已获得学分","value":"82.5","group":"汇总"},' +
        '{"label":"1","value":"00000000 脱敏学生","group":""}],' +
        '"courses":[{"courseName":"脱敏课程甲","credit":"3","score":"59",' +
        '"status":"未通过","category":"必修"}]}';
      const progress: AcademicProgress =
        CampusParser.parseProgress(progressFixture, 'https://aa.bjtu.edu.cn/path');
      expect(progress.requiredCredits).assertEqual(160);
      expect(progress.earnedCredits).assertEqual(82.5);
      expect(progress.failedCourseCount).assertEqual(1);
      expect(progress.officialSummary).assertTrue();
      expect(progress.fields.length).assertEqual(2);
    });

    it('sanitizesMailBodyAndKeepsPublishedCalendarSource', 0, () => {
      const unsafe: string =
        '<script>secret()</script><iframe>remote</iframe><form>submit</form><p>安全正文</p>javascript:run';
      const safe: string = MailParser.safeText(unsafe);
      expect(safe.includes('script')).assertFalse();
      expect(safe.includes('iframe')).assertFalse();
      expect(safe.includes('form')).assertFalse();
      expect(safe.includes('javascript:')).assertFalse();
      expect(safe.includes('安全正文')).assertTrue();
      const calendar: CampusCalendar = CampusCalendar.published20262027();
      expect(calendar.academicYear).assertEqual('2026-2027');
      expect(calendar.events.length).assertLarger(8);
      expect(calendar.sourceUrl.includes('bjtu.edu.cn')).assertTrue();
    });
  });
}
