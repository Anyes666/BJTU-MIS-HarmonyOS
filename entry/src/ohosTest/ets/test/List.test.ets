import parserTest from './Parser.test';
import storageTest from './Storage.test';
import securityTest from './Security.test';
import themeTest from './Theme.test';

export default function testsuite(): void {
  parserTest();
  storageTest();
  securityTest();
  themeTest();
}
