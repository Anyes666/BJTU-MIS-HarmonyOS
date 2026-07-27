export enum ThemeSourceType {
  DEFAULT = 'default',
  PRESET = 'preset',
  CUSTOM = 'custom'
}

export enum AppThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

class RgbColor {
  r: number = 0;
  g: number = 0;
  b: number = 0;

  constructor(r: number, g: number, b: number) {
    this.r = r;
    this.g = g;
    this.b = b;
  }
}

class HslColor {
  h: number = 0;
  s: number = 0;
  l: number = 0;

  constructor(h: number, s: number, l: number) {
    this.h = h;
    this.s = s;
    this.l = l;
  }
}

export class ThemePalette {
  overlay: string = '#00000000';
  surface: string = '#FFFFFFFF';
  card: string = '#FFFFFFFF';
  primary: string = '#245A78';
  onPrimary: string = '#FFFFFF';
  courseText: string = '#182027';
  primaryLight: string = '#FFE8F0FE';
  secondary: string = '#496A7A';
  success: string = '#207A4A';
  warning: string = '#8A5A00';
  danger: string = '#B4232C';
  dangerBackground: string = '#FFFBEAEC';
  textPrimary: string = '#211D20';
  textSecondary: string = '#514A4E';
  textDisabled: string = '#6D656A';
  border: string = '#756D72';
  tabBackground: string = '#F2FFFFFF';
  topBackground: string = '#EEFFFFFF';
  systemBarColor: string = '#FFF8FAFC';
  lightSystemIcons: boolean = false;
  courseColors: Array<string> = [];
}

export class BuiltInThemeDefinition {
  id: string = '';
  displayName: string = '';
  sourceType: ThemeSourceType = ThemeSourceType.PRESET;
  imageKey: string = '';
  imageWidth: number = 1;
  imageHeight: number = 1;
  seedColor: string = '#245A78';
  neutral: boolean = false;
  focusX: number = 0.5;
  focusY: number = 0.5;
  lightScrimOpacity: number = 0.16;
  darkScrimOpacity: number = 0.48;
  lightPalette: ThemePalette = new ThemePalette();
  darkPalette: ThemePalette = new ThemePalette();

  constructor(
    id: string,
    displayName: string,
    sourceType: ThemeSourceType,
    imageKey: string,
    imageWidth: number,
    imageHeight: number,
    seedColor: string,
    neutral: boolean,
    focusX: number,
    focusY: number,
    lightScrimOpacity: number,
    darkScrimOpacity: number
  ) {
    this.id = id;
    this.displayName = displayName;
    this.sourceType = sourceType;
    this.imageKey = imageKey;
    this.imageWidth = imageWidth;
    this.imageHeight = imageHeight;
    this.seedColor = seedColor;
    this.neutral = neutral;
    this.focusX = focusX;
    this.focusY = focusY;
    this.lightScrimOpacity = lightScrimOpacity;
    this.darkScrimOpacity = darkScrimOpacity;
    this.lightPalette =
      ThemePaletteFactory.create(seedColor, neutral, AppThemeMode.LIGHT, lightScrimOpacity);
    this.darkPalette =
      ThemePaletteFactory.create(seedColor, neutral, AppThemeMode.DARK, darkScrimOpacity);
  }
}

