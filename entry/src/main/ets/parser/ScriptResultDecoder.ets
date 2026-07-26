export class ScriptResultDecoder {
  static unwrap(result: string): string {
    const decoded: Object = JSON.parse(result) as Object;
    if (typeof decoded === 'string') {
      return decoded as string;
    }
    return result;
  }
}
