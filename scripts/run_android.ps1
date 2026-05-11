# 一键运行 Android（含友盟 Android Key，可与 dart-define 覆盖）
Set-Location $PSScriptRoot\..
flutter run -d android `
  --dart-define=UMENG_ANDROID_KEY=69da1f829a7f376488bdeb2d