export class ThemePaletteFactory {
  static create(seedColor: string, neutral: boolean, mode: AppThemeMode, scrimOpacity: number): ThemePalette {
    const palette: ThemePalette = new ThemePalette();
    const seed: RgbColor = ThemePaletteFactory.parseHex(seedColor);
    const hsl: HslColor = ThemePaletteFactory.rgbToHsl(seed);
    const dark: boolean = mode === AppThemeMode.DARK;
    const saturation: number = neutral ? 0.06 : ThemePaletteFactory.clamp(hsl.s, 0.48, 0.72);
    const secondaryHue: number = neutral ? hsl.h : (hsl.h + 34) % 360;

    palette.overlay = ThemePaletteFactory.withAlpha(dark ? '#000000' : '#FFFFFF', scrimOpacity);
    if (dark) {
      palette.primary = ThemePaletteFactory.hslToHex(hsl.h, saturation, neutral ? 0.78 : 0.72);
      palette.secondary = ThemePaletteFactory.hslToHex(secondaryHue, neutral ? 0.08 : saturation * 0.82, 0.67);
      palette.surface = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#080A0E', 0.82),
        0.92
      );
      palette.card = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#0E1118', 0.76),
        0.88
      );
      palette.primaryLight = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.hslToHex(hsl.h, neutral ? 0.08 : saturation * 0.72, 0.24),
        0.90
      );
      palette.textPrimary = '#FFF8F5F7';
      palette.textSecondary = '#FFE1DCE0';
      palette.textDisabled = '#FFBBB4B9';
      palette.border = neutral ? '#FF92969E' :
        ThemePaletteFactory.hslToHex(hsl.h, 0.24, 0.68);
      palette.tabBackground = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#080A10', 0.83),
        0.95
      );
      palette.topBackground = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#090C14', 0.78),
        0.94
      );
      palette.systemBarColor = ThemePaletteFactory.mix(seedColor, '#080A10', 0.82);
      palette.lightSystemIcons = true;
      palette.success = '#FF72D69C';
      palette.warning = '#FFFFD06A';
      palette.danger = '#FFFF9298';
      palette.dangerBackground = '#E64A1720';
      palette.courseText = '#FFFFFFFF';
      palette.courseColors = ThemePaletteFactory.coursePalette(hsl.h, neutral, true);
    } else {
      palette.primary = ThemePaletteFactory.hslToHex(hsl.h, saturation, neutral ? 0.34 : 0.36);
      palette.secondary = ThemePaletteFactory.hslToHex(secondaryHue, neutral ? 0.08 : saturation * 0.82, 0.40);
      palette.surface = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#FFFFFF', 0.91),
        0.93
      );
      palette.card = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#FFFFFF', 0.86),
        0.89
      );
      palette.primaryLight = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.hslToHex(hsl.h, neutral ? 0.08 : saturation * 0.50, 0.92),
        0.92
      );
      palette.textPrimary = '#FF211D20';
      palette.textSecondary = '#FF514A4E';
      palette.textDisabled = '#FF6D656A';
      palette.border = neutral ? '#FF666A71' :
        ThemePaletteFactory.hslToHex(hsl.h, 0.22, 0.43);
      palette.tabBackground = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#FFFFFF', 0.91),
        0.96
      );
      palette.topBackground = ThemePaletteFactory.withAlpha(
        ThemePaletteFactory.mix(seedColor, '#FFFFFF', 0.88),
        0.95
      );
      palette.systemBarColor = ThemePaletteFactory.mix(seedColor, '#FFFFFF', 0.90);
      palette.lightSystemIcons = false;
      palette.success = '#FF207A4A';
      palette.warning = '#FF8A5A00';
      palette.danger = '#FFB4232C';
      palette.dangerBackground = '#FFFBEAEC';
      palette.courseText = '#FF191B1F';
      palette.courseColors = ThemePaletteFactory.coursePalette(hsl.h, neutral, false);
    }
    palette.onPrimary = ThemePaletteFactory.bestTextColor(palette.primary);
    return palette;
  }

  static contrastRatio(first: string, second: string): number {
    const firstLuminance: number = ThemePaletteFactory.relativeLuminance(
      ThemePaletteFactory.parseHex(first)
    );
    const secondLuminance: number = ThemePaletteFactory.relativeLuminance(
      ThemePaletteFactory.parseHex(second)
    );
    const lighter: number = Math.max(firstLuminance, secondLuminance);
    const darker: number = Math.min(firstLuminance, secondLuminance);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bestTextColor(background: string): string {
    const whiteContrast: number = ThemePaletteFactory.contrastRatio('#FFFFFF', background);
    const blackContrast: number = ThemePaletteFactory.contrastRatio('#000000', background);
    return whiteContrast >= blackContrast ? '#FFFFFFFF' : '#FF000000';
  }

  private static coursePalette(hue: number, neutral: boolean, dark: boolean): Array<string> {
    if (neutral && dark) {
      return ['#FF393B40', '#FF44474D', '#FF4F535A', '#FF5A5F67', '#FF666C75'];
    }
    if (neutral) {
      return ['#FFD7D9DD', '#FFCACDD2', '#FFBEC2C8', '#FFB2B7BF', '#FFA6ACB6'];
    }
    const offsets: Array<number> = [0, 32, 68, 156, 218];
    const colors: Array<string> = [];
    for (let i = 0; i < offsets.length; i++) {
      colors.push(
        ThemePaletteFactory.hslToHex(
          (hue + offsets[i]) % 360,
          dark ? 0.46 : 0.42,
          dark ? 0.30 : 0.76
        )
      );
    }
    return colors;
  }

  private static parseHex(value: string): RgbColor {
    let hex: string = value.replace('#', '');
    if (hex.length === 8) {
      hex = hex.substring(2);
    }
    if (hex.length !== 6) {
      return new RgbColor(36, 90, 120);
    }
    return new RgbColor(
      parseInt(hex.substring(0, 2), 16),
      parseInt(hex.substring(2, 4), 16),
      parseInt(hex.substring(4, 6), 16)
    );
  }

  private static relativeLuminance(color: RgbColor): number {
    const red: number = ThemePaletteFactory.linearChannel(color.r / 255);
    const green: number = ThemePaletteFactory.linearChannel(color.g / 255);
    const blue: number = ThemePaletteFactory.linearChannel(color.b / 255);
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  private static linearChannel(channel: number): number {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
  }

  private static mix(first: string, second: string, secondWeight: number): string {
    const a: RgbColor = ThemePaletteFactory.parseHex(first);
    const b: RgbColor = ThemePaletteFactory.parseHex(second);
    const weight: number = ThemePaletteFactory.clamp(secondWeight, 0, 1);
    return ThemePaletteFactory.rgbToHex(
      new RgbColor(
        a.r * (1 - weight) + b.r * weight,
        a.g * (1 - weight) + b.g * weight,
        a.b * (1 - weight) + b.b * weight
      )
    );
  }

  private static withAlpha(color: string, opacity: number): string {
    const alpha: number = Math.round(ThemePaletteFactory.clamp(opacity, 0, 1) * 255);
    return '#' + ThemePaletteFactory.channelHex(alpha) + color.replace('#', '').substring(
      color.replace('#', '').length === 8 ? 2 : 0
    );
  }

  private static rgbToHsl(color: RgbColor): HslColor {
    const red: number = color.r / 255;
    const green: number = color.g / 255;
    const blue: number = color.b / 255;
    const maximum: number = Math.max(red, green, blue);
    const minimum: number = Math.min(red, green, blue);
    const delta: number = maximum - minimum;
    let hue: number = 0;
    const lightness: number = (maximum + minimum) / 2;
    if (delta !== 0) {
      if (maximum === red) {
        hue = 60 * (((green - blue) / delta) % 6);
      } else if (maximum === green) {
        hue = 60 * ((blue - red) / delta + 2);
      } else {
        hue = 60 * ((red - green) / delta + 4);
      }
    }
    if (hue < 0) {
      hue += 360;
    }
    const saturation: number = delta === 0 ? 0 : delta / (1 - Math.abs(2 * lightness - 1));
    return new HslColor(hue, saturation, lightness);
  }

  private static hslToHex(hue: number, saturation: number, lightness: number): string {
    const normalizedHue: number = ((hue % 360) + 360) % 360;
    const safeSaturation: number = ThemePaletteFactory.clamp(saturation, 0, 1);
    const safeLightness: number = ThemePaletteFactory.clamp(lightness, 0, 1);
    const chroma: number = (1 - Math.abs(2 * safeLightness - 1)) * safeSaturation;
    const segment: number = normalizedHue / 60;
    const secondary: number = chroma * (1 - Math.abs(segment % 2 - 1));
    let red: number = 0;
    let green: number = 0;
    let blue: number = 0;
    if (segment < 1) {
      red = chroma; green = secondary;
    } else if (segment < 2) {
      red = secondary; green = chroma;
    } else if (segment < 3) {
      green = chroma; blue = secondary;
    } else if (segment < 4) {
      green = secondary; blue = chroma;
    } else if (segment < 5) {
      red = secondary; blue = chroma;
    } else {
      red = chroma; blue = secondary;
    }
    const match: number = safeLightness - chroma / 2;
    return ThemePaletteFactory.rgbToHex(
      new RgbColor((red + match) * 255, (green + match) * 255, (blue + match) * 255)
    );
  }

  private static rgbToHex(color: RgbColor): string {
    return '#' + ThemePaletteFactory.channelHex(color.r) +
      ThemePaletteFactory.channelHex(color.g) + ThemePaletteFactory.channelHex(color.b);
  }

  private static channelHex(value: number): string {
    const text: string = Math.round(ThemePaletteFactory.clamp(value, 0, 255)).toString(16).toUpperCase();
    return text.length === 1 ? '0' + text : text;
  }

  private static clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }
}
