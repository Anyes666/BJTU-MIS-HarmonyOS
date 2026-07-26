import { ExamInfo } from '../model/ExamInfo';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class ExamParseResult {
  recognized: boolean = false;
  termCode: string = '';
  termLabel: string = '';
  exams: Array<ExamInfo> = [];
}

export class ExamColumnMap {
  name: number = -1;
  courseCode: number = -1;
  type: number = -1;
  date: number = -1;
  schedule: number = -1;
  location: number = -1;
  seat: number = -1;
  campus: number = -1;
  mode: number = -1;
  status: number = -1;
  remark: number = -1;
  registration: number = -1;
  detail: number = -1;
}

export class ExamParser {

  static buildListTermsScript(): string {
    return `
(function(){
  var sel = document.querySelector('select[name="zxjxjhh"], select#zxjxjhh');
  if(!sel) return JSON.stringify([]);
  var opts = []; var curVal = '';
  for(var i=0; i<sel.options.length; i++){
    var o = sel.options[i];
    opts.push({termCode: o.value||'', termLabel: (o.textContent||'').trim(), selected: o.selected});
    if(o.selected) curVal = o.value||'';
  }
  return JSON.stringify({terms: opts, current: curVal});
})();
`;
  }

  static buildExtractScript(): string {
    return `
(function(){
  var sel = document.querySelector('select[name="zxjxjhh"], select#zxjxjhh');
  var termCode = '', termLabel = '';
  if(sel){
    var o = sel.options[sel.selectedIndex];
    if(o){ termCode = o.value||''; termLabel = (o.textContent||'').trim(); }
  }

  var exams = [];
  var rawTables = [];
  var recognized = false;
  var tables = document.querySelectorAll('table');
  for(var t=0; t<tables.length; t++){
    var table = tables[t];
    var realTbody = table.querySelector('tbody');
    var tbody = realTbody || table;
    var rows = tbody.querySelectorAll('tr');
    if(realTbody && rows.length === 0){
      rawTables.push({
        headers:['序号','考试类型','课程名称','考试时间','考试状态','考试详情'],
        rows:[]
      });
      recognized = true;
      continue;
    }
    if(rows.length < 1) continue;

    var headers = [];
    var firstRow = rows[0];
    var hCells = firstRow.querySelectorAll('th, td');
    for(var h=0; h<hCells.length; h++){
      headers.push((hCells[h].textContent||'').trim());
    }
    var colMap = buildExamColMap(headers);
    var dataStart = 1;
    if(colMap.name < 0){
      var firstDataCells = firstRow.querySelectorAll('td');
      if(firstRow.querySelectorAll('th').length === 0 && firstDataCells.length >= 6){
        headers = ['序号','考试类型','课程名称','考试时间','考试状态','考试详情'];
        colMap = buildExamColMap(headers);
        dataStart = 0;
      } else {
        continue;
      }
    }
    recognized = true;
    var rawRows = [];
    for(var rawIndex=dataStart; rawIndex<rows.length; rawIndex++){
      var rawCells = rows[rawIndex].querySelectorAll('td');
      var rawRow = [];
      for(var rawCellIndex=0; rawCellIndex<rawCells.length; rawCellIndex++){
        var rawCell = rawCells[rawCellIndex];
        rawRow.push({
          text: (rawCell.textContent||'').trim(),
          detailPath: detailPathFromCell(rawCell)
        });
      }
      rawRows.push(rawRow);
    }
    rawTables.push({headers:headers, rows:rawRows});

    for(var r=dataStart; r<rows.length; r++){
      var cells = rows[r].querySelectorAll('td');
      if(cells.length < 2) continue;
      var exam = {};
      exam.courseName = cellText(cells, colMap.name);
      exam.courseCode = cellText(cells, colMap.courseCode);
      exam.examType = cellText(cells, colMap.type);
      exam.examDate = cellText(cells, colMap.date);
      exam.scheduleText = cellText(cells, colMap.schedule);
      exam.locationText = cellText(cells, colMap.location);
      exam.seatNo = cellText(cells, colMap.seat);
      exam.campus = cellText(cells, colMap.campus);
      exam.examMode = cellText(cells, colMap.mode);
      exam.status = cellText(cells, colMap.status);
      exam.remark = cellText(cells, colMap.remark);
      exam.registration = cellText(cells, colMap.reg);
      exam.detail = '';
      exam.detailPath = '';
      exam.rawText = rowText(cells);
      if(colMap.detail >= 0 && cells[colMap.detail]){
        var a = cells[colMap.detail].querySelector('a');
        if(a){ exam.detail = (a.textContent||'').trim(); }
        exam.detailPath = detailPathFromCell(cells[colMap.detail]);
      }
      if(exam.courseName.length > 0){
        exam.termCode = termCode;
        exam.termLabel = termLabel;
        exams.push(exam);
      }
    }
    if(exams.length > 0) break;
  }
  if(!recognized && isLegalEmptyExamPage()) recognized = true;
  return JSON.stringify({
    exams: exams,
    tables: rawTables,
    termCode: termCode,
    termLabel: termLabel,
    recognized: recognized
  });

  function buildExamColMap(headers){
    var m = {name:-1, courseCode:-1, type:-1, date:-1, schedule:-1, location:-1,
      seat:-1, campus:-1, mode:-1, status:-1, remark:-1, reg:-1, detail:-1};
    for(var i=0; i<headers.length; i++){
      var t = headers[i].toLowerCase();
      if((t.includes('课程')||t.includes('科目')) &&
         (t.includes('代码')||t.includes('编号')||t.includes('课程号'))) m.courseCode = i;
      else if(t.includes('课程')||t.includes('科目')||t.includes('名称')) m.name = i;
      else if(t.includes('类型')||t.includes('性质')) m.type = i;
      else if(t.includes('日期')) m.date = i;
      else if(t.includes('时间')||t.includes('日期')||t.includes('日程')) m.schedule = i;
      else if(t.includes('座位')||t.includes('座号')) m.seat = i;
      else if(t.includes('校区')) m.campus = i;
      else if(t.includes('考场')||t.includes('地点')||t.includes('教室')) m.location = i;
      else if(t.includes('方式')||t.includes('模式')) m.mode = i;
      else if(t.includes('状态')) m.status = i;
      else if(t.includes('备注')||t.includes('说明')) m.remark = i;
      else if(t.includes('报名')||t.includes('注册')) m.reg = i;
      else if(t.includes('详情')||t.includes('操作')) m.detail = i;
    }
    return m;
  }
  function cellText(cells, idx){
    if(idx < 0 || idx >= cells.length) return '';
    return (cells[idx].textContent||'').trim();
  }
  function rowText(cells){
    var parts = [];
    for(var i=0; i<cells.length; i++){
      var value = (cells[i].textContent||'').trim();
      if(value) parts.push(value);
    }
    return parts.join(' | ');
  }
  function detailPathFromCell(cell){
    var a = cell.querySelector('a');
    var values = [
      a ? (a.getAttribute('href')||'') : '',
      a ? (a.getAttribute('data-url')||'') : '',
      a ? (a.getAttribute('data-href')||'') : '',
      cell.getAttribute('onclick')||''
    ];
    for(var i=0; i<values.length; i++){
      var path = cleanDetailCandidate(values[i]);
      if(path.length > 0) return path;
    }
    return '';
  }
  function cleanDetailCandidate(value){
    var cleaned = (value||'').trim();
    if(cleaned.length === 0 || cleaned === '#' ||
       cleaned.toLowerCase().indexOf('javascript:void') === 0 ||
       cleaned.toLowerCase().indexOf('void(') === 0) return '';
    if(/^https?:\\/\\//i.test(cleaned) &&
       cleaned.toLowerCase().indexOf('https://aa.bjtu.edu.cn/') !== 0) return '';
    var match = cleaned.match(/(https:\\/\\/aa\\.bjtu\\.edu\\.cn\\/[^\\s"'<>]+|\\/[^\\s"'<>]+)/i);
    if(!match || match[1].indexOf('//') === 0) return '';
    var path = match[1].replace(/[);,]+$/, '');
    var prefix = 'https://aa.bjtu.edu.cn';
    return path.toLowerCase().indexOf(prefix) === 0 ? path.substring(prefix.length) : path;
  }
  function isLegalEmptyExamPage(){
    var nodes = document.querySelectorAll('.dataTables_empty, .no-data, .no-result, .empty, td[colspan]');
    for(var i=0; i<nodes.length; i++){
      var text = (nodes[i].textContent||'').trim();
      if(text.indexOf('暂无数据') >= 0 || text.indexOf('暂无考试') >= 0 ||
         text.indexOf('无考试安排') >= 0 || text.indexOf('没有相关记录') >= 0 ||
         text.indexOf('未查询到') >= 0 || text.indexOf('表中数据为空') >= 0 ||
         text.toLowerCase().indexOf('no data') >= 0) return true;
    }
    return false;
  }
})();
`;
  }

