import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { ThemeRegistry } from '../../../main/ets/common/ThemeRegistry';
import {
  AppThemeMode,
  BuiltInThemeDefinition,
  ThemePalette,
  ThemePaletteFactory,
  ThemeSourceType
} from '../../../main/ets/common/ThemeModels';
import { ThemeManager } from '../../../main/ets/manager/ThemeManager';

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
  });
}
