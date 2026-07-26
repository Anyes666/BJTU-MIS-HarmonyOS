import { MailDetail, MailFolder, MailSnapshot, MailSummary } from '../model/MailInfo';
import { ScriptResultDecoder } from './ScriptResultDecoder';

export class MailParser {
  static buildListScript(): string {
    return `
(function() {
  function clean(value) {
    return (value || '').replace(/\\s+/g, ' ').trim();
  }
  function attr(node, names) {
    for (var i = 0; i < names.length; i++) {
      var value = node.getAttribute && node.getAttribute(names[i]);
      if (value) return clean(value);
    }
    return '';
  }
  var folders = [];
  Array.prototype.slice.call(document.querySelectorAll(
    '[data-fid], [data-folder-id], [folderid], .folder-item, .folderItem'
  )).forEach(function(node, index) {
    var name = clean(node.innerText);
    if (!name || name.length > 100) return;
    var id = attr(node, ['data-fid', 'data-folder-id', 'folderid']) || ('folder_' + index);
    var count = name.match(/\\((\\d+)\\s*\\/\\s*(\\d+)\\)|\\((\\d+)\\)/);
    folders.push({
      id: id,
      name: name.replace(/\\s*\\([^)]*\\)\\s*$/, ''),
      unreadCount: count ? parseInt(count[1] || count[3] || '0') : 0,
      messageCount: count ? parseInt(count[2] || count[3] || '0') : 0
    });
  });
  var messages = [];
  Array.prototype.slice.call(document.querySelectorAll(
    'tr[data-mid], [data-message-id], [data-mid].mail-item, .mail-list-item, .mailItem'
  )).forEach(function(node, index) {
    var cells = Array.prototype.slice.call(node.querySelectorAll('th,td'))
      .map(function(cell) { return clean(cell.innerText); }).filter(Boolean);
    var subjectNode = node.querySelector('[data-subject], .subject, .mail-subject, [class*="subject"]');
    var senderNode = node.querySelector('.sender, .from, [class*="sender"], [class*="from"]');
    var timeNode = node.querySelector('time, .time, .date, [class*="time"], [class*="date"]');
    var subject = clean(subjectNode && subjectNode.innerText) || (cells.length > 1 ? cells[1] : '');
    var sender = clean(senderNode && senderNode.innerText) || (cells.length > 0 ? cells[0] : '');
    if (!subject || subject.length > 500) return;
    var id = attr(node, ['data-mid', 'data-message-id', 'mid']) || ('message_' + index);
    messages.push({
      id: id,
      folderId: attr(node, ['data-fid', 'data-folder-id']) || '',
      subject: subject,
      sender: sender,
      receivedAt: clean(timeNode && timeNode.innerText) || (cells.length > 2 ? cells[cells.length - 1] : ''),
      preview: clean(node.getAttribute && node.getAttribute('data-summary')),
      unread: /unread|未读/i.test(node.className || '') || node.getAttribute('aria-label') === '未读',
      hasAttachment: !!node.querySelector('[class*="attach"], [title*="附件"]')
    });
  });
  return JSON.stringify({
    recognized: folders.length > 0 || messages.length > 0,
    folders: folders.slice(0, 100),
    messages: messages.slice(0, 30)
  });
})();
`;
  }

  static buildDetailScript(): string {
    return `
(function() {
  function clean(value) {
    return (value || '').replace(/\\r/g, '').replace(/[ \\t]+/g, ' ').replace(/\\n{3,}/g, '\\n\\n').trim();
  }
  function first(selectors) {
    for (var i = 0; i < selectors.length; i++) {
      var node = document.querySelector(selectors[i]);
      if (node && clean(node.innerText)) return clean(node.innerText);
    }
    return '';
  }
  var body = first(['.mail-content', '.mail-body', '#mailContent', '#content', '[class*="mailBody"]']);
  if (!body && document.body) body = clean(document.body.innerText).substring(0, 20000);
  return JSON.stringify({
    recognized: body.length > 0,
    subject: first(['.subject', '.mail-subject', 'h1', 'h2']),
    sender: first(['.sender', '.from', '[class*="sender"]', '[class*="from"]']),
    recipients: first(['.to', '.recipient', '[class*="recipient"]']),
    receivedAt: first(['time', '.time', '.date', '[class*="time"]']),
    bodyText: body.substring(0, 20000)
  });
})();
`;
  }

