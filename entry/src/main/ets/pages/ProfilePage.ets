import { ProfileField, StudentProfile } from '../model/CampusInfo';
import { CourseDataStore } from '../store/CourseDataStore';
import { Theme } from '../common/Theme';

@Entry({ routeName: 'ProfilePage' })
@Component
struct ProfilePage {
  @State profile: StudentProfile = new StudentProfile();
  private dataStore: CourseDataStore = CourseDataStore.getInstance();

  aboutToAppear(): void {
    this.profile = this.dataStore.loadProfile();
  }

  build() {
    Column() {
      this.TopBar()
      if (!this.profile.hasData()) {
        this.EmptyView()
      } else {
        Scroll() {
          Column() {
            this.SummaryCard()
            this.FieldGroup('基本信息', ['姓名', '学院', '院系', '专业', '班级', '年级', '入学'])
            this.FieldGroup('学籍培养', ['培养', '学籍', '学历', '层次', '毕业', '学习形式'])
            Text('信息来自学校官方页面，仅保存在本机')
              .fontSize(11)
              .fontColor(Theme.textDisabled())
              .margin({ top: 12, bottom: 32 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background())
  }

  @Builder
  TopBar(): void {
    Row() {
      Button('返回')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .fontColor(Theme.primary())
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Text('个人与培养信息')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.textPrimary())
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row() {}.width(60)
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Theme.topBackground())
  }

  @Builder
  EmptyView(): void {
    Column() {
      Text('暂无个人与培养信息').fontSize(18).fontColor(Theme.textPrimary())
      Text('同步后可离线查看学校官方学籍信息')
        .fontSize(13).fontColor(Theme.textSecondary()).margin({ top: 8 })
      Button('去同步')
        .fontSize(15).height(42).backgroundColor(Theme.primary()).margin({ top: 20 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/MisWebPage',
            params: { 'mode': 'sync', 'target': 'profile' }
          });
        })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SummaryCard(): void {
    Column() {
      Text(this.profile.studentName.length > 0 ? this.profile.studentName : '学生信息')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.textPrimary())
      if (this.profile.major.length > 0) {
        Text(this.profile.major).fontSize(14).fontColor(Theme.primary()).margin({ top: 6 })
      }
      if (this.profile.college.length > 0) {
        Text(this.profile.college).fontSize(13).fontColor(Theme.textSecondary()).margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(18)
    .margin({ top: 12, bottom: 12 })
    .borderRadius(14)
    .backgroundColor(Theme.surface())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FieldGroup(title: string, keywords: Array<string>): void {
    if (this.fieldsFor(keywords).length > 0) {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.textPrimary())
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })
        ForEach(this.fieldsFor(keywords), (field: ProfileField) => {
          Row() {
            Text(field.label).fontSize(13).fontColor(Theme.textSecondary()).width(112)
            Text(field.value).fontSize(13).fontColor(Theme.textPrimary()).layoutWeight(1)
          }.width('100%').padding({ top: 7, bottom: 7 })
        }, (field: ProfileField, index: number): string => title + '_' + field.label + '_' + index)
      }
      .width('100%')
      .padding(16)
      .margin({ bottom: 12 })
      .borderRadius(12)
      .backgroundColor(Theme.surface())
    }
  }

  private fieldsFor(keywords: Array<string>): Array<ProfileField> {
    const result: Array<ProfileField> = [];
    for (let i = 0; i < this.profile.fields.length; i++) {
      const field: ProfileField = this.profile.fields[i];
      if (keywords.find((keyword: string): boolean =>
        field.label.includes(keyword) || field.group.includes(keyword)) !== undefined) {
        if (result.find((item: ProfileField): boolean =>
          item.label === field.label && item.value === field.value) === undefined) {
          result.push(field);
        }
      }
    }
    return result;
  }
}
