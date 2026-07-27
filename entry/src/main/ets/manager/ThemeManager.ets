import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AppThemeMode,
  BuiltInThemeDefinition,
  CustomThemeProfile,
  MAX_CUSTOM_THEME_ZOOM,
  MIN_CUSTOM_THEME_ZOOM,
  ThemePalette,
  ThemeSourceType
} from '../common/ThemeModels';
import {
  CUSTOM_THEME_ID,
  DEFAULT_THEME_ID,
  ThemeRegistry
} from '../common/ThemeRegistry';
import { CustomThemeProcessor } from './CustomThemeProcessor';

const STORE_NAME: string = 'bjtu_mis_theme';
const KEY_SCHEMA_VERSION: string = 'schema_version';
const KEY_THEME_SOURCE: string = 'theme_source';
const KEY_THEME_ID: string = 'theme_id';
const KEY_CUSTOM_VERSION: string = 'custom_version';
const KEY_CUSTOM_IMAGE_PATH: string = 'custom_image_path';
const KEY_CUSTOM_IMAGE_WIDTH: string = 'custom_image_width';
const KEY_CUSTOM_IMAGE_HEIGHT: string = 'custom_image_height';
const KEY_CUSTOM_SEED_COLOR: string = 'custom_seed_color';
const KEY_CUSTOM_NEUTRAL: string = 'custom_neutral';
const KEY_CUSTOM_FOCUS_X: string = 'custom_focus_x';
const KEY_CUSTOM_FOCUS_Y: string = 'custom_focus_y';
const KEY_CUSTOM_ZOOM_SCALE: string = 'custom_zoom_scale';
const KEY_CUSTOM_LIGHT_SCRIM: string = 'custom_light_scrim';
const KEY_CUSTOM_DARK_SCRIM: string = 'custom_dark_scrim';
const LEGACY_SCHEMA_VERSION: number = 1;
const SCHEMA_VERSION: number = 2;
const CUSTOM_PROFILE_VERSION: number = 1;
const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'BjtuMisTheme';

