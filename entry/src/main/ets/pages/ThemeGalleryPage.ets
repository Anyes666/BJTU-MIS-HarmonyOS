import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { ThemeRegistry } from '../common/ThemeRegistry';
import { AppThemeMode, BuiltInThemeDefinition } from '../common/ThemeModels';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';
import { ThemeManager } from '../manager/ThemeManager';

@Entry({ routeName: 'ThemeGalleryPage' })
@Component
struct ThemeGalleryPage {
  @State selectedThemeId: string = '';
  @State previewMode: AppThemeMode = AppThemeMode.LIGHT;
  private themeManager: ThemeManager = ThemeManager.getInstance();

  aboutToAppear(): void {
    this.selectedThemeId = this.themeManager.savedThemeId();
    this.previewMode = this.themeManager.isDarkMode() ? AppThemeMode.DARK : AppThemeMode.LIGHT;
    this.themeManager.beginPreview(this.selectedThemeId);
    this.themeManager.setPreviewMode(this.previewMode);
  }

  aboutToDisappear(): void {
    if (this.themeManager.isPreviewing()) {
      this.themeManager.cancelPreview();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemedBackground()
      ThemeContentBoundary() {
        Column() {
          this.TopBar()
          Scroll() {
            Column() {
              this.PreviewModeSelector()
              Text('选择一套主题后可先预览，点击“应用主题”才会保存。')
                .fontSize(12)
                .fontColor(Theme.textSecondary())
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .borderRadius(12)
                .backgroundColor(Theme.surface())
                .backgroundBlurStyle(Theme.blurStyle())
                .margin({ top: 12, bottom: 12 })
              this.CustomThemeEntry()
              this.ThemeGrid()
              Button('应用主题')
                .width('100%')
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.onPrimary())
                .backgroundColor(Theme.primary())
                .borderRadius(14)
                .margin({ top: 18, bottom: 32 })
                .onClick(() => {
                  this.applyTheme();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.background())
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private CustomThemeEntry(): void {
    Row() {
      if (this.themeManager.hasCustomTheme()) {
        Image(this.themeManager.customImageUri())
          .width(78)
          .height(96)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
      } else {
        Text('＋')
          .width(78)
          .height(96)
          .fontSize(38)
          .fontColor(Theme.primary())
          .textAlign(TextAlign.Center)
          .borderRadius(12)
          .backgroundColor(Theme.surface())
      }
      Column() {
        Text('自定义照片')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary())
        Text(this.themeManager.hasCustomTheme() ? '更换照片或调整背景取景' : '从系统相册选择，自动提取主色')
          .fontSize(12)
          .fontColor(Theme.textSecondary())
          .margin({ top: 7 })
        if (this.selectedThemeId === 'custom_photo') {
          Text('当前主题')
            .fontSize(12)
            .fontColor(Theme.primary())
            .margin({ top: 7 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
      Text('›')
        .fontSize(26)
        .fontColor(Theme.textDisabled())
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor(Theme.card())
    .backgroundBlurStyle(Theme.blurStyle())
    .border({
      width: this.selectedThemeId === 'custom_photo' ? 2 : 1,
      color: this.selectedThemeId === 'custom_photo' ? Theme.primary() : Theme.border()
    })
    .margin({ bottom: 12 })
    .onClick(() => {
      this.themeManager.cancelPreview();
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CustomThemePage' });
    })
  }

  @Builder
  private TopBar(): void {
    Row() {
      Button('返回')
        .width(60)
        .height(42)
        .fontSize(14)
        .fontColor(Theme.primary())
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.themeManager.cancelPreview();
          this.getUIContext().getRouter().back();
        })
      Text('主题背景')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.textPrimary())
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row().width(60).height(42)
    }
    .width('100%')
    .height(54)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Theme.topBackground())
    .backgroundBlurStyle(Theme.blurStyle())
  }

  @Builder
  private PreviewModeSelector(): void {
    Row() {
      this.ModeButton('浅色预览', AppThemeMode.LIGHT)
      this.ModeButton('深色预览', AppThemeMode.DARK)
    }
    .width('100%')
    .height(46)
    .padding(4)
    .margin({ top: 14 })
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .backgroundBlurStyle(Theme.blurStyle())
  }

  @Builder
  private ModeButton(label: string, mode: AppThemeMode): void {
    Button(label)
      .layoutWeight(1)
      .height(38)
      .fontSize(14)
      .fontColor(this.previewMode === mode ? Theme.onPrimary() : Theme.textSecondary())
      .backgroundColor(this.previewMode === mode ? Theme.primary() : Color.Transparent)
      .borderRadius(11)
      .onClick(() => {
        this.previewMode = mode;
        this.themeManager.setPreviewMode(mode);
      })
  }

  @Builder
  private ThemeGrid(): void {
    Grid() {
      ForEach(ThemeRegistry.all(), (definition: BuiltInThemeDefinition) => {
        GridItem() {
          this.ThemeCard(definition)
        }
      }, (definition: BuiltInThemeDefinition): string => definition.id)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
  }

  @Builder
  private ThemeCard(definition: BuiltInThemeDefinition): void {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(ThemeRegistry.thumbnailResource(definition.id))
          .width('100%')
          .height(176)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: 13, topRight: 13 })
        if (this.selectedThemeId === definition.id) {
          Text('✓')
            .width(28)
            .height(28)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.onPrimary())
            .textAlign(TextAlign.Center)
            .borderRadius(14)
            .backgroundColor(Theme.primary())
            .margin(8)
        }
      }
      .width('100%')
      .height(176)
      Text(definition.displayName)
        .fontSize(14)
        .fontWeight(this.selectedThemeId === definition.id ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .height(42)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .borderRadius(14)
    .backgroundColor(Theme.card())
    .backgroundBlurStyle(Theme.blurStyle())
    .border({
      width: this.selectedThemeId === definition.id ? 2 : 1,
      color: this.selectedThemeId === definition.id ? Theme.primary() : Theme.border()
    })
    .onClick(() => {
      this.selectedThemeId = definition.id;
      this.themeManager.beginPreview(definition.id);
      this.themeManager.setPreviewMode(this.previewMode);
    })
  }

  private applyTheme(): void {
    if (this.themeManager.commitPreview()) {
      promptAction.showToast({ message: '已应用“' + Theme.activeThemeName() + '”' });
      this.selectedThemeId = this.themeManager.savedThemeId();
      return;
    }
    promptAction.showToast({ message: '主题保存失败，已恢复原主题' });
  }
}
