# CatCompanion Full 版打包说明

## 1) 生成 Release DMG
```bash
cd /Users/deebell/Documents/猫咪伴侣
scripts/build_dmg.sh --configuration Release --name CatCompanion
```

输出目录：`/Users/deebell/Documents/猫咪伴侣/dist`

## 2) 跳过构建直接打包（可选）
```bash
cd /Users/deebell/Documents/猫咪伴侣
scripts/build_dmg.sh \
  --skip-build \
  --configuration Release \
  --derived-data /Users/deebell/Documents/猫咪伴侣/.build/dmg-derived-data \
  --name CatCompanion
```

## 3) 说明
- 当前脚本产出可安装测试包（DMG），未包含 notarization 流程。
- 若用于外部分发，建议执行 `notarytool` 公证与 stapler。

## 4) DMG 公证（notarization）
先存储凭据（示例）：
```bash
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

然后执行：
```bash
cd /Users/deebell/Documents/猫咪伴侣
scripts/notarize_dmg.sh \
  --dmg /Users/deebell/Documents/猫咪伴侣/dist/CatCompanion-YYYYMMDD-HHMMSS.dmg \
  --keychain-profile AC_NOTARY
```
