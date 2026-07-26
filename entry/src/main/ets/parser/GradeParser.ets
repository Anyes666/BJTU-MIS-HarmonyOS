import { GradeDetailField, GradeInfo, GradeTermOption, GradeTermOrder, GradeTermSummary } from '../model/GradeInfo';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class GradeParseResult {
  recognized: boolean = false;
  grades: Array<GradeInfo> = [];
  termCode: string = '';
  termLabel: string = '';
  ctype: string = '';
  termSummary: GradeTermSummary = new GradeTermSummary();
}

export class GradeColumnMap {
  term: number = -1;
  name: number = -1;
  credit: number = -1;
  score: number = -1;
  bonus: number = -1;
  gradePoint: number = -1;
  teacher: number = -1;
  examType: number = -1;
  status: number = -1;
  remark: number = -1;
  detail: number = -1;
}

export class GradeParser {

  static parseTermOptions(result: string): Array<GradeTermOption> {
    const raw: Object = JSON.parse(ScriptResultDecoder.unwrap(result));
    if (!Array.isArray(raw)) {
      return [];
    }
    const selected: Array<GradeTermOption> = [];
    const remaining: Array<GradeTermOption> = [];
    const arr: Array<Object> = raw as Array<Object>;
    for (let i = 0; i < arr.length; i++) {
      const item: Record<string, Object> = arr[i] as Record<string, Object>;
      const option: GradeTermOption = new GradeTermOption();
      option.termCode = (item['termCode'] as string) ?? '';
      option.termLabel = (item['termLabel'] as string) ?? option.termCode;
      option.selected = (item['selected'] as boolean) ?? false;
      if (option.termCode.length === 0) {
        continue;
      }
      if (option.selected) {
        selected.push(option);
      } else {
        remaining.push(option);
      }
    }
    return selected.concat(remaining);
  }

  static isFutureAcademicTerm(termLabel: string, now: Date = new Date()): boolean {
    const normalized: string = termLabel.replace(new RegExp('\\s+', 'g'), '');
    const yearMatch: RegExpMatchArray | null =
      normalized.match(new RegExp('(20\\d{2})[-~至](20\\d{2})'));
    if (yearMatch === null || yearMatch.length < 3) {
      return false;
    }
    let semester: number = 0;
    if (normalized.includes('第一学期') || normalized.includes('1学期') ||
        normalized.includes('秋') || new RegExp('[-_]1$').test(normalized)) {
      semester = 1;
    } else if (normalized.includes('第二学期') || normalized.includes('2学期') ||
               normalized.includes('春') || new RegExp('[-_]2$').test(normalized)) {
      semester = 2;
    }
    if (semester === 0) {
      return false;
    }
    const month: number = now.getMonth() + 1;
    const currentStartYear: number = month >= 8 ? now.getFullYear() : now.getFullYear() - 1;
    const currentSemester: number = month >= 8 || month === 1 ? 1 : 2;
    const termStartYear: number = Number(yearMatch[1]);
    return termStartYear > currentStartYear ||
      (termStartYear === currentStartYear && semester > currentSemester);
  }

  static currentAcademicTermCode(now: Date = new Date()): string {
    const month: number = now.getMonth() + 1;
    const startYear: number = month >= 8 ? now.getFullYear() : now.getFullYear() - 1;
    const semester: number = month >= 8 || month === 1 ? 1 : 2;
    return startYear.toString() + '-' + (startYear + 1).toString() + '-' + semester.toString();
  }

