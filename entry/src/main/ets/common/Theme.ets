export class Theme {
  static background(): ResourceColor { return $r('app.color.app_background'); }
  static surface(): ResourceColor { return $r('app.color.app_surface'); }
  static card(): ResourceColor { return $r('app.color.app_card'); }
  static primary(): ResourceColor { return $r('app.color.app_primary'); }
  static onPrimary(): ResourceColor { return $r('app.color.app_on_primary'); }
  static primaryLight(): ResourceColor { return $r('app.color.app_primary_light'); }
  static secondary(): ResourceColor { return $r('app.color.app_secondary'); }
  static success(): ResourceColor { return $r('app.color.app_success'); }
  static warning(): ResourceColor { return $r('app.color.app_warning'); }
  static danger(): ResourceColor { return $r('app.color.app_danger'); }
  static dangerBackground(): ResourceColor { return $r('app.color.app_danger_background'); }
  static textPrimary(): ResourceColor { return $r('app.color.app_text_primary'); }
  static textSecondary(): ResourceColor { return $r('app.color.app_text_secondary'); }
  static textDisabled(): ResourceColor { return $r('app.color.app_text_disabled'); }
  static border(): ResourceColor { return $r('app.color.app_border'); }
  static tabBackground(): ResourceColor { return $r('app.color.app_tab_background'); }
  static topBackground(): ResourceColor { return $r('app.color.app_top_background'); }

  static course(courseType: string, seed: string = ''): ResourceColor {
    if (courseType.includes('必修')) { return $r('app.color.app_course_required'); }
    if (courseType.includes('选修') || courseType.includes('任选')) {
      return $r('app.color.app_course_elective');
    }
    if (courseType.includes('实验')) { return $r('app.color.app_course_lab'); }
    if (courseType.includes('体育')) { return $r('app.color.app_course_sport'); }
    let hash: number = 0;
    for (let i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
    }
    const paletteIndex: number = hash % 5;
    if (paletteIndex === 1) { return $r('app.color.app_course_required'); }
    if (paletteIndex === 2) { return $r('app.color.app_course_elective'); }
    if (paletteIndex === 3) { return $r('app.color.app_course_lab'); }
    if (paletteIndex === 4) { return $r('app.color.app_course_sport'); }
    return $r('app.color.app_course_default');
  }
}