  static parseResult(result: string, sourceUrl: string, syncedAt: number = Date.now()): ExamParseResult {
    const parsed: ExamParseResult = new ExamParseResult();
    const raw: Record<string, Object> =
      JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
    parsed.termCode = (raw['termCode'] as string) ?? '';
    parsed.termLabel = (raw['termLabel'] as string) ?? '';
    const tablesRaw: Object | undefined = raw['tables'];
    if (tablesRaw !== undefined && Array.isArray(tablesRaw)) {
      return ExamParser.parseTables(
        tablesRaw as Array<Object>,
        (raw['termCode'] as string) ?? '',
        (raw['termLabel'] as string) ?? '',
        sourceUrl,
        syncedAt
      );
    }
    parsed.recognized = (raw['recognized'] as boolean) ?? false;
    const examsRaw: Object | undefined = raw['exams'];
    if (examsRaw === undefined || !Array.isArray(examsRaw)) {
      return parsed;
    }
    const arr: Array<Object> = examsRaw as Array<Object>;
    for (let i = 0; i < arr.length; i++) {
      const item: Record<string, Object> = arr[i] as Record<string, Object>;
      const exam: ExamInfo = new ExamInfo();
      exam.courseName = (item['courseName'] as string) ?? '';
      exam.courseCode = (item['courseCode'] as string) ?? '';
      exam.examDate = (item['examDate'] as string) ?? '';
      exam.examTime = (item['examTime'] as string) ?? '';
      exam.scheduleText = (item['scheduleText'] as string) ?? '';
      exam.examType = (item['examType'] as string) ?? '';
      exam.examMode = (item['examMode'] as string) ?? '';
      exam.status = (item['status'] as string) ?? '';
      exam.remark = (item['remark'] as string) ?? '';
      exam.registration = (item['registration'] as string) ?? '';
      exam.detail = (item['detail'] as string) ?? '';
      exam.detailPath = (item['detailPath'] as string) ?? '';
      exam.rawText = (item['rawText'] as string) ?? '';
      exam.campus = (item['campus'] as string) ?? '';
      exam.building = (item['building'] as string) ?? '';
      exam.classroom = (item['classroom'] as string) ?? '';
      exam.locationText = (item['locationText'] as string) ?? '';
      exam.seatNo = (item['seatNo'] as string) ?? '';
      exam.termCode = (item['termCode'] as string) ?? parsed.termCode;
      exam.termLabel = (item['termLabel'] as string) ?? parsed.termLabel;
      exam.sourceUrl = sourceUrl;
      exam.syncedAt = syncedAt;
      ExamParser.enrichStructuredFields(exam);
      exam.id = ExamParser.buildId(exam);
      if (exam.courseName.length > 0) {
        if (parsed.termCode.length === 0 && exam.termCode.length > 0) {
          parsed.termCode = exam.termCode;
          parsed.termLabel = exam.termLabel;
        }
        parsed.exams.push(exam);
      }
    }
    return parsed;
  }

