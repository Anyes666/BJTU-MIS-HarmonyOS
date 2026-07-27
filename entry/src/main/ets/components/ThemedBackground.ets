import { Theme } from '../common/Theme';

@Builder
function EmptyThemeContent(): void {
}

@Component
export struct ThemedBackground {
  @StorageLink('themeRevision') themeRevision: number = 0;
  @State containerWidth: number = 0;
  @State containerHeight: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach([this.themeRevision], (_revision: number) => {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.hasPhotoTheme()) {
            if (this.containerWidth > 0 && this.containerHeight > 0) {
              Image(Theme.backgroundImage())
                .width(this.coveredImageWidth())
                .height(this.coveredImageHeight())
                .objectFit(ImageFit.Fill)
                .position({ x: this.coveredImageX(), y: this.coveredImageY() })
                .draggable(false)
                .hitTestBehavior(HitTestMode.None)
            } else {
              Image(Theme.backgroundImage())
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .draggable(false)
                .hitTestBehavior(HitTestMode.None)
            }
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(Theme.backgroundOverlay())
              .hitTestBehavior(HitTestMode.None)
          } else {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.app_background'))
              .hitTestBehavior(HitTestMode.None)
          }
        }
        .width('100%')
        .height('100%')
      }, (revision: number): string => revision.toString())
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.containerWidth = this.toNumber(newArea.width);
      this.containerHeight = this.toNumber(newArea.height);
    })
  }

  private hasPhotoTheme(): boolean {
    return this.themeRevision >= 0 && Theme.isPhotoTheme();
  }

  private coverScale(): number {
    const imageWidth: number = Math.max(Theme.backgroundImageWidth(), 1);
    const imageHeight: number = Math.max(Theme.backgroundImageHeight(), 1);
    return Math.max(this.containerWidth / imageWidth, this.containerHeight / imageHeight);
  }

  private coveredImageWidth(): number {
    return Theme.backgroundImageWidth() * this.coverScale();
  }

  private coveredImageHeight(): number {
    return Theme.backgroundImageHeight() * this.coverScale();
  }

  private coveredImageX(): number {
    return (this.containerWidth - this.coveredImageWidth()) * Theme.focusX();
  }

  private coveredImageY(): number {
    return (this.containerHeight - this.coveredImageHeight()) * Theme.focusY();
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

@Component
export struct ThemeContentBoundary {
  @StorageLink('themeRevision') themeRevision: number = 0;
  @BuilderParam content: () => void = EmptyThemeContent;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach([this.themeRevision], (_revision: number) => {
        this.content();
      }, (revision: number): string => revision.toString())
    }
    .width('100%')
    .height('100%')
  }
}
