export class MailFolder {
  id: string = '';
  name: string = '';
  unreadCount: number = 0;
  messageCount: number = 0;
}

export class MailSummary {
  id: string = '';
  folderId: string = '';
  subject: string = '';
  sender: string = '';
  receivedAt: string = '';
  preview: string = '';
  unread: boolean = false;
  hasAttachment: boolean = false;
  syncedAt: number = 0;

  businessKey(): string {
    if (this.id.length > 0) {
      return this.folderId + '|' + this.id;
    }
    return this.folderId + '|' + this.subject + '|' + this.sender + '|' + this.receivedAt;
  }
}

export class MailDetail {
  messageKey: string = '';
  subject: string = '';
  sender: string = '';
  recipients: string = '';
  receivedAt: string = '';
  bodyText: string = '';
  cachedAt: number = 0;

  hasContent(): boolean {
    return this.bodyText.length > 0 || this.subject.length > 0;
  }
}

export class MailSnapshot {
  folders: Array<MailFolder> = [];
  messages: Array<MailSummary> = [];
  details: Array<MailDetail> = [];
  updatedAt: number = 0;
  sourcePage: string = '';

  unreadCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.folders.length; i++) {
      count += Math.max(0, this.folders[i].unreadCount);
    }
    return count;
  }
}
