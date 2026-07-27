/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  AbilityConstant,
  Configuration,
  ConfigurationConstant,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { ThemeManager } from '../manager/ThemeManager';
import { Theme } from '../common/Theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    ThemeManager.getInstance().initialize(this.context, this.context.config.colorMode);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    ThemeManager.getInstance().setChangeListener(undefined);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.windowStage = windowStage;
    ThemeManager.getInstance().setChangeListener(() => {
      this.applySystemBars();
    });
    this.applySystemBars();

    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    this.windowStage = undefined;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    ThemeManager.getInstance().handleColorModeChange(newConfig.colorMode);
    this.applySystemBars();
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    try {
      webview.WebCookieManager.saveCookieSync();
    } catch (_) {
      hilog.warn(DOMAIN, 'testTag', 'ArkWeb session was not ready to persist.');
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  private applySystemBars(): void {
    if (this.windowStage === undefined) {
      return;
    }
    try {
      this.windowStage.getMainWindowSync().setWindowSystemBarProperties({
        statusBarColor: Theme.systemBarColor(),
        navigationBarColor: Theme.systemBarColor(),
        isStatusBarLightIcon: Theme.lightSystemIcons(),
        isNavigationBarLightIcon: Theme.lightSystemIcons()
      }).catch((err: Error) => {
        hilog.warn(DOMAIN, 'testTag', 'Failed to update system bars. Cause: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to access main window. Cause: %{public}s', JSON.stringify(err));
    }
  }
}
