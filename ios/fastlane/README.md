# TestFlight Upload

## 1) Prepare env vars

```bash
cd ios/fastlane
cp .env.example .env
```

Fill in:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT` (Base64 of `AuthKey_XXXX.p8`)

## 2) Run upload

```bash
cd ios
bundle exec fastlane beta
```

Or from project root (shorter):

```bash
make tf
```

Or pass version on demand:

```bash
bundle exec fastlane beta build_name:1.0.1 build_number:12 changelog:"修复已知问题"
```

Root shortcut with params:

```bash
make tf BUILD_NAME=1.0.1 BUILD_NUMBER=12 NOTE="修复已知问题"
```
