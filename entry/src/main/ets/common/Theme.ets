import { ThemeManager } from '../manager/ThemeManager';
import { ThemePalette } from './ThemeModels';
import { ThemeRegistry } from './ThemeRegistry';

export class Theme {
  static background(): ResourceColor {
    return Color.Transparent;
  }

  static surface(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().surface : $r('app.color.app_surface');
  }

  static card(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().card : $r('app.color.app_card');
  }

  static primary(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().primary : $r('app.color.app_primary');
  }

  static dialogPrimary(): string | Resource {
    return Theme.isPhotoTheme() ? Theme.palette().primary : $r('app.color.app_primary');
  }

  static onPrimary(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().onPrimary : $r('app.color.app_on_primary');
  }

  static courseText(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().courseText : $r('app.color.app_course_text');
  }

  static primaryLight(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().primaryLight : $r('app.color.app_primary_light');
  }

  static secondary(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().secondary : $r('app.color.app_secondary');
  }

  static success(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().success : $r('app.color.app_success');
  }

  static warning(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().warning : $r('app.color.app_warning');
  }

  static danger(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().danger : $r('app.color.app_danger');
  }

  static dialogDanger(): string | Resource {
    return Theme.isPhotoTheme() ? Theme.palette().danger : $r('app.color.app_danger');
  }

  static dangerBackground(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().dangerBackground : $r('app.color.app_danger_background');
  }

  static textPrimary(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().textPrimary : $r('app.color.app_text_primary');
  }

  static textSecondary(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().textSecondary : $r('app.color.app_text_secondary');
  }

  static textDisabled(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().textDisabled : $r('app.color.app_text_disabled');
  }

  static border(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().border : $r('app.color.app_border');
  }

  static tabBackground(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().tabBackground : $r('app.color.app_tab_background');
  }

  static topBackground(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().topBackground : $r('app.color.app_top_background');
  }

  static backgroundOverlay(): ResourceColor {
    return Theme.isPhotoTheme() ? Theme.palette().overlay : Color.Transparent;
  }

  static backgroundImage(): ResourceStr {
    if (ThemeManager.getInstance().isCustomTheme()) {
      return ThemeManager.getInstance().customImageUri();
    }
    return ThemeRegistry.backgroundResource(Theme.activeThemeId());
  }

  static activeThumbnail(): ResourceStr {
    if (ThemeManager.getInstance().isCustomTheme()) {
      return ThemeManager.getInstance().customImageUri();
    }
    return ThemeRegistry.thumbnailResource(Theme.activeThemeId());
  }

  static activeThemeId(): string {
    return ThemeManager.getInstance().currentThemeId();
  }

  static activeThemeName(): string {
    return ThemeManager.getInstance().currentDefinition().displayName;
  }

  static focusX(): number {
    return ThemeManager.getInstance().currentDefinition().focusX;
  }

  static focusY(): number {
    return ThemeManager.getInstance().currentDefinition().focusY;
  }

  static backgroundZoomScale(): number {
    return ThemeManager.getInstance().currentZoomScale();
  }

  static backgroundImageWidth(): number {
    return ThemeManager.getInstance().currentDefinition().imageWidth;
  }

  static backgroundImageHeight(): number {
    return ThemeManager.getInstance().currentDefinition().imageHeight;
  }

  static isPhotoTheme(): boolean {
    return ThemeManager.getInstance().isPhotoTheme();
  }

  static isDarkMode(): boolean {
    return ThemeManager.getInstance().isDarkMode();
  }

  static blurStyle(): BlurStyle {
    return Theme.isPhotoTheme() ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE;
  }

  static systemBarColor(): string {
    if (Theme.isPhotoTheme()) {
      return Theme.palette().systemBarColor;
    }
    return Theme.isDarkMode() ? '#101418' : '#F5F7FA';
  }

  static lightSystemIcons(): boolean {
    return Theme.isPhotoTheme() ? Theme.palette().lightSystemIcons : Theme.isDarkMode();
  }

  static course(courseType: string, seed: string = ''): ResourceColor {
    if (Theme.isPhotoTheme()) {
      const colors: Array<string> = Theme.palette().courseColors;
      return colors[Theme.seedIndex(courseType + seed, colors.length)];
    }
    if (courseType.includes('必修')) { return $r('app.color.app_course_required'); }
    if (courseType.includes('选修') || courseType.includes('任选')) {
      return $r('app.color.app_course_elective');
    }
    if (courseType.includes('实验')) { return $r('app.color.app_course_lab'); }
    if (courseType.includes('体育')) { return $r('app.color.app_course_sport'); }
    const paletteIndex: number = Theme.seedIndex(seed, 5);
    if (paletteIndex === 1) { return $r('app.color.app_course_required'); }
    if (paletteIndex === 2) { return $r('app.color.app_course_elective'); }
    if (paletteIndex === 3) { return $r('app.color.app_course_lab'); }
    if (paletteIndex === 4) { return $r('app.color.app_course_sport'); }
    return $r('app.color.app_course_default');
  }

  private static palette(): ThemePalette {
    return ThemeManager.getInstance().currentPalette();
  }

  private static seedIndex(seed: string, size: number): number {
    if (size <= 0) {
      return 0;
    }
    let hash: number = 0;
    for (let i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
    }
    return hash % size;
  }
}