export class ThemeManager {
  private static instance: ThemeManager;
  private context: common.Context | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;
  private persistedThemeId: string = DEFAULT_THEME_ID;
  private activeThemeId: string = DEFAULT_THEME_ID;
  private customProfile: CustomThemeProfile | undefined = undefined;
  private customDefinition: BuiltInThemeDefinition | undefined = undefined;
  private customDraft: CustomThemeProfile | undefined = undefined;
  private customDraftDefinition: BuiltInThemeDefinition | undefined = undefined;
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
    manager.context = context;
    manager.initializeStore(context, storeName);
    manager.loadSelection();
    return manager;
  }

  initialize(context: common.Context, colorMode?: ConfigurationConstant.ColorMode): void {
    this.context = context;
    this.initializeStore(context, STORE_NAME);
    this.systemMode = ThemeManager.toAppThemeMode(colorMode);
    this.previewMode = undefined;
    this.previewActive = false;
    this.discardCustomDraft();
    this.loadSelection();
    AppStorage.setOrCreate('themeRevision', this.revision);
  }

  setChangeListener(listener: (() => void) | undefined): void {
    this.changeListener = listener;
  }

  beginPreview(themeId: string): boolean {
    const available: boolean = themeId === CUSTOM_THEME_ID ?
      this.customDefinition !== undefined : ThemeRegistry.isKnown(themeId);
    if (!available) {
      return false;
    }
    this.discardCustomDraft();
    this.activeThemeId = themeId;
    this.previewActive = true;
    this.notifyChanged();
    return true;
  }

  beginCustomPreview(): boolean {
    if (this.customProfile === undefined) {
      return false;
    }
    this.discardCustomDraft();
    this.customDraft = ThemeManager.copyProfile(this.customProfile);
    this.customDraftDefinition = this.definitionFromProfile(this.customDraft);
    this.activeThemeId = CUSTOM_THEME_ID;
    this.previewActive = true;
    this.notifyChanged();
    return true;
  }

  async prepareCustomPhoto(uri: string): Promise<boolean> {
    if (this.context === undefined) {
      throw new Error('主题服务尚未初始化');
    }
    const prepared: CustomThemeProfile =
      await CustomThemeProcessor.prepare(uri, this.context.filesDir);
    this.discardCustomDraft();
    this.customDraft = prepared;
    this.customDraftDefinition = this.definitionFromProfile(prepared);
    this.activeThemeId = CUSTOM_THEME_ID;
    this.previewActive = true;
    this.notifyChanged();
    return true;
  }

  updateCustomDraftFocus(focusX: number, focusY: number): void {
    const zoomScale: number = this.customDraft === undefined ?
      MIN_CUSTOM_THEME_ZOOM : this.customDraft.zoomScale;
    this.updateCustomDraftTransform(focusX, focusY, zoomScale);
  }

  updateCustomDraftTransform(focusX: number, focusY: number, zoomScale: number): void {
    if (this.customDraft === undefined || this.customDraftDefinition === undefined) {
      return;
    }
    const safeX: number = ThemeManager.clamp(focusX, 0, 1);
    const safeY: number = ThemeManager.clamp(focusY, 0, 1);
    const safeZoom: number =
      ThemeManager.clamp(zoomScale, MIN_CUSTOM_THEME_ZOOM, MAX_CUSTOM_THEME_ZOOM);
    this.customDraft.focusX = safeX;
    this.customDraft.focusY = safeY;
    this.customDraft.zoomScale = safeZoom;
    this.customDraftDefinition.focusX = safeX;
    this.customDraftDefinition.focusY = safeY;
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
    const previousCustomProfile: CustomThemeProfile | undefined = this.customProfile;
    let committedDraft: CustomThemeProfile | undefined = undefined;
    let createdFilePath: string = '';
    try {
      if (this.activeThemeId === CUSTOM_THEME_ID) {
        if (this.customDraft !== undefined) {
          if (this.context === undefined) {
            throw new Error('主题服务尚未初始化');
          }
          committedDraft = this.customDraft.temporary ?
            CustomThemeProcessor.commitDraft(this.customDraft, this.context.filesDir) :
            ThemeManager.copyProfile(this.customDraft);
          if (this.customDraft.temporary) {
            createdFilePath = committedDraft.imagePath;
          }
          this.persistSelection(CUSTOM_THEME_ID, committedDraft);
          this.customProfile = committedDraft;
          this.customDefinition = this.definitionFromProfile(committedDraft);
        } else if (this.customProfile !== undefined) {
          this.persistSelection(CUSTOM_THEME_ID, this.customProfile);
        } else {
          throw new Error('没有可应用的自定义照片');
        }
      } else {
        this.persistSelection(this.activeThemeId);
      }
      this.persistedThemeId = this.activeThemeId;
      this.customDraft = undefined;
      this.customDraftDefinition = undefined;
      this.previewActive = false;
      this.previewMode = undefined;
      if (committedDraft !== undefined && previousCustomProfile !== undefined &&
          committedDraft.imagePath !== previousCustomProfile.imagePath) {
        CustomThemeProcessor.deleteFile(previousCustomProfile.imagePath);
      }
      this.notifyChanged();
      return true;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : 'unknown error';
      hilog.error(
        LOG_DOMAIN,
        LOG_TAG,
        'Failed to commit theme preview. Cause: %{private}s',
        message
      );
      if (createdFilePath.length > 0) {
        CustomThemeProcessor.deleteFile(createdFilePath);
      }
      this.customProfile = previousCustomProfile;
      this.customDefinition = previousCustomProfile === undefined ?
        undefined : this.definitionFromProfile(previousCustomProfile);
      this.persistedThemeId = previousThemeId;
      this.activeThemeId = previousThemeId;
      this.customDraft = undefined;
      this.customDraftDefinition = undefined;
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
    this.discardCustomDraft();
    this.activeThemeId = this.persistedThemeId;
    this.previewActive = false;
    this.previewMode = undefined;
    this.notifyChanged();
  }

  resetToDefault(): boolean {
    this.discardCustomDraft();
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
    if (this.activeThemeId === CUSTOM_THEME_ID) {
      if (this.customDraftDefinition !== undefined) {
        return this.customDraftDefinition;
      }
      if (this.customDefinition !== undefined) {
        return this.customDefinition;
      }
    }
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
    return this.currentDefinition().sourceType !== ThemeSourceType.DEFAULT;
  }

  isCustomTheme(): boolean {
    return this.activeThemeId === CUSTOM_THEME_ID &&
      (this.customDraftDefinition !== undefined || this.customDefinition !== undefined);
  }

  hasCustomTheme(): boolean {
    return this.customProfile !== undefined;
  }

  hasCustomPreview(): boolean {
    return this.activeThemeId === CUSTOM_THEME_ID &&
      (this.customDraft !== undefined || this.customProfile !== undefined);
  }

  customImageUri(): string {
    const profile: CustomThemeProfile | undefined =
      this.customDraft !== undefined ? this.customDraft : this.customProfile;
    return profile === undefined ? '' : CustomThemeProcessor.imageUri(profile.imagePath);
  }

  currentZoomScale(): number {
    if (this.activeThemeId !== CUSTOM_THEME_ID) {
      return MIN_CUSTOM_THEME_ZOOM;
    }
    const profile: CustomThemeProfile | undefined =
      this.customDraft !== undefined ? this.customDraft : this.customProfile;
    return profile === undefined ? MIN_CUSTOM_THEME_ZOOM : profile.zoomScale;
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
    this.customProfile = this.loadCustomProfile();
    this.customDefinition = this.customProfile === undefined ?
      undefined : this.definitionFromProfile(this.customProfile);
    if (this.store === undefined) {
      this.persistedThemeId = DEFAULT_THEME_ID;
      this.activeThemeId = DEFAULT_THEME_ID;
      return;
    }
    const version: number = this.store.getSync(KEY_SCHEMA_VERSION, 0) as number;
    const storedThemeId: string = this.store.getSync(KEY_THEME_ID, DEFAULT_THEME_ID) as string;
    let safeThemeId: string = DEFAULT_THEME_ID;
    if ((version === LEGACY_SCHEMA_VERSION || version === SCHEMA_VERSION) &&
        ThemeRegistry.isKnown(storedThemeId)) {
      safeThemeId = storedThemeId;
    } else if (version === SCHEMA_VERSION && storedThemeId === CUSTOM_THEME_ID &&
        this.customProfile !== undefined) {
      safeThemeId = CUSTOM_THEME_ID;
    }
    this.persistedThemeId = safeThemeId;
    this.activeThemeId = safeThemeId;
  }

  private loadCustomProfile(): CustomThemeProfile | undefined {
    if (this.store === undefined || this.context === undefined) {
      return undefined;
    }
    const version: number = this.store.getSync(KEY_CUSTOM_VERSION, 0) as number;
    const imagePath: string = this.store.getSync(KEY_CUSTOM_IMAGE_PATH, '') as string;
    const imageWidth: number = this.store.getSync(KEY_CUSTOM_IMAGE_WIDTH, 0) as number;
    const imageHeight: number = this.store.getSync(KEY_CUSTOM_IMAGE_HEIGHT, 0) as number;
    const seedColor: string = this.store.getSync(KEY_CUSTOM_SEED_COLOR, '#245A78') as string;
    const focusX: number = this.store.getSync(KEY_CUSTOM_FOCUS_X, 0.5) as number;
    const focusY: number = this.store.getSync(KEY_CUSTOM_FOCUS_Y, 0.5) as number;
    const zoomScale: number =
      this.store.getSync(KEY_CUSTOM_ZOOM_SCALE, MIN_CUSTOM_THEME_ZOOM) as number;
    if (version !== CUSTOM_PROFILE_VERSION || imageWidth <= 0 || imageHeight <= 0 ||
        !CustomThemeProcessor.isManagedPath(imagePath, this.context.filesDir) ||
        !CustomThemeProcessor.fileExists(imagePath)) {
      return undefined;
    }
    return new CustomThemeProfile(
      imagePath,
      imageWidth,
      imageHeight,
      seedColor,
      this.store.getSync(KEY_CUSTOM_NEUTRAL, false) as boolean,
      ThemeManager.clamp(focusX, 0, 1),
      ThemeManager.clamp(focusY, 0, 1),
      this.store.getSync(KEY_CUSTOM_LIGHT_SCRIM, 0.20) as number,
      this.store.getSync(KEY_CUSTOM_DARK_SCRIM, 0.52) as number,
      false,
      ThemeManager.clamp(zoomScale, MIN_CUSTOM_THEME_ZOOM, MAX_CUSTOM_THEME_ZOOM)
    );
  }

  private persistSelection(themeId: string, customProfile?: CustomThemeProfile): void {
    if (this.store === undefined) {
      throw new Error('Theme preferences are not initialized');
    }
    let sourceType: ThemeSourceType = ThemeSourceType.DEFAULT;
    if (themeId === CUSTOM_THEME_ID) {
      if (customProfile === undefined) {
        throw new Error('Custom theme profile is missing');
      }
      sourceType = ThemeSourceType.CUSTOM;
      this.persistCustomProfile(customProfile);
    } else {
      sourceType = ThemeRegistry.getById(themeId).sourceType;
    }
    this.store.putSync(KEY_SCHEMA_VERSION, SCHEMA_VERSION);
    this.store.putSync(KEY_THEME_SOURCE, sourceType);
    this.store.putSync(KEY_THEME_ID, themeId);
    this.store.flushSync();
  }

  private persistCustomProfile(profile: CustomThemeProfile): void {
    if (this.store === undefined) {
      throw new Error('Theme preferences are not initialized');
    }
    this.store.putSync(KEY_CUSTOM_VERSION, CUSTOM_PROFILE_VERSION);
    this.store.putSync(KEY_CUSTOM_IMAGE_PATH, profile.imagePath);
    this.store.putSync(KEY_CUSTOM_IMAGE_WIDTH, profile.imageWidth);
    this.store.putSync(KEY_CUSTOM_IMAGE_HEIGHT, profile.imageHeight);
    this.store.putSync(KEY_CUSTOM_SEED_COLOR, profile.seedColor);
    this.store.putSync(KEY_CUSTOM_NEUTRAL, profile.neutral);
    this.store.putSync(KEY_CUSTOM_FOCUS_X, profile.focusX);
    this.store.putSync(KEY_CUSTOM_FOCUS_Y, profile.focusY);
    this.store.putSync(KEY_CUSTOM_ZOOM_SCALE, profile.zoomScale);
    this.store.putSync(KEY_CUSTOM_LIGHT_SCRIM, profile.lightScrimOpacity);
    this.store.putSync(KEY_CUSTOM_DARK_SCRIM, profile.darkScrimOpacity);
  }

  private definitionFromProfile(profile: CustomThemeProfile): BuiltInThemeDefinition {
    return new BuiltInThemeDefinition(
      CUSTOM_THEME_ID,
      '我的照片',
      ThemeSourceType.CUSTOM,
      profile.imagePath,
      profile.imageWidth,
      profile.imageHeight,
      profile.seedColor,
      profile.neutral,
      profile.focusX,
      profile.focusY,
      profile.lightScrimOpacity,
      profile.darkScrimOpacity
    );
  }

  private discardCustomDraft(): void {
    if (this.customDraft !== undefined && this.customDraft.temporary) {
      CustomThemeProcessor.deleteFile(this.customDraft.imagePath);
    }
    this.customDraft = undefined;
    this.customDraftDefinition = undefined;
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

  private static copyProfile(profile: CustomThemeProfile): CustomThemeProfile {
    return new CustomThemeProfile(
      profile.imagePath,
      profile.imageWidth,
      profile.imageHeight,
      profile.seedColor,
      profile.neutral,
      profile.focusX,
      profile.focusY,
      profile.lightScrimOpacity,
      profile.darkScrimOpacity,
      profile.temporary,
      profile.zoomScale
    );
  }

  private static clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private static toAppThemeMode(colorMode?: ConfigurationConstant.ColorMode): AppThemeMode {
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ?
      AppThemeMode.DARK : AppThemeMode.LIGHT;
  }
}
