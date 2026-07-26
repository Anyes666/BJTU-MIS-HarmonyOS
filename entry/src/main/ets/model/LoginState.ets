export enum LoginState {
  UNKNOWN = 0,
  NOT_LOGGED_IN = 1,
  LOGGING_IN = 2,
  LOGGED_IN = 3,
  SESSION_EXPIRED = 4,
  NETWORK_ERROR = 5
}

export function loginStateLabel(state: LoginState, hasLocalData: boolean = false): string {
  switch (state) {
    case LoginState.NOT_LOGGED_IN:
      return '未登录';
    case LoginState.LOGGING_IN:
      return '登录中...';
    case LoginState.LOGGED_IN:
      return '已登录';
    case LoginState.SESSION_EXPIRED:
      return '会话已过期';
    case LoginState.NETWORK_ERROR:
      return '网络不可用';
    default:
      return hasLocalData ? '本地数据可用' : '状态未知';
  }
}