  static buildListTermsScript(): string {
    return `
(function(){
  var sel = findTermSelect();
  if(!sel) return JSON.stringify([]);
  var opts = [];
  for(var i=0; i<sel.options.length; i++){
    var o = sel.options[i];
    opts.push({termCode: o.value||'', termLabel: (o.textContent||'').trim(), selected: o.selected});
  }
  return JSON.stringify(opts);

  function findTermSelect(){
    var preferred = document.querySelector(
      'select[name="zxjxjhh"], select#zxjxjhh, select[name*="xnxq"], select[id*="xnxq"]'
    );
    if(preferred) return preferred;
    var candidates = document.querySelectorAll('select');
    var best = null, bestScore = 0;
    for(var s=0; s<candidates.length; s++){
      var score = 0;
      var identity = ((candidates[s].name || '') + ' ' + (candidates[s].id || '')).toLowerCase();
      if(/term|semester|xnxq|xq|jxjh/.test(identity)) score += 4;
      for(var j=0; j<candidates[s].options.length; j++){
        var optionText = ((candidates[s].options[j].textContent || '') + ' ' +
          (candidates[s].options[j].value || '')).trim();
        if(/20\\d{2}\\s*[-—–~至]\\s*20\\d{2}/.test(optionText)) score += 3;
        if(/(?:[-_]\\s*[12]\\b|第[一二12]学期|春|秋)/.test(optionText)) score += 1;
      }
      if(score > bestScore){
        best = candidates[s];
        bestScore = score;
      }
    }
    return bestScore >= 3 ? best : null;
  }
})();
`;
  }

