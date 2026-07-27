import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppThemeMode,
  BuiltInThemeDefinition,
  ThemePalette,
  ThemeSourceType
} from '../common/ThemeModels';
import { DEFAULT_THEME_ID, ThemeRegistry } from '../common/ThemeRegistry';

const STORE_NAME: string = 'bjtu_mis_theme';
const KEY_SCHEMA_VERSION: string = 'schema_version';
const KEY_THEME_SOURCE: string = 'theme_source';
const KEY_THEME_ID: string = 'theme_id';
const SCHEMA_VERSION: number = 1;

export class ThemeManager {
  private static instance: ThemeManager;
  private store: preferences.Preferences | undefined = undefined;
  private persistedThemeId: string = DEFAULT_THEME_ID;
  private activeThemeId: string = DEFAULT_THEME_ID;
  private systemMode: AppThemeMode = AppThemeMode.LIGHT;
  private previewMode: AppThemeMode | undefined = undefined;
  private previewActive: boolean = false;
  private revision: number = 0;
  private changeListener: (() => void) | undefined = undefined;

  private constructor() {
  }

  static getInstance(): ThemeManager {
    if (ThemeManager.instance === undefined) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  static createForTesting(context: common.Context, storeName: string): ThemeManager {
    const manager: ThemeManager = new ThemeManager();
    manager.initializeStore(context, storeName);
    manager.loadSelection();
    return manager;
  }

  initialize(context: common.Context, colorMode?: ConfigurationConstant.ColorMode): void {
    this.initializeStore(context, STORE_NAME);
    this.systemMode = ThemeManager.toAppThemeMode(colorMode);
    this.previewMode = undefined;
    this.previewActive = false;
    this.loadSelection();
    AppStorage.setOrCreate('themeRevision', this.revision);
  }

  setChangeListener(listener: (() => void) | undefined): void {
    this.changeListener = listener;
  }

  beginPreview(themeId: string): boolean {
    if (!ThemeRegistry.isKnown(themeId)) {
      return false;
    }
    this.activeThemeId = themeId;
    this.previewActive = true;
    this.notifyChanged();
    return true;
  }

  setPreviewMode(mode: AppThemeMode): void {
    if (!this.previewActive) {
      return;
    }
    this.previewMode = mode;
    this.notifyChanged();
  }

  commitPreview(): boolean {
    if (!this.previewActive) {
      return false;
    }
    const previousThemeId: string = this.persistedThemeId;
    try {
      this.persistSelection(this.activeThemeId);
      this.persistedThemeId = this.activeThemeId;
      this.previewActive = false;
      this.previewMode = undefined;
      this.notifyChanged();
      return true;
    } catch (_) {
      this.persistedThemeId = previousThemeId;
      this.activeThemeId = previousThemeId;
      this.previewActive = false;
      this.previewMode = undefined;
      this.notifyChanged();
      return false;
    }
  }

  cancelPreview(): void {
    if (!this.previewActive && this.activeThemeId === this.persistedThemeId &&
        this.previewMode === undefined) {
      return;
    }
    this.activeThemeId = this.persistedThemeId;
    this.previewActive = false;
    this.previewMode = undefined;
    this.notifyChanged();
  }

  resetToDefault(): boolean {
    this.activeThemeId = DEFAULT_THEME_ID;
    this.previewActive = true;
    return this.commitPreview();
  }

  handleColorModeChange(colorMode?: ConfigurationConstant.ColorMode): void {
    const nextMode: AppThemeMode = ThemeManager.toAppThemeMode(colorMode);
    if (this.systemMode === nextMode) {
      return;
    }
    this.systemMode = nextMode;
    if (this.previewMode === undefined) {
      this.notifyChanged();
    }
  }

  currentDefinition(): BuiltInThemeDefinition {
    return ThemeRegistry.getById(this.activeThemeId);
  }

  currentPalette(): ThemePalette {
    const definition: BuiltInThemeDefinition = this.currentDefinition();
    return this.effectiveMode() === AppThemeMode.DARK ?
      definition.darkPalette : definition.lightPalette;
  }

  currentThemeId(): string {
    return this.activeThemeId;
  }

  savedThemeId(): string {
    return this.persistedThemeId;
  }

  isPhotoTheme(): boolean {
    return this.currentDefinition().sourceType === ThemeSourceType.PRESET;
  }

  isDarkMode(): boolean {
    return this.effectiveMode() === AppThemeMode.DARK;
  }

  isPreviewing(): boolean {
    return this.previewActive;
  }

  private initializeStore(context: common.Context, storeName: string): void {
    this.store = preferences.getPreferencesSync(context, { name: storeName });
  }

  private loadSelection(): void {
    if (this.store === undefined) {
      this.persistedThemeId = DEFAULT_THEME_ID;
      this.activeThemeId = DEFAULT_THEME_ID;
      return;
    }
    const version: number = this.store.getSync(KEY_SCHEMA_VERSION, 0) as number;
    const storedThemeId: string = this.store.getSync(KEY_THEME_ID, DEFAULT_THEME_ID) as string;
    const safeThemeId: string =
      version === SCHEMA_VERSION && ThemeRegistry.isKnown(storedThemeId) ?
        storedThemeId : DEFAULT_THEME_ID;
    this.persistedThemeId = safeThemeId;
    this.activeThemeId = safeThemeId;
  }

  private persistSelection(themeId: string): void {
    if (this.store === undefined) {
      throw new Error('Theme preferences are not initialized');
    }
    const definition: BuiltInThemeDefinition = ThemeRegistry.getById(themeId);
    this.store.putSync(KEY_SCHEMA_VERSION, SCHEMA_VERSION);
    this.store.putSync(KEY_THEME_SOURCE, definition.sourceType);
    this.store.putSync(KEY_THEME_ID, definition.id);
    this.store.flushSync();
  }

  private effectiveMode(): AppThemeMode {
    return this.previewMode === undefined ? this.systemMode : this.previewMode;
  }

  private notifyChanged(): void {
    this.revision++;
    if (!AppStorage.set('themeRevision', this.revision)) {
      AppStorage.setOrCreate('themeRevision', this.revision);
    }
    if (this.changeListener !== undefined) {
      this.changeListener();
    }
  }

  private static toAppThemeMode(colorMode?: ConfigurationConstant.ColorMode): AppThemeMode {
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ?
      AppThemeMode.DARK : AppThemeMode.LIGHT;
  }
}
