import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { ThemeRegistry } from '../../../main/ets/common/ThemeRegistry';
import {
  AppThemeMode,
  BuiltInThemeDefinition,
  ThemePalette,
  ThemePaletteFactory,
  ThemeSourceType
} from '../../../main/ets/common/ThemeModels';
import { ThemeManager } from '../../../main/ets/manager/ThemeManager';
import { CustomThemeProcessor } from '../../../main/ets/manager/CustomThemeProcessor';

const TEST_STORE_NAME: string = 'bjtu_mis_theme_ohos_test';

function clearThemeStore(): void {
  const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
    .getAppContext().createModuleContext('entry_test');
  const store: preferences.Preferences =
    preferences.getPreferencesSync(moduleContext, { name: TEST_STORE_NAME });
  store.clearSync();
  store.flushSync();
}

function verifyContrast(label: string, foreground: string, background: string, minimum: number): void {
  const ratio: number = ThemePaletteFactory.contrastRatio(foreground, background);
  if (ratio < minimum) {
    throw new Error(label + ' contrast ' + ratio.toFixed(2) + ' is below ' + minimum.toFixed(1));
  }
}

function verifyPaletteContrast(label: string, palette: ThemePalette): void {
  verifyContrast(label + ':onPrimary', palette.onPrimary, palette.primary, 4.5);
  verifyContrast(label + ':textPrimary', palette.textPrimary, palette.surface, 4.5);
  verifyContrast(label + ':textSecondary', palette.textSecondary, palette.surface, 4.5);
  verifyContrast(label + ':border', palette.border, palette.surface, 3.0);
  for (let i = 0; i < palette.courseColors.length; i++) {
    verifyContrast(label + ':course' + i, palette.courseText, palette.courseColors[i], 4.5);
  }
}

function solidRgba(red: number, green: number, blue: number, width: number, height: number): ArrayBuffer {
  const buffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
  const bytes: Uint8Array = new Uint8Array(buffer);
  for (let i = 0; i < width * height; i++) {
    const offset: number = i * 4;
    bytes[offset] = red;
    bytes[offset + 1] = green;
    bytes[offset + 2] = blue;
    bytes[offset + 3] = 255;
  }
  return buffer;
}