  static mapHeaders(headers: Array<string>): ExamColumnMap {
    const map: ExamColumnMap = new ExamColumnMap();
    for (let i = 0; i < headers.length; i++) {
      const text: string = headers[i].toLowerCase();
      if ((text.includes('课程') || text.includes('科目')) &&
          (text.includes('代码') || text.includes('编号') || text.includes('课程号'))) {
        map.courseCode = i;
      } else if (text.includes('课程') || text.includes('科目') || text.includes('名称')) {
        map.name = i;
      } else if (text.includes('类型') || text.includes('性质')) {
        map.type = i;
      } else if (text.includes('日期')) {
        map.date = i;
      } else if (text.includes('时间') || text.includes('日程')) {
        map.schedule = i;
      } else if (text.includes('座位') || text.includes('座号')) {
        map.seat = i;
      } else if (text.includes('校区')) {
        map.campus = i;
      } else if (text.includes('考场') || text.includes('地点') || text.includes('教室')) {
        map.location = i;
      } else if (text.includes('方式') || text.includes('模式')) {
        map.mode = i;
      } else if (text.includes('状态')) {
        map.status = i;
      } else if (text.includes('备注') || text.includes('说明')) {
        map.remark = i;
      } else if (text.includes('报名') || text.includes('注册')) {
        map.registration = i;
      } else if (text.includes('详情') || text.includes('操作')) {
        map.detail = i;
      }
    }
    return map;
  }

