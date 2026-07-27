import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction } from '@kit.ArkUI';
import {
  AppThemeMode,
  MAX_CUSTOM_THEME_ZOOM,
  MIN_CUSTOM_THEME_ZOOM
} from '../common/ThemeModels';
import { Theme } from '../common/Theme';
import { ThemeContentBoundary, ThemedBackground } from '../components/ThemedBackground';
import { ThemeManager } from '../manager/ThemeManager';

@Entry({ routeName: 'CustomThemePage' })
@Component
struct CustomThemePage {
  @State hasPhoto: boolean = false;
  @State isProcessing: boolean = false;
  @State previewMode: AppThemeMode = AppThemeMode.LIGHT;
  @State focusX: number = 0.5;
  @State focusY: number = 0.5;
  @State zoomScale: number = MIN_CUSTOM_THEME_ZOOM;
  @State previewWidth: number = 0;
  @State previewHeight: number = 0;
  private dragStartFocusX: number = 0.5;
  private dragStartFocusY: number = 0.5;
  private pinchStartFocusX: number = 0.5;
  private pinchStartFocusY: number = 0.5;
  private pinchStartZoomScale: number = MIN_CUSTOM_THEME_ZOOM;
  private themeManager: ThemeManager = ThemeManager.getInstance();

  aboutToAppear(): void {
    this.previewMode = this.themeManager.isDarkMode() ? AppThemeMode.DARK : AppThemeMode.LIGHT;
    this.hasPhoto = this.themeManager.beginCustomPreview();
    if (this.hasPhoto) {
      this.syncFocus();
      this.themeManager.setPreviewMode(this.previewMode);
    }
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
              Text('从系统相册选择一张照片。应用会等比铺满背景，并从照片中提取主色生成按钮、卡片和课表配色。')
                .fontSize(13)
                .fontColor(Theme.textSecondary())
                .width('100%')
                .padding(14)
                .borderRadius(14)
                .backgroundColor(Theme.surface())
                .backgroundBlurStyle(Theme.blurStyle())
                .margin({ top: 14, bottom: 14 })
              if (this.hasPhoto) {
                this.WallpaperPreview()
                this.PreviewModeSelector()
              } else {
                this.EmptyPhoto()
              }
              Button(this.hasPhoto ? '更换照片' : '选择照片')
                .width('100%')
                .height(46)
                .fontSize(15)
                .fontColor(Theme.textPrimary())
                .backgroundColor(Theme.card())
                .border({ width: 1, color: Theme.border() })
                .borderRadius(14)
                .margin({ top: 14 })
                .enabled(!this.isProcessing)
                .onClick(() => {
                  this.selectPhoto();
                })
              if (this.hasPhoto) {
                Button('应用此背景')
                  .width('100%')
                  .height(48)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.onPrimary())
                  .backgroundColor(Theme.primary())
                  .borderRadius(14)
                  .margin({ top: 12, bottom: 32 })
                  .enabled(!this.isProcessing)
                  .onClick(() => {
                    this.applyPhoto();
                  })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
      if (this.isProcessing) {
        Column() {
          LoadingProgress()
            .width(42)
            .height(42)
            .color(Theme.primary())
          Text('正在处理照片并生成主题…')
            .fontSize(14)
            .fontColor(Theme.textPrimary())
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.surface())
      }
    }
    .width('100%')
    .height('100%')
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
      Text('自定义照片')
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
  private EmptyPhoto(): void {
    Column() {
      Text('＋')
        .fontSize(42)
        .fontColor(Theme.primary())
      Text('选择照片后可预览背景效果')
        .fontSize(14)
        .fontColor(Theme.textSecondary())
        .margin({ top: 10 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(360)
    .borderRadius(20)
    .backgroundColor(Theme.card())
    .border({ width: 1, color: Theme.border() })
  }

  @Builder
  private WallpaperPreview(): void {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(Theme.backgroundImage())
          .width(this.coveredImageWidth())
          .height(this.coveredImageHeight())
          .objectFit(ImageFit.Fill)
          .position({ x: this.coveredImageX(), y: this.coveredImageY() })
          .draggable(false)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.backgroundOverlay())
          .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height(430)
      .clip(true)
      .borderRadius(22)
      .border({ width: 1, color: Theme.border() })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.previewWidth = this.toNumber(newArea.width);
        this.previewHeight = this.toNumber(newArea.height);
      })
      .gesture(
        GestureGroup(
          GestureMode.Parallel,
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
            .onActionStart(() => {
              this.dragStartFocusX = this.focusX;
              this.dragStartFocusY = this.focusY;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.updateFocusFromDrag(event.offsetX, event.offsetY);
            })
            .onActionEnd(() => {
              this.persistCurrentTransform();
            }),
          PinchGesture({ fingers: 2, distance: 3 })
            .onActionStart(() => {
              this.pinchStartFocusX = this.focusX;
              this.pinchStartFocusY = this.focusY;
              this.pinchStartZoomScale = this.zoomScale;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.updateZoomFromPinch(event);
            })
            .onActionEnd(() => {
              this.persistCurrentTransform();
            })
            .onActionCancel(() => {
              this.persistCurrentTransform();
            })
        )
      )
      Row() {
        Button('重置')
          .fontSize(13)
          .fontColor(Theme.primary())
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.focusX = 0.5;
            this.focusY = 0.5;
            this.zoomScale = MIN_CUSTOM_THEME_ZOOM;
            this.persistCurrentTransform();
          })
        Blank()
        Text('双指缩放 · 单指拖动 · ' + this.zoomPercentage())
          .fontSize(11)
          .fontColor(Theme.textSecondary())
      }
      .width('100%')
      .height(40)
      Column() {
        Text('双指缩放，单指拖动调整取景')
          .fontSize(12)
          .fontColor(Theme.textSecondary())
        Text('示例标题')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.textPrimary())
          .margin({ top: 8 })
        Button('主题按钮')
          .fontColor(Theme.onPrimary())
          .backgroundColor(Theme.primary())
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .borderRadius(16)
      .backgroundColor(Theme.card())
      .backgroundBlurStyle(Theme.blurStyle())
    }
    .width('100%')
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
    .margin({ top: 8 })
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

  private async selectPhoto(): Promise<void> {
    if (this.isProcessing) {
      return;
    }
    try {
      const options: photoAccessHelper.PhotoSelectOptions =
        new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      this.isProcessing = true;
      await this.themeManager.prepareCustomPhoto(result.photoUris[0]);
      this.hasPhoto = true;
      this.syncFocus();
      this.themeManager.setPreviewMode(this.previewMode);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '无法处理这张照片';
      promptAction.showToast({ message: message });
    } finally {
      this.isProcessing = false;
    }
  }

  private applyPhoto(): void {
    this.persistCurrentTransform();
    if (this.themeManager.commitPreview()) {
      promptAction.showToast({ message: '已应用自定义照片主题' });
      this.getUIContext().getRouter().back();
      return;
    }
    promptAction.showToast({ message: '主题保存失败，已恢复原主题' });
  }

  private syncFocus(): void {
    this.focusX = this.themeManager.currentDefinition().focusX;
    this.focusY = this.themeManager.currentDefinition().focusY;
    this.zoomScale = this.themeManager.currentZoomScale();
  }

  private updateFocusFromDrag(offsetX: number, offsetY: number): void {
    const overflowX: number = Math.max(this.coveredImageWidth() - this.previewWidth, 0);
    const overflowY: number = Math.max(this.coveredImageHeight() - this.previewHeight, 0);
    if (overflowX > 0) {
      this.focusX = this.clamp(this.dragStartFocusX - offsetX / overflowX, 0, 1);
    }
    if (overflowY > 0) {
      this.focusY = this.clamp(this.dragStartFocusY - offsetY / overflowY, 0, 1);
    }
  }

  private coverScale(): number {
    const imageWidth: number = Math.max(Theme.backgroundImageWidth(), 1);
    const imageHeight: number = Math.max(Theme.backgroundImageHeight(), 1);
    return Math.max(this.previewWidth / imageWidth, this.previewHeight / imageHeight) *
      this.zoomScale;
  }

  private coveredImageWidth(): number {
    return Theme.backgroundImageWidth() * this.coverScale();
  }

  private coveredImageHeight(): number {
    return Theme.backgroundImageHeight() * this.coverScale();
  }

  private coveredImageX(): number {
    return (this.previewWidth - this.coveredImageWidth()) * this.focusX;
  }

  private coveredImageY(): number {
    return (this.previewHeight - this.coveredImageHeight()) * this.focusY;
  }

  private updateZoomFromPinch(event: GestureEvent): void {
    const nextZoom: number = this.clamp(
      this.pinchStartZoomScale * event.scale,
      MIN_CUSTOM_THEME_ZOOM,
      MAX_CUSTOM_THEME_ZOOM
    );
    const baseWidth: number = this.baseCoveredImageWidth();
    const baseHeight: number = this.baseCoveredImageHeight();
    this.focusX = this.zoomedFocus(
      event.pinchCenterX,
      this.previewWidth,
      baseWidth,
      this.pinchStartZoomScale,
      nextZoom,
      this.pinchStartFocusX
    );
    this.focusY = this.zoomedFocus(
      event.pinchCenterY,
      this.previewHeight,
      baseHeight,
      this.pinchStartZoomScale,
      nextZoom,
      this.pinchStartFocusY
    );
    this.zoomScale = nextZoom;
  }

  private baseCoveredImageWidth(): number {
    return this.coveredImageWidth() / Math.max(this.zoomScale, MIN_CUSTOM_THEME_ZOOM);
  }

  private baseCoveredImageHeight(): number {
    return this.coveredImageHeight() / Math.max(this.zoomScale, MIN_CUSTOM_THEME_ZOOM);
  }

  private zoomedFocus(
    anchor: number,
    viewportSize: number,
    baseImageSize: number,
    oldZoom: number,
    newZoom: number,
    oldFocus: number
  ): number {
    const oldImageSize: number = baseImageSize * oldZoom;
    const newImageSize: number = baseImageSize * newZoom;
    const safeAnchor: number = this.clamp(anchor, 0, viewportSize);
    const oldPosition: number = (viewportSize - oldImageSize) * oldFocus;
    const imagePoint: number = (safeAnchor - oldPosition) / Math.max(oldImageSize, 1);
    const newPosition: number = safeAnchor - imagePoint * newImageSize;
    const availableOffset: number = viewportSize - newImageSize;
    if (Math.abs(availableOffset) < 0.001) {
      return oldFocus;
    }
    return this.clamp(newPosition / availableOffset, 0, 1);
  }

  private persistCurrentTransform(): void {
    this.themeManager.updateCustomDraftTransform(this.focusX, this.focusY, this.zoomScale);
  }

  private zoomPercentage(): string {
    return Math.round(this.zoomScale * 100).toString() + '%';
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private toNumber(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = parseFloat(value);
      return Number.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }
}