  static parseList(result: string, sourcePage: string): MailSnapshot {
    const snapshot: MailSnapshot = new MailSnapshot();
    const raw: Record<string, Object> = MailParser.decode(result);
    const folders: Object | undefined = raw['folders'];
    if (folders !== undefined && Array.isArray(folders)) {
      for (let i = 0; i < folders.length; i++) {
        const item: Record<string, Object> = folders[i] as Record<string, Object>;
        const folder: MailFolder = new MailFolder();
        folder.id = (item['id'] as string) ?? '';
        folder.name = (item['name'] as string) ?? '';
        folder.unreadCount = (item['unreadCount'] as number) ?? 0;
        folder.messageCount = (item['messageCount'] as number) ?? 0;
        if (folder.id.length > 0 && folder.name.length > 0) {
          snapshot.folders.push(folder);
        }
      }
    }
    const messages: Object | undefined = raw['messages'];
    if (messages !== undefined && Array.isArray(messages)) {
      for (let i = 0; i < messages.length; i++) {
        const item: Record<string, Object> = messages[i] as Record<string, Object>;
        const message: MailSummary = new MailSummary();
        message.id = (item['id'] as string) ?? '';
        message.folderId = (item['folderId'] as string) ?? '';
        message.subject = (item['subject'] as string) ?? '';
        message.sender = (item['sender'] as string) ?? '';
        message.receivedAt = (item['receivedAt'] as string) ?? '';
        message.preview = (item['preview'] as string) ?? '';
        message.unread = (item['unread'] as boolean) ?? false;
        message.hasAttachment = (item['hasAttachment'] as boolean) ?? false;
        message.syncedAt = Date.now();
        if (message.subject.length > 0) {
          snapshot.messages.push(message);
        }
      }
    }
    if (snapshot.folders.length > 0 || snapshot.messages.length > 0) {
      snapshot.updatedAt = Date.now();
      snapshot.sourcePage = sourcePage;
    }
    return snapshot;
  }

  static parseDetail(result: string, messageKey: string): MailDetail {
    const detail: MailDetail = new MailDetail();
    const raw: Record<string, Object> = MailParser.decode(result);
    detail.messageKey = messageKey;
    detail.subject = (raw['subject'] as string) ?? '';
    detail.sender = (raw['sender'] as string) ?? '';
    detail.recipients = (raw['recipients'] as string) ?? '';
    detail.receivedAt = (raw['receivedAt'] as string) ?? '';
    detail.bodyText = MailParser.safeText((raw['bodyText'] as string) ?? '');
    if (detail.hasContent()) {
      detail.cachedAt = Date.now();
    }
    return detail;
  }

  static safeText(value: string): string {
    return value
      .replace(new RegExp('<script[\\s\\S]*?</script>', 'gi'), '')
      .replace(new RegExp('<iframe[\\s\\S]*?</iframe>', 'gi'), '')
      .replace(new RegExp('<form[\\s\\S]*?</form>', 'gi'), '')
      .replace(new RegExp('<[^>]+>', 'g'), '')
      .replace(new RegExp('javascript:', 'gi'), '')
      .substring(0, 20000)
      .trim();
  }

  static isRecognized(result: string): boolean {
    return (MailParser.decode(result)['recognized'] as boolean) ?? false;
  }

  private static decode(result: string): Record<string, Object> {
    try {
      return JSON.parse(ScriptResultDecoder.unwrap(result)) as Record<string, Object>;
    } catch (_) {
      return {};
    }
  }
}