  private static parseTables(
    tables: Array<Object>,
    termCode: string,
    termLabel: string,
    sourceUrl: string,
    syncedAt: number
  ): ExamParseResult {
    const parsed: ExamParseResult = new ExamParseResult();
    parsed.termCode = termCode;
    parsed.termLabel = termLabel;
    let selectedTable: Record<string, Object> | undefined = undefined;
    let selectedMap: ExamColumnMap | undefined = undefined;
    let selectedScore: number = -1;
    for (let t = 0; t < tables.length; t++) {
      const table: Record<string, Object> = tables[t] as Record<string, Object>;
      const headersRaw: Object | undefined = table['headers'];
      const rowsRaw: Object | undefined = table['rows'];
      if (headersRaw === undefined || rowsRaw === undefined ||
          !Array.isArray(headersRaw) || !Array.isArray(rowsRaw)) {
        continue;
      }
      const headers: Array<string> = headersRaw as Array<string>;
      const map: ExamColumnMap = ExamParser.mapHeaders(headers);
      const score: number = ExamParser.scoreColumnMap(map);
      if (score > selectedScore) {
        selectedTable = table;
        selectedMap = map;
        selectedScore = score;
      }
    }
    if (selectedTable === undefined || selectedMap === undefined || selectedScore < 0) {
      return parsed;
    }
    parsed.recognized = true;
    const rows: Array<Object> = selectedTable['rows'] as Array<Object>;
    for (let r = 0; r < rows.length; r++) {
      if (!Array.isArray(rows[r])) {
        continue;
      }
      const row: Array<Object> = rows[r] as Array<Object>;
      const exam: ExamInfo = new ExamInfo();
      exam.courseName = ExamParser.cellText(row, selectedMap.name);
      exam.courseCode = ExamParser.cellText(row, selectedMap.courseCode);
      exam.examType = ExamParser.cellText(row, selectedMap.type);
      exam.examDate = ExamParser.cellText(row, selectedMap.date);
      exam.scheduleText = ExamParser.cellText(row, selectedMap.schedule);
      exam.locationText = ExamParser.cellText(row, selectedMap.location);
      exam.seatNo = ExamParser.cellText(row, selectedMap.seat);
      exam.campus = ExamParser.cellText(row, selectedMap.campus);
      exam.examMode = ExamParser.cellText(row, selectedMap.mode);
      exam.status = ExamParser.cellText(row, selectedMap.status);
      exam.remark = ExamParser.cellText(row, selectedMap.remark);
      exam.registration = ExamParser.cellText(row, selectedMap.registration);
      exam.detailPath = ExamParser.cellDetailPath(row, selectedMap.detail);
      exam.detail = selectedMap.detail >= 0 ? ExamParser.cellText(row, selectedMap.detail) : '';
      exam.rawText = ExamParser.rowText(row);
      exam.termCode = termCode;
      exam.termLabel = termLabel;
      exam.sourceUrl = sourceUrl;
      exam.syncedAt = syncedAt;
      ExamParser.enrichStructuredFields(exam);
      exam.id = ExamParser.buildId(exam);
      if (exam.courseName.length > 0) {
        parsed.exams.push(exam);
      }
    }
    return parsed;
  }

