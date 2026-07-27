import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import {
  CustomThemeProfile,
  ThemeColorAnalysis
} from '../common/ThemeModels';

const MAX_SOURCE_BYTES: number = 50 * 1024 * 1024;
const MAX_SOURCE_PIXELS: number = 50 * 1000 * 1000;
const MAX_OUTPUT_EDGE: number = 2160;
const ANALYSIS_EDGE: number = 96;
const THEME_DIRECTORY: string = 'theme_assets';

export class CustomThemeProcessor {
  static async prepare(uri: string, filesDir: string): Promise<CustomThemeProfile> {
    if (uri.length === 0) {
      throw new Error('未选择照片');
    }
    const directory: string = CustomThemeProcessor.themeDirectory(filesDir);
    CustomThemeProcessor.ensureDirectory(directory);
    const timestamp: string = Date.now().toString();
    const tempPath: string = directory + '/custom_theme_' + timestamp + '.preview.jpg';
    const sourceCopyPath: string = directory + '/custom_theme_' + timestamp + '.source';
    let sourceFile: fileIo.File | undefined = undefined;
    let privateSourceFile: fileIo.File | undefined = undefined;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      sourceFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const sourceBytes: number = fileIo.statSync(sourceFile.fd).size;
      if (sourceBytes <= 0 || sourceBytes > MAX_SOURCE_BYTES) {
        throw new Error('照片大小必须在 50 MB 以内');
      }
      fileIo.copyFileSync(sourceFile.fd, sourceCopyPath);
      privateSourceFile = fileIo.openSync(sourceCopyPath, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(privateSourceFile.fd);
      if (source === undefined) {
        throw new Error('无法解码这张照片，请更换常见格式后重试');
      }
      const sourceInfo: image.ImageInfo = await source.getImageInfo();
      const width: number = sourceInfo.size.width;
      const height: number = sourceInfo.size.height;
      if (width <= 0 || height <= 0 || width * height > MAX_SOURCE_PIXELS) {
        throw new Error('照片像素不能超过 5000 万');
      }
      const outputSize: image.Size = CustomThemeProcessor.scaledSize(width, height, MAX_OUTPUT_EDGE);
      pixelMap = await source.createPixelMap({
        desiredSize: outputSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      packer = image.createImagePacker();
      const packed: ArrayBuffer = await packer.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: 88
      });
      const outputFile: fileIo.File = fileIo.openSync(
        tempPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      try {
        const written: number = fileIo.writeSync(outputFile.fd, packed);
        if (written !== packed.byteLength) {
          throw new Error('照片写入不完整');
        }
      } finally {
        fileIo.closeSync(outputFile);
      }
      const analysis: ThemeColorAnalysis = await CustomThemeProcessor.analyzeFile(tempPath);
      return new CustomThemeProfile(
        tempPath,
        outputSize.width,
        outputSize.height,
        analysis.seedColor,
        analysis.neutral,
        0.5,
        0.5,
        analysis.luminance > 0.68 ? 0.24 : 0.18,
        analysis.luminance < 0.24 ? 0.42 : 0.52,
        true
      );
    } catch (error) {
      CustomThemeProcessor.deleteFile(tempPath);
      const message: string = error instanceof Error ? error.message : '照片处理失败';
      throw new Error(message);
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (_) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_) {
        }
      }
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_) {
        }
      }
      if (sourceFile !== undefined) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (_) {
        }
      }
      if (privateSourceFile !== undefined) {
        try {
          fileIo.closeSync(privateSourceFile);
        } catch (_) {
        }
      }
      CustomThemeProcessor.deleteFile(sourceCopyPath);
    }
  }

  static commitDraft(profile: CustomThemeProfile, filesDir: string): CustomThemeProfile {
    if (!profile.temporary || !CustomThemeProcessor.isManagedPath(profile.imagePath, filesDir)) {
      throw new Error('自定义主题草稿无效');
    }
    const finalPath: string =
      CustomThemeProcessor.themeDirectory(filesDir) + '/custom_theme_' + Date.now().toString() + '.jpg';
    fileIo.renameSync(profile.imagePath, finalPath);
    return new CustomThemeProfile(
      finalPath,
      profile.imageWidth,
      profile.imageHeight,
      profile.seedColor,
      profile.neutral,
      profile.focusX,
      profile.focusY,
      profile.lightScrimOpacity,
      profile.darkScrimOpacity,
      false,
      profile.zoomScale
    );
  }

  static imageUri(path: string): string {
    return path.length === 0 ? '' : fileUri.getUriFromPath(path);
  }

  static isManagedPath(path: string, filesDir: string): boolean {
    return path.startsWith(CustomThemeProcessor.themeDirectory(filesDir) + '/');
  }

  static fileExists(path: string): boolean {
    return path.length > 0 && fileIo.accessSync(path);
  }

  static deleteFile(path: string): void {
    if (path.length === 0 || !fileIo.accessSync(path)) {
      return;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (_) {
    }
  }

  static analyzeRgba(buffer: ArrayBuffer, width: number, height: number): ThemeColorAnalysis {
    if (width <= 0 || height <= 0 || buffer.byteLength < width * height * 4) {
      return new ThemeColorAnalysis('#245A78', false, 0.5);
    }
    const bytes: Uint8Array = new Uint8Array(buffer);
    const binWeights: Array<number> = [];
    const redSums: Array<number> = [];
    const greenSums: Array<number> = [];
    const blueSums: Array<number> = [];
    for (let i = 0; i < 24; i++) {
      binWeights.push(0);
      redSums.push(0);
      greenSums.push(0);
      blueSums.push(0);
    }
    let validWeight: number = 0;
    let chromaticWeight: number = 0;
    let luminanceSum: number = 0;
    let luminanceWeight: number = 0;
    let grayRed: number = 0;
    let grayGreen: number = 0;
    let grayBlue: number = 0;

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const offset: number = (y * width + x) * 4;
        const alpha: number = bytes[offset + 3];
        if (alpha < 128) {
          continue;
        }
        const red: number = bytes[offset];
        const green: number = bytes[offset + 1];
        const blue: number = bytes[offset + 2];
        const maximum: number = Math.max(red, green, blue) / 255;
        const minimum: number = Math.min(red, green, blue) / 255;
        const lightness: number = (maximum + minimum) / 2;
        if (lightness < 0.04 || lightness > 0.96) {
          continue;
        }
        const delta: number = maximum - minimum;
        const saturation: number =
          delta === 0 ? 0 : delta / (1 - Math.abs(2 * lightness - 1));
        const normalizedX: number = width <= 1 ? 0.5 : x / (width - 1);
        const normalizedY: number = height <= 1 ? 0.5 : y / (height - 1);
        const centerDistance: number =
          Math.sqrt(Math.pow(normalizedX - 0.5, 2) + Math.pow(normalizedY - 0.5, 2));
        const centerWeight: number = Math.max(0.78, 1.16 - centerDistance * 0.5);
        validWeight += centerWeight;
        luminanceSum += lightness * centerWeight;
        luminanceWeight += centerWeight;
        grayRed += red * centerWeight;
        grayGreen += green * centerWeight;
        grayBlue += blue * centerWeight;
        if (saturation < 0.10) {
          continue;
        }
        const hue: number = CustomThemeProcessor.rgbHue(red, green, blue);
        const bin: number = Math.min(23, Math.floor(hue / 15));
        const weight: number = centerWeight * (0.35 + saturation * 1.65);
        binWeights[bin] += weight;
        redSums[bin] += red * weight;
        greenSums[bin] += green * weight;
        blueSums[bin] += blue * weight;
        chromaticWeight += weight;
      }
    }
    if (validWeight <= 0 || luminanceWeight <= 0) {
      return new ThemeColorAnalysis('#245A78', false, 0.5);
    }
    const luminance: number = luminanceSum / luminanceWeight;
    let winningBin: number = 0;
    for (let i = 1; i < binWeights.length; i++) {
      if (binWeights[i] > binWeights[winningBin]) {
        winningBin = i;
      }
    }
    const unstableColor: boolean =
      chromaticWeight < validWeight * 0.18 || binWeights[winningBin] < chromaticWeight * 0.16;
    if (unstableColor || binWeights[winningBin] <= 0) {
      return new ThemeColorAnalysis(
        CustomThemeProcessor.rgbHex(
          CustomThemeProcessor.clamp(grayRed / validWeight, 64, 184),
          CustomThemeProcessor.clamp(grayGreen / validWeight, 64, 184),
          CustomThemeProcessor.clamp(grayBlue / validWeight, 64, 184)
        ),
        true,
        luminance
      );
    }
    return new ThemeColorAnalysis(
      CustomThemeProcessor.rgbHex(
        redSums[winningBin] / binWeights[winningBin],
        greenSums[winningBin] / binWeights[winningBin],
        blueSums[winningBin] / binWeights[winningBin]
      ),
      false,
      luminance
    );
  }

  private static async analyzeFile(path: string): Promise<ThemeColorAnalysis> {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    const source: image.ImageSource = image.createImageSource(file.fd);
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      if (source === undefined) {
        throw new Error('无法分析照片颜色');
      }
      const info: image.ImageInfo = await source.getImageInfo();
      const analysisSize: image.Size =
        CustomThemeProcessor.scaledSize(info.size.width, info.size.height, ANALYSIS_EDGE);
      pixelMap = await source.createPixelMap({
        desiredSize: analysisSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const pixelInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const buffer: ArrayBuffer =
        new ArrayBuffer(pixelInfo.size.width * pixelInfo.size.height * 4);
      await pixelMap.readPixelsToBuffer(buffer);
      return CustomThemeProcessor.analyzeRgba(buffer, pixelInfo.size.width, pixelInfo.size.height);
    } finally {
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_) {
        }
      }
      try {
        await source.release();
      } catch (_) {
      }
      try {
        fileIo.closeSync(file);
      } catch (_) {
      }
    }
  }

  private static scaledSize(width: number, height: number, longestEdge: number): image.Size {
    const scale: number = Math.min(1, longestEdge / Math.max(width, height));
    return {
      width: Math.max(1, Math.round(width * scale)),
      height: Math.max(1, Math.round(height * scale))
    };
  }

  private static themeDirectory(filesDir: string): string {
    return filesDir + '/' + THEME_DIRECTORY;
  }

  private static ensureDirectory(path: string): void {
    if (!fileIo.accessSync(path)) {
      fileIo.mkdirSync(path, true);
    }
  }

  private static rgbHue(redValue: number, greenValue: number, blueValue: number): number {
    const red: number = redValue / 255;
    const green: number = greenValue / 255;
    const blue: number = blueValue / 255;
    const maximum: number = Math.max(red, green, blue);
    const minimum: number = Math.min(red, green, blue);
    const delta: number = maximum - minimum;
    if (delta === 0) {
      return 0;
    }
    let hue: number = 0;
    if (maximum === red) {
      hue = 60 * (((green - blue) / delta) % 6);
    } else if (maximum === green) {
      hue = 60 * ((blue - red) / delta + 2);
    } else {
      hue = 60 * ((red - green) / delta + 4);
    }
    return hue < 0 ? hue + 360 : hue;
  }

  private static rgbHex(red: number, green: number, blue: number): string {
    return '#' + CustomThemeProcessor.channelHex(red) +
      CustomThemeProcessor.channelHex(green) + CustomThemeProcessor.channelHex(blue);
  }

  private static channelHex(value: number): string {
    const text: string =
      Math.round(CustomThemeProcessor.clamp(value, 0, 255)).toString(16).toUpperCase();
    return text.length === 1 ? '0' + text : text;
  }

  private static clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }
}
