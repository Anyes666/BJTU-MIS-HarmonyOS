import {
  BuiltInThemeDefinition,
  ThemeSourceType
} from './ThemeModels';

export const DEFAULT_THEME_ID: string = 'classic_default';

const BUILT_IN_THEMES: Array<BuiltInThemeDefinition> = [
  new BuiltInThemeDefinition(
    DEFAULT_THEME_ID,
    '经典默认',
    ThemeSourceType.DEFAULT,
    '',
    1,
    1,
    '#245A78',
    false,
    0.5,
    0.5,
    0,
    0
  ),
  new BuiltInThemeDefinition(
    'sakura_pink',
    '樱粉心语',
    ThemeSourceType.PRESET,
    'sakura',
    1086,
    1448,
    '#EEAAB4',
    false,
    0.50,
    0.43,
    0.16,
    0.68
  ),
  new BuiltInThemeDefinition(
    'amber_energy',
    '暖阳活力',
    ThemeSourceType.PRESET,
    'amber',
    1254,
    1254,
    '#F6CF82',
    false,
    0.52,
    0.42,
    0.18,
    0.56
  ),
  new BuiltInThemeDefinition(
    'monochrome_ink',
    '墨白静谧',
    ThemeSourceType.PRESET,
    'ink',
    1080,
    1080,
    '#58585B',
    true,
    0.51,
    0.44,
    0.08,
    0.76
  ),
  new BuiltInThemeDefinition(
    'midnight_stage',
    '深海乐章',
    ThemeSourceType.PRESET,
    'midnight',
    1032,
    2004,
    '#444C71',
    false,
    0.48,
    0.46,
    0.34,
    0.28
  ),
  new BuiltInThemeDefinition(
    'crystal_blue',
    '冰晶之境',
    ThemeSourceType.PRESET,
    'crystal',
    1122,
    1402,
    '#5D6FB3',
    false,
    0.54,
    0.38,
    0.24,
    0.42
  )
];

export class ThemeRegistry {
  static all(): Array<BuiltInThemeDefinition> {
    return BUILT_IN_THEMES.slice(0);
  }

  static getById(themeId: string): BuiltInThemeDefinition {
    for (let i = 0; i < BUILT_IN_THEMES.length; i++) {
      if (BUILT_IN_THEMES[i].id === themeId) {
        return BUILT_IN_THEMES[i];
      }
    }
    return BUILT_IN_THEMES[0];
  }

  static isKnown(themeId: string): boolean {
    for (let i = 0; i < BUILT_IN_THEMES.length; i++) {
      if (BUILT_IN_THEMES[i].id === themeId) {
        return true;
      }
    }
    return false;
  }

  static backgroundResource(themeId: string): Resource {
    switch (themeId) {
      case 'sakura_pink':
        return $r('app.media.theme_sakura_bg');
      case 'amber_energy':
        return $r('app.media.theme_amber_bg');
      case 'monochrome_ink':
        return $r('app.media.theme_ink_bg');
      case 'midnight_stage':
        return $r('app.media.theme_midnight_bg');
      case 'crystal_blue':
        return $r('app.media.theme_crystal_bg');
      default:
        return $r('app.media.background');
    }
  }

  static thumbnailResource(themeId: string): Resource {
    switch (themeId) {
      case 'sakura_pink':
        return $r('app.media.theme_sakura_thumb');
      case 'amber_energy':
        return $r('app.media.theme_amber_thumb');
      case 'monochrome_ink':
        return $r('app.media.theme_ink_thumb');
      case 'midnight_stage':
        return $r('app.media.theme_midnight_thumb');
      case 'crystal_blue':
        return $r('app.media.theme_crystal_thumb');
      default:
        return $r('app.media.startIcon');
    }
  }
}
