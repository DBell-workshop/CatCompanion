# CatCompanion 打包与分发

## 1) 生成 Release DMG（推荐）
```bash
cd /Users/deebell/Documents/猫咪伴侣
scripts/build_dmg.sh --configuration Release --name CatCompanion
```

输出目录：`dist/`

此命令会自动完成以下步骤：
1. 使用 xcodebuild 编译 Release 版 CatCompanion.app
2. 使用 swift build 编译 Release 版 CatCompanionAgent
3. 将 Agent 捆绑到 .app/Contents/Helpers/ 目录
4. 打包为 DMG 磁盘映像

## 2) 带代码签名的 DMG
```bash
scripts/build_dmg.sh \
  --configuration Release \
  --name CatCompanion \
  --sign "Developer ID Application: Your Name (TEAMID)"
```

代码签名顺序：先签 Agent，再签整个 .app bundle（`--deep --options runtime`）。

## 3) 跳过构建直接打包（可选）
```bash
scripts/build_dmg.sh \
  --skip-build \
  --configuration Release \
  --derived-data .build/dmg-derived-data \
  --name CatCompanion
```

注意：`--skip-build` 也会跳过 Agent 编译，需确保 `.build/release/CatCompanionAgent` 已存在。

## 4) DMG 公证（notarization）

### 前置：存储凭据
```bash
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

### 执行公证
```bash
scripts/notarize_dmg.sh \
  --dmg dist/CatCompanion-YYYYMMDD-HHMMSS.dmg \
  --keychain-profile AC_NOTARY
```

公证脚本会自动完成：提交 → 等待 → Staple → 验证。

## 5) 完整分发流程

```bash
# 1. 编译 + 签名 + 打包
scripts/build_dmg.sh \
  --configuration Release \
  --name CatCompanion \
  --sign "Developer ID Application: Your Name (TEAMID)"

# 2. 公证
scripts/notarize_dmg.sh \
  --dmg dist/CatCompanion-YYYYMMDD-HHMMSS.dmg \
  --keychain-profile AC_NOTARY
```

## 6) 注意事项
- Agent（CatCompanionAgent）是独立的 SPM target，不在 Xcode project 中
- `build_dmg.sh` 会自动使用 `swift build -c release` 编译 Agent
- 代码签名需要有效的 Developer ID 证书
- 公证需要 Apple Developer 账号和 app-specific password
- DMG 文件名包含时间戳，不会覆盖旧版本