  private static scoreColumnMap(map: ExamColumnMap): number {
    if (map.name < 0) {
      return -1;
    }
    let score: number = 10;
    if (map.courseCode >= 0) { score += 1; }
    if (map.type >= 0) { score += 1; }
    if (map.date >= 0) { score += 3; }
    if (map.schedule >= 0) { score += 4; }
    if (map.location >= 0) { score += 3; }
    if (map.seat >= 0) { score += 2; }
    if (map.mode >= 0) { score += 1; }
    if (map.status >= 0) { score += 1; }
    return score;
  }

  private static cellText(row: Array<Object>, index: number): string {
    if (index < 0 || index >= row.length) {
      return '';
    }
    const cell: Record<string, Object> = row[index] as Record<string, Object>;
    return (cell['text'] as string) ?? '';
  }

  private static rowText(row: Array<Object>): string {
    const values: Array<string> = [];
    for (let i = 0; i < row.length; i++) {
      const value: string = ExamParser.cellText(row, i).trim();
      if (value.length > 0) {
        values.push(value);
      }
    }
    return values.join(' | ');
  }

  private static enrichStructuredFields(exam: ExamInfo): void {
    const combined: string = [
      exam.examDate,
      exam.examTime,
      exam.scheduleText,
      exam.locationText,
      exam.detail
    ].join(' ');
    const dateMatch: RegExpMatchArray | null = combined.match(
      new RegExp('(20\\d{2})\\s*[-年/.]\\s*(\\d{1,2})\\s*[-月/.]\\s*(\\d{1,2})\\s*日?')
    );
    if (dateMatch !== null && dateMatch.length >= 4) {
      exam.examDate = dateMatch[1] + '-' + ExamParser.pad(dateMatch[2]) + '-' + ExamParser.pad(dateMatch[3]);
    }
    const rangeMatch: RegExpMatchArray | null = combined.match(
      new RegExp('(\\d{1,2}:\\d{2})\\s*[-~—–至]\\s*(\\d{1,2}:\\d{2})')
    );
    if (rangeMatch !== null && rangeMatch.length >= 3) {
      exam.examTime = rangeMatch[1] + '-' + rangeMatch[2];
    } else {
      const timeMatch: RegExpMatchArray | null = combined.match(new RegExp('(\\d{1,2}:\\d{2})'));
      if (timeMatch !== null && timeMatch.length >= 2) {
        exam.examTime = timeMatch[1];
      }
    }

    const seatSource: string = [exam.seatNo, exam.locationText, exam.detail, exam.scheduleText].join(' ');
    const seatMatch: RegExpMatchArray | null = seatSource.match(
      new RegExp('(?:座位(?:号)?|座号)\\s*[:：]?\\s*([A-Za-z0-9-]+)')
    );
    if (seatMatch !== null && seatMatch.length >= 2) {
      exam.seatNo = seatMatch[1];
    } else {
      exam.seatNo = exam.seatNo.trim();
    }

    if (exam.locationText.trim().length === 0) {
      if (ExamParser.looksLikeLocation(exam.detail)) {
        exam.locationText = ExamParser.stripSeat(exam.detail);
      } else {
        exam.locationText = ExamParser.extractLocation(exam.scheduleText);
      }
    } else {
      exam.locationText = ExamParser.stripSeat(exam.locationText);
    }
    if (exam.classroom.length === 0) {
      exam.classroom = exam.locationText;
    }
    if (exam.campus.length === 0) {
      const campusMatch: RegExpMatchArray | null = exam.locationText.match(
        new RegExp('([^\\s,，;；]+校区)')
      );
      if (campusMatch !== null && campusMatch.length >= 2) {
        exam.campus = campusMatch[1];
      }
    }
    if (exam.building.length === 0) {
      const buildingMatch: RegExpMatchArray | null = exam.locationText.match(
        new RegExp('([^\\s,，;；]*?(?:楼|馆|中心))')
      );
      if (buildingMatch !== null && buildingMatch.length >= 2) {
        exam.building = buildingMatch[1];
      }
    }
    if (exam.scheduleText.length === 0) {
      exam.scheduleText = (exam.examDate + ' ' + exam.examTime).trim();
    }
    if (exam.rawText.length === 0) {
      exam.rawText = [exam.courseName, exam.scheduleText, exam.locationText, exam.seatNo,
        exam.examMode, exam.status, exam.remark].join(' | ');
    }
  }

