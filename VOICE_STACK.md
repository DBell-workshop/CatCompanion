# CatCompanion 本地语音方案（离线 / 无 token）

## 目标
- 语音输入（STT）与语音播报（TTS）默认走本地，不依赖云端 token。
- 首期支持：中文普通话、英语、日语。

## 推荐栈
- STT：`whisper.cpp`（本地推理，Apple Silicon 可用）
- TTS：`CosyVoice`（优先 `CosyVoice2`）
- VAD（后续）：`silero-vad`

## 最小接入策略（当前仓库）
- 先用 `scripts/check_voice_stack.py` 做环境探测与安装提示。
- 应用层已接入本地语音链路：
  - 输入：`mic -> whisper.cpp -> text -> AI chat`
  - 输出：`assistant text -> CosyVoice -> speaker`
- 设置项中支持配置：
  - Whisper 命令（默认 `whisper-cli`）
  - Whisper 模型路径（必填）
  - Whisper 语言（默认 `auto`）
  - CosyVoice 模型 / 说话人 / 脚本路径

## 本地环境检查
```bash
python3 scripts/check_voice_stack.py --strict
```

## 参考安装命令（示例）
```bash
# 1) whisper.cpp（示例，按你的安装方式调整）
brew install whisper-cpp

# 2) CosyVoice 运行依赖（安装到当前 Python 环境）
pip install modelscope
pip install torch torchaudio

# 3) 可选：ffmpeg
brew install ffmpeg
```

## 说明
- 语音模型文件较大，建议在首次启动向导里提供“下载/校验/切换”。
- 对 MAS 版建议默认关闭语音录音与自动执行能力，避免审核风险。
- 当前仓库提供了 `scripts/cosyvoice_tts.py` 作为 App -> CosyVoice 的本地桥接脚本。
- 首次使用语音输入时，App 会申请麦克风权限（`NSMicrophoneUsageDescription`）。