  static buildExtractScript(): string {
    return `
(function(){
  var sel = findTermSelect();
  var termCode = '', termLabel = '';
  var ctype = '';
  try {
    ctype = new URL(window.location.href).searchParams.get('ctype') || '';
  } catch (_) {}
  if(ctype.length === 0){
    var ctypeInput = document.querySelector('[name="ctype"]');
    if(ctypeInput){ ctype = ctypeInput.value || ''; }
  }
  if(ctype.length === 0){
    var activeHistoryLink = document.querySelector(
      'li.active a[href*="ctype=ln"], a.active[href*="ctype=ln"], .active a[href*="ctype=ln"]'
    );
    if(activeHistoryLink){ ctype = 'ln'; }
  }
  if(sel){
    var o = sel.options[sel.selectedIndex];
    if(o){ termCode = o.value||''; termLabel = (o.textContent||'').trim(); }
  }

  var grades = [];
  var rawTables = [];
  var recognized = false;
  var tables = document.querySelectorAll('table');
  for(var t=0; t<tables.length; t++){
    var table = tables[t];
    var tbody = table.querySelector('tbody');
    var rows = tbody ? tbody.querySelectorAll('tr') : table.querySelectorAll('tr');
    var headerRow = table.querySelector('thead tr');
    var firstDataRow = 0;
    if(!headerRow){
      if(rows.length < 1) continue;
      headerRow = rows[0];
      firstDataRow = 1;
    }

    var headers = [];
    var hCells = headerRow.querySelectorAll('th, td');
    for(var h=0; h<hCells.length; h++){
      headers.push((hCells[h].textContent||'').trim());
    }
    var colMap = buildGradeColMap(headers);
    if(colMap.name < 0 && (ctype === 'ln' || ctype === 'lr')){
      var probeCells = rows.length > firstDataRow ?
        rows[firstDataRow].querySelectorAll('td') : [];
      if(headers.length >= 8 || probeCells.length >= 8){
        colMap.term = 1;
        colMap.name = 2;
        colMap.credit = 3;
        colMap.score = 4;
        colMap.teacher = 6;
        colMap.detail = 7;
      }
    }
    if(colMap.name < 0) continue;
    recognized = true;
    var rawRows = [];
    for(var rawIndex=firstDataRow; rawIndex<rows.length; rawIndex++){
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

    for(var r = firstDataRow; r < rows.length; r++){
      var cells = rows[r].querySelectorAll('td');
      if(cells.length < 3) continue;
      var g = {};
      g.courseName = cellText(cells, colMap.name);
      g.credit = cellText(cells, colMap.credit);
      g.score = cellText(cells, colMap.score);
      g.bonusScore = cellText(cells, colMap.bonus);
      g.gradePoint = cellText(cells, colMap.gpa);
      g.teacher = cellText(cells, colMap.teacher);
      g.examType = cellText(cells, colMap.examType);
      g.gradeStatus = cellText(cells, colMap.status);
      g.remark = cellText(cells, colMap.remark);
      g.detail = '';
      g.detailPath = '';
      g.detailFields = [];
      var rowTerm = cellText(cells, colMap.term);
      if(colMap.detail >= 0 && cells[colMap.detail]){
        g.detail = (cells[colMap.detail].textContent||'').trim();
        g.detailPath = detailPathFromCell(cells[colMap.detail]);
        g.detailFields = inlineDetailFields(cells[colMap.detail]);
      }
      if(g.detailPath.length === 0){
        for(var detailCellIndex=0; detailCellIndex<cells.length; detailCellIndex++){
          g.detailPath = detailPathFromCell(cells[detailCellIndex]);
          if(g.detailPath.length > 0) break;
        }
      }
      if(g.detailFields.length === 0){
        for(var inlineCellIndex=0; inlineCellIndex<cells.length; inlineCellIndex++){
          g.detailFields = inlineDetailFields(cells[inlineCellIndex]);
          if(g.detailFields.length > 0) break;
        }
      }
      if(g.courseName.length > 0){
        g.termCode = rowTerm || termCode;
        g.termLabel = rowTerm || termLabel;
        grades.push(g);
      }
    }
    if(grades.length > 0) break;
  }
  var collegeRanking = extractCollegeRanking();
  return JSON.stringify({
    grades: grades,
    tables: rawTables,
    termCode: termCode,
    termLabel: termLabel,
    ctype: ctype,
    collegeRanking: collegeRanking,
    recognized: recognized
  });

  function findTermSelect(){
    var preferred = document.querySelector(
      'select[name="zxjxjhh"], select#zxjxjhh, select[name*="xnxq"], select[id*="xnxq"]'
    );
    if(preferred) return preferred;
    var candidates = document.querySelectorAll('select');
    var best = null, bestScore = 0;
    for(var s=0; s<candidates.length; s++){
      var score = 0;
      var identity = ((candidates[s].name || '') + ' ' + (candidates[s].id || '')).toLowerCase();
      if(/term|semester|xnxq|xq|jxjh/.test(identity)) score += 4;
      for(var j=0; j<candidates[s].options.length; j++){
        var optionText = ((candidates[s].options[j].textContent || '') + ' ' +
          (candidates[s].options[j].value || '')).trim();
        if(/20\\d{2}\\s*[-—–~至]\\s*20\\d{2}/.test(optionText)) score += 3;
        if(/(?:[-_]\\s*[12]\\b|第[一二12]学期|春|秋)/.test(optionText)) score += 1;
      }
      if(score > bestScore){
        best = candidates[s];
        bestScore = score;
      }
    }
    return bestScore >= 3 ? best : null;
  }

  function extractCollegeRanking(){
    var nodes = document.querySelectorAll('tr, .form-group, .control-group, .row');
    for(var i = 0; i < nodes.length; i++){
      var text = (nodes[i].textContent || '').replace(/\\s+/g, ' ').trim();
      if(text.indexOf('学院') < 0 ||
         (text.indexOf('排名') < 0 && text.indexOf('百分位') < 0 && text.indexOf('前') < 0)) continue;
      var rankMatch = text.match(/学院(?:内)?(?:排名)?\\s*[:：]?\\s*(\\d+)\\s*(?:\\/(?:(\\d+))|名|\\/\\s*(\\d+))?/);
      var ratioMatch = text.match(/(\\d+)\\s*\\/\\s*(\\d+)/);
      var percentileMatch = text.match(/(?:学院)?(?:百分位|前)\\s*[:：]?\\s*([0-9]+(?:\\.[0-9]+)?%)/);
      var rank = rankMatch ? Number(rankMatch[1]) : (ratioMatch ? Number(ratioMatch[1]) : -1);
      var total = rankMatch && (rankMatch[2] || rankMatch[3]) ?
        Number(rankMatch[2] || rankMatch[3]) : (ratioMatch ? Number(ratioMatch[2]) : -1);
      var percentile = percentileMatch ? percentileMatch[1] : '';
      if(rank > 0 || percentile.length > 0){
        return {rank: rank, total: total, percentile: percentile};
      }
    }
    return {rank: -1, total: -1, percentile: ''};
  }

  function buildGradeColMap(headers){
    var m = {term:-1, name:-1, credit:-1, score:-1, bonus:-1, gpa:-1, teacher:-1, examType:-1, status:-1, remark:-1, detail:-1};
    for(var i=0; i<headers.length; i++){
      var t = headers[i].toLowerCase();
      if(t.includes('学年')||t.includes('学期')) m.term = i;
      else if(t.includes('课程')||t.includes('名称')) m.name = i;
      else if(t.includes('学分')) m.credit = i;
      else if(t.includes('加分')||t.includes('附加')) m.bonus = i;
      else if(t.includes('成绩')||t.includes('分数')||t.includes('得分')) m.score = i;
      else if(t.includes('绩点')||t.includes('gpa')) m.gpa = i;
      else if(t.includes('教师')||t.includes('老师')) m.teacher = i;
      else if(t.includes('考试')||t.includes('考核')||t.includes('性质')) m.examType = i;
      else if(t.includes('状态')) m.status = i;
      else if(t.includes('备注')) m.remark = i;
      else if(t.includes('详情')||t.includes('详细')||t.includes('操作')) m.detail = i;
    }
    return m;
  }
  function cellText(cells, idx){
    if(idx < 0 || idx >= cells.length) return '';
    return (cells[idx].textContent||'').trim();
  }
  function detailPathFromCell(cell){
    if(!cell) return '';
    var node = cell.querySelector('a,button,[data-url],[data-href],[onclick]');
    var candidates = [
      node ? (node.getAttribute('href')||'') : '',
      node ? (node.getAttribute('data-url')||'') : '',
      node ? (node.getAttribute('data-href')||'') : '',
      node ? (node.getAttribute('onclick')||'') : '',
      cell.getAttribute('onclick')||''
    ];
    for(var candidateIndex=0; candidateIndex<candidates.length; candidateIndex++){
      var path = cleanDetailCandidate(candidates[candidateIndex]);
      if(path.length > 0) return path;
    }
    return '';
  }
  function inlineDetailFields(cell){
    if(!cell) return [];
    var nodes = cell.querySelectorAll('[data-content],[data-original-title]');
    var html = '';
    for(var contentIndex=0; contentIndex<nodes.length; contentIndex++){
      html = nodes[contentIndex].getAttribute('data-content')||
        nodes[contentIndex].getAttribute('data-original-title')||'';
      if(html.length > 0) break;
    }
    if(html.length === 0) return [];
    var box = document.createElement('div');
    var marker = '__BJTU_DETAIL_BREAK__';
    box.innerHTML = html.replace(/<br\\s*\\/?>/gi, marker);
    var text = (box.innerText||box.textContent||'').replace(/\\r/g, '');
    var lines = text.split(new RegExp(marker + '|\\\\n+'));
    var fields = [];
    for(var lineIndex=0; lineIndex<lines.length; lineIndex++){
      var line = (lines[lineIndex]||'').trim();
      if(line.length === 0) continue;
      var separator = line.search(/[:：]/);
      var label = '', value = '';
      if(separator > 0){
        label = line.substring(0, separator).trim();
        value = line.substring(separator + 1).trim();
      } else {
        var pair = line.match(/^(.+?(?:\\)|）|信息))\\s+(.+)$/);
        if(pair){ label = pair[1].trim(); value = pair[2].trim(); }
      }
      if(label.length > 0 && value.length > 0){
        fields.push({label:label, value:value});
      }
    }
    if(fields.length === 0){
      var compact = text.replace(new RegExp(marker, 'g'), ' ').trim();
      var pattern = /([^:：]{1,32})[:：]\\s*([^:：]+?)(?=\\s*[^:：]{1,32}[:：]|$)/g;
      var match;
      while((match = pattern.exec(compact)) !== null){
        var compactLabel = (match[1]||'').trim();
        var compactValue = (match[2]||'').trim();
        if(compactLabel.length > 0 && compactValue.length > 0){
          fields.push({label:compactLabel, value:compactValue});
        }
      }
    }
    if(fields.length === 0){
      var knownCompact = text.replace(new RegExp(marker, 'g'), ' ').trim();
      var knownPattern = /(平时(?:成绩|分)(?:\\([^)]*\\)|（[^）]*）)?|期末(?:成绩|分)(?:\\([^)]*\\)|（[^）]*）)?|最终成绩|总评成绩|总成绩|备注信息)\\s*[:：]?\\s*(.*?)(?=平时(?:成绩|分)|期末(?:成绩|分)|最终成绩|总评成绩|总成绩|备注信息|$)/g;
      var knownMatch;
      while((knownMatch = knownPattern.exec(knownCompact)) !== null){
        var knownLabel = (knownMatch[1]||'').trim();
        var knownValue = (knownMatch[2]||'').trim();
        if(knownLabel.length > 0 && knownValue.length > 0){
          fields.push({label:knownLabel, value:knownValue});
        }
      }
    }
    return fields;
  }
  function cleanDetailCandidate(value){
    var cleaned = (value||'').trim();
    if(cleaned.length === 0 || cleaned === '#' ||
       cleaned.toLowerCase().indexOf('javascript:void') === 0 ||
       cleaned.toLowerCase().indexOf('void(') === 0) return '';
    if(/^https?:\\/\\//i.test(cleaned) &&
       cleaned.toLowerCase().indexOf('https://aa.bjtu.edu.cn/') !== 0) return '';
    var match = cleaned.match(/(https?:\\/\\/aa\\.bjtu\\.edu\\.cn\\/[^\\s"'<>]+|\\/[^\\s"'<>]*(?:score|cj|grade)[^\\s"'<>]*)/i);
    if(!match) return '';
    if(match[1].indexOf('//') === 0) return '';
    var path = match[1].replace(/[);,]+$/, '');
    var prefix = 'https://aa.bjtu.edu.cn';
    return path.toLowerCase().indexOf(prefix) === 0 ? path.substring(prefix.length) : path;
  }
})();
`;
  }