export default function themeTest(): void {
  describe('BuiltInPhotoThemeTest', () => {
    it('registryContainsDefaultAndFiveUniquePresets', 0, () => {
      const themes: Array<BuiltInThemeDefinition> = ThemeRegistry.all();
      expect(themes.length).assertEqual(6);
      const seenIds: Array<string> = [];
      let presetCount: number = 0;
      for (let i = 0; i < themes.length; i++) {
        expect(seenIds.includes(themes[i].id)).assertFalse();
        seenIds.push(themes[i].id);
        expect(themes[i].focusX >= 0 && themes[i].focusX <= 1).assertTrue();
        expect(themes[i].focusY >= 0 && themes[i].focusY <= 1).assertTrue();
        if (themes[i].sourceType === ThemeSourceType.PRESET) {
          presetCount++;
          expect(themes[i].imageKey.length > 0).assertTrue();
          expect(themes[i].imageWidth > 0).assertTrue();
          expect(themes[i].imageHeight > 0).assertTrue();
        }
      }
      expect(presetCount).assertEqual(5);
    });

    it('allPresetPalettesMeetContrastThresholds', 0, () => {
      const themes: Array<BuiltInThemeDefinition> = ThemeRegistry.all();
      for (let i = 1; i < themes.length; i++) {
        verifyPaletteContrast(themes[i].id + ':light', themes[i].lightPalette);
        verifyPaletteContrast(themes[i].id + ':dark', themes[i].darkPalette);
      }
    });

    it('paletteGenerationIsDeterministicAndKeepsNeutralThemeNeutral', 0, () => {
      const first: ThemePalette =
        ThemePaletteFactory.create('#58585B', true, AppThemeMode.LIGHT, 0.08);
      const second: ThemePalette =
        ThemePaletteFactory.create('#58585B', true, AppThemeMode.LIGHT, 0.08);
      expect(first.primary).assertEqual(second.primary);
      expect(first.courseColors.join(',')).assertEqual(second.courseColors.join(','));
      expect(first.primary).assertEqual('#51515C');
    });

    it('previewCancelCommitRestartAndResetAreIsolated', 0, () => {
      clearThemeStore();
      const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext().createModuleContext('entry_test');
      const manager: ThemeManager = ThemeManager.createForTesting(moduleContext, TEST_STORE_NAME);
      expect(manager.savedThemeId()).assertEqual('classic_default');
      expect(manager.beginPreview('sakura_pink')).assertTrue();
      expect(manager.currentThemeId()).assertEqual('sakura_pink');
      manager.cancelPreview();
      expect(manager.currentThemeId()).assertEqual('classic_default');

      expect(manager.beginPreview('amber_energy')).assertTrue();
      expect(manager.commitPreview()).assertTrue();
      expect(manager.savedThemeId()).assertEqual('amber_energy');

      const restarted: ThemeManager = ThemeManager.createForTesting(moduleContext, TEST_STORE_NAME);
      expect(restarted.savedThemeId()).assertEqual('amber_energy');
      expect(restarted.resetToDefault()).assertTrue();
      expect(restarted.savedThemeId()).assertEqual('classic_default');
      clearThemeStore();
    });

    it('unknownPersistedThemeFallsBackToClassicDefault', 0, () => {
      clearThemeStore();
      const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext().createModuleContext('entry_test');
      const store: preferences.Preferences =
        preferences.getPreferencesSync(moduleContext, { name: TEST_STORE_NAME });
      store.putSync('schema_version', 1);
      store.putSync('theme_source', ThemeSourceType.PRESET);
      store.putSync('theme_id', 'missing_theme');
      store.flushSync();
      const manager: ThemeManager = ThemeManager.createForTesting(moduleContext, TEST_STORE_NAME);
      expect(manager.savedThemeId()).assertEqual('classic_default');
      clearThemeStore();
    });

    it('customPhotoAnalysisIsDeterministicAndReadable', 0, () => {
      const colorful = CustomThemeProcessor.analyzeRgba(solidRgba(220, 70, 90, 8, 8), 8, 8);
      const repeated = CustomThemeProcessor.analyzeRgba(solidRgba(220, 70, 90, 8, 8), 8, 8);
      expect(colorful.seedColor).assertEqual(repeated.seedColor);
      expect(colorful.neutral).assertFalse();
      const light: ThemePalette =
        ThemePaletteFactory.create(colorful.seedColor, colorful.neutral, AppThemeMode.LIGHT, 0.2);
      const dark: ThemePalette =
        ThemePaletteFactory.create(colorful.seedColor, colorful.neutral, AppThemeMode.DARK, 0.52);
      verifyPaletteContrast('custom:light', light);
      verifyPaletteContrast('custom:dark', dark);

      const gray = CustomThemeProcessor.analyzeRgba(solidRgba(128, 128, 128, 8, 8), 8, 8);
      expect(gray.neutral).assertTrue();
    });

    it('customThemeRestoresOnlyWhenPrivateImageExists', 0, () => {
      clearThemeStore();
      const moduleContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext().createModuleContext('entry_test');
      const directory: string = moduleContext.filesDir + '/theme_assets';
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
      const imagePath: string = directory + '/test_custom_theme.jpg';
      const file = fileIo.openSync(
        imagePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(file.fd, new Uint8Array([255, 216, 255, 217]).buffer);
      fileIo.closeSync(file);

      const store: preferences.Preferences =
        preferences.getPreferencesSync(moduleContext, { name: TEST_STORE_NAME });
      store.putSync('schema_version', 2);
      store.putSync('theme_source', ThemeSourceType.CUSTOM);
      store.putSync('theme_id', 'custom_photo');
      store.putSync('custom_version', 1);
      store.putSync('custom_image_path', imagePath);
      store.putSync('custom_image_width', 1080);
      store.putSync('custom_image_height', 1920);
      store.putSync('custom_seed_color', '#A64D79');
      store.putSync('custom_neutral', false);
      store.putSync('custom_focus_x', 0.42);
      store.putSync('custom_focus_y', 0.61);
      store.putSync('custom_zoom_scale', 2.25);
      store.putSync('custom_light_scrim', 0.2);
      store.putSync('custom_dark_scrim', 0.52);
      store.flushSync();

      const restored: ThemeManager = ThemeManager.createForTesting(moduleContext, TEST_STORE_NAME);
      expect(restored.savedThemeId()).assertEqual('custom_photo');
      expect(restored.hasCustomTheme()).assertTrue();
      expect(restored.currentDefinition().focusX).assertEqual(0.42);
      expect(restored.currentZoomScale()).assertEqual(2.25);
      fileIo.unlinkSync(imagePath);

      const missing: ThemeManager = ThemeManager.createForTesting(moduleContext, TEST_STORE_NAME);
      expect(missing.savedThemeId()).assertEqual('classic_default');
      clearThemeStore();
    });
  });
}
