const INITIAL_WHITELIST: Array<string> = [
  'mis.bjtu.edu.cn',
  'webvpn.bjtu.edu.cn',
  'ids.bjtu.edu.cn',
  'auth.bjtu.edu.cn',
  'sso.bjtu.edu.cn',
  'cas.bjtu.edu.cn',
  'my.bjtu.edu.cn',
  'learn.bjtu.edu.cn',
  'dean.bjtu.edu.cn',
  'jwc.bjtu.edu.cn',
  'aa.bjtu.edu.cn',
  'mail.bjtu.edu.cn',
  'bksy.bjtu.edu.cn',
  'gmis.bjtu.edu.cn',
  'zhjw.bjtu.edu.cn',
  'jw.bjtu.edu.cn'
];

const AUTH_PAGE_PATTERNS: Array<string> = [
  'login',
  'auth',
  'sso',
  'cas',
  'signin',
  'oauth',
  'passport',
  'ids.bjtu.edu.cn'
];

export class WhiteListManager {
  private static instance: WhiteListManager;
  private confirmedDomains: Array<string> = [];
  private observedDomains: Array<string> = [];
  private blockedDomains: Array<string> = [];

  private constructor() {
    this.confirmedDomains = INITIAL_WHITELIST.slice(0);
  }

  static getInstance(): WhiteListManager {
    if (WhiteListManager.instance === undefined) {
      WhiteListManager.instance = new WhiteListManager();
    }
    return WhiteListManager.instance;
  }

  isAllowed(url: string): boolean {
    if (url.length === 0) {
      return false;
    }
    if (url === 'about:blank') {
      return true;
    }
    if (!url.toLowerCase().startsWith('https://')) {
      return false;
    }
    const host: string = this.extractDomain(url);
    if (host.length === 0) {
      return false;
    }
    for (let i = 0; i < this.blockedDomains.length; i++) {
      if (host === this.blockedDomains[i]) {
        return false;
      }
    }
    for (let i = 0; i < this.confirmedDomains.length; i++) {
      if (host === this.confirmedDomains[i]) {
        return true;
      }
    }
    this.observeNewDomain(url);
    return false;
  }

  isAuthPage(url: string): boolean {
    const host: string = this.extractDomain(url);
    if (host === 'cas.bjtu.edu.cn' || host === 'ids.bjtu.edu.cn' ||
        host === 'auth.bjtu.edu.cn' || host === 'sso.bjtu.edu.cn') {
      return true;
    }
    for (let i = 0; i < AUTH_PAGE_PATTERNS.length; i++) {
      if (url.toLowerCase().includes(AUTH_PAGE_PATTERNS[i])) {
        return true;
      }
    }
    return false;
  }

  isMisHomePage(url: string): boolean {
    if (this.extractDomain(url) === 'mis.bjtu.edu.cn' &&
        !url.includes('login') &&
        !url.includes('auth') &&
        !url.includes('oauth')) {
      return true;
    }
    return false;
  }

  canExtractData(url: string): boolean {
    if (url.length === 0) {
      return false;
    }
    if (this.isAuthPage(url)) {
      return false;
    }
    if (!this.isAllowed(url)) {
      return false;
    }
    return true;
  }

  getObservedDomains(): Array<string> {
    return this.observedDomains.slice(0);
  }

  confirmDomain(domain: string): void {
    if (!domain.endsWith('.bjtu.edu.cn') && domain !== 'bjtu.edu.cn') {
      return;
    }
    const found = this.confirmedDomains.find((d: string): boolean => d === domain);
    if (found === undefined) {
      this.confirmedDomains.push(domain);
    }
  }

  blockDomain(domain: string): void {
    const found = this.blockedDomains.find((d: string): boolean => d === domain);
    if (found === undefined) {
      this.blockedDomains.push(domain);
    }
  }

  reset(): void {
    this.confirmedDomains = INITIAL_WHITELIST.slice(0);
    this.observedDomains = [];
    this.blockedDomains = [];
  }

  private observeNewDomain(url: string): void {
    const domain: string = this.extractDomain(url);
    if (domain.length === 0) {
      return;
    }
    const found = this.observedDomains.find((d: string): boolean => d === domain);
    if (found === undefined) {
      this.observedDomains.push(domain);
    }
  }

  private extractDomain(url: string): string {
    if (url.length === 0) {
      return '';
    }
    const schemeIndex: number = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const authorityStart: number = schemeIndex + 3;
    let authorityEnd: number = url.length;
    const separators: Array<string> = ['/', '?', '#', '\\'];
    for (let i = 0; i < separators.length; i++) {
      const index: number = url.indexOf(separators[i], authorityStart);
      if (index >= 0 && index < authorityEnd) {
        authorityEnd = index;
      }
    }
    let authority: string = url.substring(authorityStart, authorityEnd).toLowerCase();
    const userInfoIndex: number = authority.lastIndexOf('@');
    if (userInfoIndex >= 0) {
      authority = authority.substring(userInfoIndex + 1);
    }
    if (authority.startsWith('[')) {
      return '';
    }
    const colonIndex: number = authority.lastIndexOf(':');
    if (colonIndex >= 0) {
      const port: string = authority.substring(colonIndex + 1);
      if (port.length === 0 || !new RegExp('^\\d+$').test(port)) {
        return '';
      }
      authority = authority.substring(0, colonIndex);
    }
    return new RegExp('^[a-z0-9.-]+$').test(authority) ? authority : '';
  }
}