  static parseResult(result: string, sourceUrl: string, syncedAt: number = Date.now()): GradeParseResult {
    const parsed: GradeParseResult = new GradeParseResult();
    const raw: Record<string, Object> =
      JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
    parsed.recognized = (raw['recognized'] as boolean) ?? false;
    parsed.termCode = (raw['termCode'] as string) ?? '';
    parsed.termLabel = (raw['termLabel'] as string) ?? '';
    parsed.ctype = (raw['ctype'] as string) ?? '';
    parsed.termSummary.termCode = parsed.termCode;
    parsed.termSummary.termLabel = parsed.termLabel;
    const rankingRaw: Record<string, Object> | undefined = raw['collegeRanking'] as Record<string, Object>;
    if (rankingRaw !== undefined) {
      parsed.termSummary.collegeRank = (rankingRaw['rank'] as number) ?? -1;
      parsed.termSummary.collegeTotal = (rankingRaw['total'] as number) ?? -1;
      parsed.termSummary.collegePercentile = (rankingRaw['percentile'] as string) ?? '';
    }
    const gradesRaw: Object | undefined = raw['grades'];
    if (gradesRaw !== undefined && Array.isArray(gradesRaw) &&
        (gradesRaw as Array<Object>).length > 0) {
      const arr: Array<Object> = gradesRaw as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const item: Record<string, Object> = arr[i] as Record<string, Object>;
        const grade: GradeInfo = new GradeInfo();
        grade.courseName = (item['courseName'] as string) ?? '';
        grade.credit = (item['credit'] as string) ?? '';
        grade.score = (item['score'] as string) ?? '';
        grade.bonusScore = (item['bonusScore'] as string) ?? '';
        grade.gradePoint = (item['gradePoint'] as string) ?? '';
        grade.teacher = (item['teacher'] as string) ?? '';
        grade.examType = (item['examType'] as string) ?? '';
        grade.gradeStatus = (item['gradeStatus'] as string) ?? '';
        grade.remark = (item['remark'] as string) ?? '';
        grade.detail = (item['detail'] as string) ?? '';
        grade.detailPath = GradeParser.normalizeDetailPath((item['detailPath'] as string) ?? '');
        const detailFieldsRaw: Object | undefined = item['detailFields'];
        if (detailFieldsRaw !== undefined && Array.isArray(detailFieldsRaw)) {
          const fields: Array<Object> = detailFieldsRaw as Array<Object>;
          for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
            const rawField: Record<string, Object> = fields[fieldIndex] as Record<string, Object>;
            const field: GradeDetailField = new GradeDetailField();
            field.label = (rawField['label'] as string) ?? '';
            field.value = (rawField['value'] as string) ?? '';
            if (field.label.length > 0 && field.value.length > 0) {
              grade.detailFields.push(field);
            }
          }
        }
        grade.detailTitle = grade.detailFields.length > 0 ? '成绩组成' : '';
        grade.detailLoadedAt = grade.detailFields.length > 0 ? syncedAt : 0;
        const rawTermCode: string = (item['termCode'] as string) ?? '';
        const rawTermLabel: string = (item['termLabel'] as string) ?? rawTermCode;
        grade.termCode = GradeTermOrder.canonical(rawTermCode, rawTermLabel);
        grade.termLabel = GradeTermOrder.normalize(rawTermLabel.length > 0 ? rawTermLabel : rawTermCode);
        grade.sourceUrl = sourceUrl;
        grade.syncedAt = syncedAt;
        grade.id = grade.getDedupeKey();
        if (grade.courseName.length > 0) {
          parsed.grades.push(grade);
        }
      }
      return parsed;
    }
    const tablesRaw: Object | undefined = raw['tables'];
    if (tablesRaw !== undefined && Array.isArray(tablesRaw)) {
      const tableResult: GradeParseResult = GradeParser.parseTables(
        tablesRaw as Array<Object>,
        parsed.termCode,
        parsed.termLabel,
        sourceUrl,
        syncedAt
      );
      tableResult.termCode = parsed.termCode;
      tableResult.termLabel = parsed.termLabel;
      tableResult.ctype = parsed.ctype;
      tableResult.termSummary = parsed.termSummary;
      tableResult.recognized = tableResult.recognized || parsed.recognized;
      return tableResult;
    }
    return parsed;
  }

  static mapHeaders(headers: Array<string>): GradeColumnMap {
    const map: GradeColumnMap = new GradeColumnMap();
    for (let i = 0; i < headers.length; i++) {
      const text: string = headers[i].toLowerCase();
      if (text.includes('学年') || text.includes('学期')) {
        map.term = i;
      } else if (text.includes('课程') || text.includes('名称')) {
        map.name = i;
      } else if (text.includes('学分')) {
        map.credit = i;
      } else if (text.includes('加分') || text.includes('附加')) {
        map.bonus = i;
      } else if (text.includes('成绩') || text.includes('分数') || text.includes('得分')) {
        map.score = i;
      } else if (text.includes('绩点') || text.includes('gpa')) {
        map.gradePoint = i;
      } else if (text.includes('教师') || text.includes('老师')) {
        map.teacher = i;
      } else if (text.includes('考试') || text.includes('考核') || text.includes('性质')) {
        map.examType = i;
      } else if (text.includes('状态')) {
        map.status = i;
      } else if (text.includes('备注')) {
        map.remark = i;
      } else if (text.includes('详情') || text.includes('详细') || text.includes('操作')) {
        map.detail = i;
      }
    }
    return map;
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
      new RegExp("(https?://aa\\.bjtu\\.edu\\.cn/[^\\s\"'<>]+|/[^\\s\"'<>]*(?:score|cj|grade)[^\\s\"'<>]*)", 'i')
    );
    if (match === null || match.length < 2) {
      return '';
    }
    if (match[1].startsWith('//')) {
      return '';
    }
    let path: string = match[1].replace(new RegExp('[);,]+$'), '');
    const prefix: string = 'https://aa.bjtu.edu.cn';
    if (path.toLowerCase().startsWith(prefix)) {
      path = path.substring(prefix.length);
    }
    return path;
  }

  private static parseTables(
    tables: Array<Object>,
    termCode: string,
    termLabel: string,
    sourceUrl: string,
    syncedAt: number
  ): GradeParseResult {
    const parsed: GradeParseResult = new GradeParseResult();
    for (let t = 0; t < tables.length; t++) {
      const table: Record<string, Object> = tables[t] as Record<string, Object>;
      const headersRaw: Object | undefined = table['headers'];
      const rowsRaw: Object | undefined = table['rows'];
      if (headersRaw === undefined || rowsRaw === undefined ||
          !Array.isArray(headersRaw) || !Array.isArray(rowsRaw)) {
        continue;
      }
      const map: GradeColumnMap = GradeParser.mapHeaders(headersRaw as Array<string>);
      if (map.name < 0) {
        continue;
      }
      parsed.recognized = true;
      const rows: Array<Object> = rowsRaw as Array<Object>;
      for (let r = 0; r < rows.length; r++) {
        if (!Array.isArray(rows[r])) {
          continue;
        }
        const row: Array<Object> = rows[r] as Array<Object>;
        const grade: GradeInfo = new GradeInfo();
        grade.courseName = GradeParser.cellText(row, map.name);
        grade.credit = GradeParser.cellText(row, map.credit);
        grade.score = GradeParser.cellText(row, map.score);
        grade.bonusScore = GradeParser.cellText(row, map.bonus);
        grade.gradePoint = GradeParser.cellText(row, map.gradePoint);
        grade.teacher = GradeParser.cellText(row, map.teacher);
        grade.examType = GradeParser.cellText(row, map.examType);
        grade.gradeStatus = GradeParser.cellText(row, map.status);
        grade.remark = GradeParser.cellText(row, map.remark);
        grade.detail = GradeParser.cellText(row, map.detail);
        grade.detailPath = GradeParser.cellDetailPath(row, map.detail);
        if (grade.detailPath.length === 0) {
          grade.detailPath = GradeParser.rowDetailPath(row);
        }
        const rowTerm: string = GradeParser.cellText(row, map.term);
        grade.termCode = GradeTermOrder.canonical(rowTerm.length > 0 ? rowTerm : termCode,
          rowTerm.length > 0 ? rowTerm : termLabel);
        grade.termLabel = GradeTermOrder.normalize(rowTerm.length > 0 ? rowTerm : termLabel);
        grade.sourceUrl = sourceUrl;
        grade.syncedAt = syncedAt;
        grade.id = grade.getDedupeKey();
        if (grade.courseName.length > 0) {
          parsed.grades.push(grade);
        }
      }
      return parsed;
    }
    return parsed;
  }

  private static cellText(row: Array<Object>, index: number): string {
    if (index < 0 || index >= row.length) {
      return '';
    }
    const cell: Record<string, Object> = row[index] as Record<string, Object>;
    return (cell['text'] as string) ?? '';
  }

  private static cellDetailPath(row: Array<Object>, index: number): string {
    if (index < 0 || index >= row.length) {
      return '';
    }
    const cell: Record<string, Object> = row[index] as Record<string, Object>;
    const detailPath: string = (cell['detailPath'] as string) ?? '';
    const normalizedDetailPath: string = GradeParser.normalizeDetailPath(detailPath);
    if (normalizedDetailPath.length > 0) {
      return normalizedDetailPath;
    }
    const href: string = (cell['href'] as string) ?? '';
    const dataUrl: string = (cell['dataUrl'] as string) ?? '';
    const dataHref: string = (cell['dataHref'] as string) ?? '';
    const onclick: string = (cell['onclick'] as string) ?? '';
    const html: string = (cell['html'] as string) ?? '';
    const candidates: Array<string> = [href, dataUrl, dataHref, onclick, html];
    for (let i = 0; i < candidates.length; i++) {
      const normalized: string = GradeParser.normalizeDetailPath(candidates[i]);
      if (normalized.length > 0) {
        return normalized;
      }
    }
    return '';
  }

  private static rowDetailPath(row: Array<Object>): string {
    for (let i = 0; i < row.length; i++) {
      const path: string = GradeParser.cellDetailPath(row, i);
      if (path.length > 0) {
        return path;
      }
    }
    return '';
  }
}
