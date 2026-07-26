import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
  }

  onRun(): void {
    const argumentsInfo: abilityDelegatorRegistry.AbilityDelegatorArgs =
      abilityDelegatorRegistry.getArguments();
    const want: Want = {
      bundleName: argumentsInfo.bundleName,
      moduleName: argumentsInfo.parameters['-m'],
      abilityName: 'TestAbility'
    };
    abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);
  }
}
