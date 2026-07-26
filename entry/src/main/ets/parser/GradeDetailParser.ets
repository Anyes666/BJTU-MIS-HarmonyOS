import {
  GradeDetailData,
  GradeDetailField,
  GradeDetailTable
} from '../model/GradeInfo';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class GradeDetailParser {
  static buildExtractScript(): string {
    return `
(function(){
  var title = '';
  var titleSelectors = ['.modal-title', 'h1', 'h2', 'h3', 'legend', 'title'];
  for(var titleIndex=0; titleIndex<titleSelectors.length; titleIndex++){
    var titleNode = document.querySelector(titleSelectors[titleIndex]);
    if(titleNode && (titleNode.textContent||'').trim().length > 0){
      title = (titleNode.textContent||'').trim();
      break;
    }
  }
  var fields = [];
  var tables = [];
  var seenFields = {};
  var tableNodes = document.querySelectorAll('table');
  for(var tableIndex=0; tableIndex<tableNodes.length; tableIndex++){
    var table = tableNodes[tableIndex];
    var rowNodes = table.querySelectorAll('tr');
    var rows = [];
    for(var rowIndex=0; rowIndex<rowNodes.length; rowIndex++){
      var cellNodes = rowNodes[rowIndex].querySelectorAll('th, td');
      var row = [];
      for(var cellIndex=0; cellIndex<cellNodes.length; cellIndex++){
        row.push((cellNodes[cellIndex].textContent||'').trim());
      }
      if(row.length > 0) rows.push(row);
    }
    if(rows.length === 0) continue;

    for(var fieldRowIndex=0; fieldRowIndex<rows.length; fieldRowIndex++){
      var fieldRow = rows[fieldRowIndex];
      if(fieldRow.length >= 2 && fieldRow.length % 2 === 0){
        for(var pairIndex=0; pairIndex<fieldRow.length; pairIndex+=2){
          var label = fieldRow[pairIndex].replace(/[：:]$/, '').trim();
          var value = fieldRow[pairIndex+1].trim();
          var key = label + '\\u0000' + value;
          if(label.length > 0 && label.length <= 32 && value.length > 0 && !seenFields[key]){
            seenFields[key] = true;
            fields.push({label:label, value:value});
          }
        }
      }
    }

    var firstCells = rowNodes[0].querySelectorAll('th, td');
    var hasHeader = firstCells.length > 0;
    for(var firstIndex=0; firstIndex<firstCells.length; firstIndex++){
      if((firstCells[firstIndex].tagName||'').toLowerCase() !== 'th'){
        hasHeader = false;
        break;
      }
    }
    var headers = hasHeader ? rows[0] : [];
    var bodyRows = hasHeader ? rows.slice(1) : rows;
    var isFieldTable = !hasHeader;
    for(var bodyIndex=0; bodyIndex<rows.length; bodyIndex++){
      if(rows[bodyIndex].length < 2 || rows[bodyIndex].length % 2 !== 0){
        isFieldTable = false;
        break;
      }
    }
    if(bodyRows.length > 0 && !isFieldTable){
      var tableTitle = '';
      var caption = table.querySelector('caption');
      if(caption) tableTitle = (caption.textContent||'').trim();
      if(tableTitle.length === 0){
        var sibling = table.previousElementSibling;
        while(sibling){
          var tag = (sibling.tagName||'').toLowerCase();
          if(tag === 'h1' || tag === 'h2' || tag === 'h3' || tag === 'h4' || tag === 'legend'){
            tableTitle = (sibling.textContent||'').trim();
            break;
          }
          sibling = sibling.previousElementSibling;
        }
      }
      tables.push({title:tableTitle, headers:headers, rows:bodyRows});
    }
  }
  return JSON.stringify({title:title, fields:fields, tables:tables});
})();
`;
  }

  static parseResult(result: string): GradeDetailData {
    const data: GradeDetailData = new GradeDetailData();
    const raw: Record<string, Object> =
      JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
    data.title = (raw['title'] as string) ?? '';
    const fieldsRaw: Object | undefined = raw['fields'];
    if (fieldsRaw !== undefined && Array.isArray(fieldsRaw)) {
      const fields: Array<Object> = fieldsRaw as Array<Object>;
      for (let i = 0; i < fields.length; i++) {
        const item: Record<string, Object> = fields[i] as Record<string, Object>;
        const field: GradeDetailField = new GradeDetailField();
        field.label = (item['label'] as string) ?? '';
        field.value = (item['value'] as string) ?? '';
        if (field.label.length > 0 && field.value.length > 0) {
          data.fields.push(field);
        }
      }
    }
    const tablesRaw: Object | undefined = raw['tables'];
    if (tablesRaw !== undefined && Array.isArray(tablesRaw)) {
      const tables: Array<Object> = tablesRaw as Array<Object>;
      for (let i = 0; i < tables.length; i++) {
        const item: Record<string, Object> = tables[i] as Record<string, Object>;
        const table: GradeDetailTable = new GradeDetailTable();
        table.title = (item['title'] as string) ?? '';
        const headersRaw: Object | undefined = item['headers'];
        if (headersRaw !== undefined && Array.isArray(headersRaw)) {
          table.headers = headersRaw as Array<string>;
        }
        const rowsRaw: Object | undefined = item['rows'];
        if (rowsRaw !== undefined && Array.isArray(rowsRaw)) {
          const rows: Array<Object> = rowsRaw as Array<Object>;
          for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
            if (Array.isArray(rows[rowIndex])) {
              table.rows.push(rows[rowIndex] as Array<string>);
            }
          }
        }
        if (table.rows.length > 0) {
          data.tables.push(table);
        }
      }
    }
    return data;
  }
}