  private static extractLocation(raw: string): string {
    let value: string = raw
      .replace(new RegExp('(20\\d{2})\\s*[-年/.]\\s*(\\d{1,2})\\s*[-月/.]\\s*(\\d{1,2})\\s*日?', 'g'), ' ')
      .replace(new RegExp('(\\d{1,2}:\\d{2})\\s*[-~—–至]\\s*(\\d{1,2}:\\d{2})', 'g'), ' ')
      .replace(new RegExp('(\\d{1,2}:\\d{2})', 'g'), ' ');
    value = ExamParser.stripSeat(value)
      .replace(new RegExp('[,，;；]+', 'g'), ' ')
      .replace(new RegExp('\\s+', 'g'), ' ')
      .trim();
    return ExamParser.looksLikeLocation(value) ? value : '';
  }

  private static stripSeat(raw: string): string {
    return raw
      .replace(new RegExp('(?:座位(?:号)?|座号)\\s*[:：]?\\s*[A-Za-z0-9-]+', 'g'), ' ')
      .replace(new RegExp('\\s+', 'g'), ' ')
      .trim();
  }

  private static looksLikeLocation(raw: string): boolean {
    const value: string = raw.trim();
    if (value.length === 0 || value === '详情' || value === '查看') {
      return false;
    }
    return value.includes('楼') || value.includes('馆') || value.includes('校区') ||
      value.includes('教室') || value.includes('考场') || value.includes('中心') ||
      new RegExp('[A-Za-z]\\d{2,4}').test(value);
  }

  private static buildId(exam: ExamInfo): string {
    const courseKey: string = exam.courseCode.length > 0 ? exam.courseCode : exam.courseName;
    return exam.termCode + '|' + courseKey + '|' + exam.examDate + '|' + exam.examTime + '|' +
      exam.locationText;
  }

  private static pad(value: string): string {
    const numberValue: number = parseInt(value);
    return numberValue < 10 ? '0' + numberValue.toString() : numberValue.toString();
  }

  private static cellDetailPath(row: Array<Object>, index: number): string {
    if (index < 0 || index >= row.length) {
      return '';
    }
    const cell: Record<string, Object> = row[index] as Record<string, Object>;
    const detailPath: string = (cell['detailPath'] as string) ?? '';
    const href: string = (cell['href'] as string) ?? '';
    const dataUrl: string = (cell['dataUrl'] as string) ?? '';
    const dataHref: string = (cell['dataHref'] as string) ?? '';
    const candidates: Array<string> = [detailPath, href, dataUrl, dataHref];
    for (let i = 0; i < candidates.length; i++) {
      const normalized: string = ExamParser.normalizeDetailPath(candidates[i]);
      if (normalized.length > 0) {
        return normalized;
      }
    }
    const onclick: string = (cell['onclick'] as string) ?? '';
    return ExamParser.normalizeDetailPath(onclick);
  }

  static normalizeDetailPath(candidate: string): string {
    const cleaned: string = candidate.trim();
    if (cleaned.length === 0 || cleaned === '#' ||
        cleaned.toLowerCase().startsWith('javascript:void') ||
        cleaned.toLowerCase().startsWith('void(')) {
      return '';
    }
    if ((cleaned.toLowerCase().startsWith('http://') ||
         cleaned.toLowerCase().startsWith('https://')) &&
        !cleaned.toLowerCase().startsWith('https://aa.bjtu.edu.cn/')) {
      return '';
    }
    const match: RegExpMatchArray | null = cleaned.match(
      new RegExp("(https://aa\\.bjtu\\.edu\\.cn/[^\\s\"'<>]+|/[^\\s\"'<>]+)", 'i')
    );
    if (match === null || match.length < 2 || match[1].startsWith('//')) {
      return '';
    }
    let path: string = match[1].replace(new RegExp('[);,]+$'), '');
    const prefix: string = 'https://aa.bjtu.edu.cn';
    if (path.toLowerCase().startsWith(prefix)) {
      path = path.substring(prefix.length);
    }
    return path;
  }
}
