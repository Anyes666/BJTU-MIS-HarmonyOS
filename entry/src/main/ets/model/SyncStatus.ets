export enum SyncPhase {
  IDLE = 'idle',
  WAITING_FOR_LOGIN = 'waiting_login',
  MIS_AUTHENTICATED = 'mis_authenticated',
  OPENING_AA = 'opening_aa',
  AA_READY = 'aa_ready',
  LOADING_TIMETABLE = 'loading_timetable',
  PARSING_TIMETABLE = 'parsing_timetable',
  LOADING_EXAMS = 'loading_exams',
  PARSING_EXAMS = 'parsing_exams',
  LOADING_PROFILE = 'loading_profile',
  PARSING_PROFILE = 'parsing_profile',
  LOADING_PROGRESS = 'loading_progress',
  PARSING_PROGRESS = 'parsing_progress',
  LOADING_MAIL = 'loading_mail',
  PARSING_MAIL = 'parsing_mail',
  DISCOVERING_SCORE_TERMS = 'discovering_score_terms',
  LOADING_SCORE_TERM = 'loading_score_term',
  VALIDATING = 'validating',
  COMMITTING = 'committing',
  COMPLETED = 'completed',
  PARTIAL_SUCCESS = 'partial_success',
  SESSION_EXPIRED = 'session_expired',
  NETWORK_ERROR = 'network_error',
  PAGE_NOT_RECOGNIZED = 'page_not_recognized',
  PARSE_FAILED = 'parse_failed',
  CANCELLED = 'cancelled'
}

export class SyncPhaseTrace {
  phase: SyncPhase = SyncPhase.IDLE;
  message: string = '';
  startedAt: number = 0;
  endedAt: number = 0;
  errorReason: string = '';
}

export class SyncStatus {
  phase: SyncPhase = SyncPhase.IDLE;
  message: string = '';
  startedAt: number = 0;
  phaseStartedAt: number = 0;
  phaseEndedAt: number = 0;
  completedAt: number = 0;
  errorReason: string = '';
  running: boolean = false;
  cancelled: boolean = false;
  timetableCount: number = 0;
  examCount: number = 0;
  gradeTotalTerms: number = 0;
  gradeCompletedTerms: number = 0;
  gradeTotalCount: number = 0;
  totalProgress: number = 0;
  errors: Array<string> = [];
  traces: Array<SyncPhaseTrace> = [];

  clone(): SyncStatus {
    const copy: SyncStatus = new SyncStatus();
    copy.phase = this.phase;
    copy.message = this.message;
    copy.startedAt = this.startedAt;
    copy.phaseStartedAt = this.phaseStartedAt;
    copy.phaseEndedAt = this.phaseEndedAt;
    copy.completedAt = this.completedAt;
    copy.errorReason = this.errorReason;
    copy.running = this.running;
    copy.cancelled = this.cancelled;
    copy.timetableCount = this.timetableCount;
    copy.examCount = this.examCount;
    copy.gradeTotalTerms = this.gradeTotalTerms;
    copy.gradeCompletedTerms = this.gradeCompletedTerms;
    copy.gradeTotalCount = this.gradeTotalCount;
    copy.totalProgress = this.totalProgress;
    copy.errors = this.errors.slice(0);
    for (let i = 0; i < this.traces.length; i++) {
      const trace: SyncPhaseTrace = new SyncPhaseTrace();
      trace.phase = this.traces[i].phase;
      trace.message = this.traces[i].message;
      trace.startedAt = this.traces[i].startedAt;
      trace.endedAt = this.traces[i].endedAt;
      trace.errorReason = this.traces[i].errorReason;
      copy.traces.push(trace);
    }
    return copy;
  }
}
