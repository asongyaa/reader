# Anx-Reader Fork 个人改造路线图
> 本文件为个人执行手册；Claude Code 请查看 `CLAUDE.md`

## 项目目标
基于 [Anxcye/anx-reader](https://github.com/Anxcye/anx-reader) Fork 定制**个人 Android 阅读器**
- **运行平台**：仅 Android(arm64-v8a)
- **分发方式**：不上架应用商店，仅对内分发 APK
- **运营规则**：无广告、纯个人使用、不商业化

### 保留功能
- 核心阅读（foliate-js + WebView 渲染）
- 书库管理
- 笔记 / 高亮标注
- WebDAV 数据同步
- 阅读样式自定义
- 阅读数据统计

### 移除功能
- 全量 AI 助手（OpenAI / Claude / Gemini / LangChain / DeepSeek）
- 内购、订阅付费模块
- 桌面端代码（Windows / macOS / Linux）
- 启动引导页
- 网络请求日志

### 新增功能
- 离线 TTS 引擎（sherpa-onnx + vits-melo-tts-zh_en）
- 保留系统 TTS 作为兜底方案
- 句子级朗读跟随高亮

### 视觉美化
- 遵循 Material 3 配色体系
- 集成优质中文字体（思源宋体 / 霞鹜文楷）
- 优化阅读页、书架页、设置页整体样式
- 接入 flutter_animate 实现微动效

## 已锁定关键决策
1. 基于 anx-reader **1.2.6 之后 Commit** 进行 Fork，规避 GPL-3.0 协议，保证项目为 MIT 协议
2. 仅维护 Android 端，不开发 iOS、桌面、Linux 版本
3. 坚持不上架、无广告、不商业化原则
4. 先抽象 TTS 通用接口，再做具体引擎实现替换
5. TTS 模型不内置进 APK，首次使用引导在线下载
6. 数据库结构保持不变，仅删除冗余业务代码，空数据表保留
7. 保留 WebDAV 同步（个人刚需）
8. **全程不额外扩张需求**，不再新增平台、功能及商业化模块

---

## Phase 0：环境跑通（Day 1-2）
**目标**：Android 真机正常安装启动，核心阅读流程可用

### 执行步骤
1. Fork 原仓库：`https://github.com/Anxcye/anx-reader`
2. 拉取代码并创建开发分支
```bash
git clone <你的Fork仓库地址>
cd anx-reader
git checkout -b my-fork
```
3. 安装项目依赖
```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```
4. 真机测试：导入 EPUB 书籍、翻页、原版 TTS 朗读功能验证
5. 提交基线版本
```bash
git commit -m "chore: baseline fork from upstream"
```

### 验收 Checkpoint 0
- [ ] Android 真机可正常安装、启动
- [ ] 支持导入 EPUB 并正常翻页阅读
- [ ] 原生 flutter_tts 朗读功能可用

### 常见问题
- Flutter 版本不匹配：使用 `pubspec.lock` 锁定的对应版本
- build_runner 执行卡顿：首次编译耗时 5-10 分钟属正常，耐心等待
- Git 依赖拉取失败：检查网络/代理（部分依赖源自作者私有仓库）
- Gradle 编译报错：根据日志升降级 Gradle、Kotlin 版本

---

## Phase 1：精简冗余模块（Week 1）
**目标**：删除无用代码与依赖，显著缩减 APK 体积

### 新建分支
```bash
git checkout -b feature/strip-down
```

### 待删除业务代码
1. `lib/page/` 目录
   - AI 相关页面（关键词：`ai_`、`chat`）
   - 内购订阅页面（关键词：`purchase`、`subscription`、`pro`）
   - 启动引导页（关键词：`introduction`、`onboarding`）
2. `lib/service/` 目录
   - AI 服务（关键词：`ai_`、`langchain`、`gemini`、`openai`）
   - 内购服务（关键词：`purchase`）

### 待删除桌面端代码
- 完整删除 `windows/`、`macos/`、`linux/` 目录
- 移除代码中 `window_manager`、`screen_retriever`、`desktop_drop` 相关调用

### 强制保留内容
- `ios/` 目录（不编译，避免 Flutter 配置异常）
- WebDAV 同步模块（`lib/service/sync_*`）
- 笔记/高亮功能（`lib/dao/notes_*` 及对应页面）
- 阅读统计、EPUB 解析渲染、书架、设置全量核心代码

### 待移除依赖（pubspec.yaml）
```yaml
# AI 相关
langchain
langchain_anthropic
langchain_google
langchain_openai
langchain_core
flutter_gemini
gpt_markdown

# 内购相关
in_app_purchase
in_app_purchase_storekit
asn1lib

# 桌面端相关
window_manager
screen_retriever
desktop_drop

# 引导页
introduction_screen

# 网络日志
pretty_dio_logger
dio_intercept_to_curl
```

### 操作顺序
1. 先删除依赖，执行 `flutter pub get`，梳理编译报错文件
2. 根据 `flutter analyze` 报错，逐行清理冗余代码、注释无效引用
3. 删除空目录，清理无效路由
4. 重构设置页菜单，移除已删除功能的入口
5. 可选：后续清理 `.arb` 国际化残留 Key（不影响编译）

### 验收 Checkpoint 1
- [ ] `flutter analyze` 无报错
- [ ] `flutter run` 正常启动运行
- [ ] 核心阅读流程不受改动影响
- [ ] APK 体积优化至 30-35MB（原版约 50MB）
- [ ] 设置页无无效跳转入口

### 提交代码
```bash
git commit -m "feat: strip AI / purchase / desktop / onboarding modules"
```

---

## Phase 2：抽象 TTS 统一接口（Week 2 上半段）
**目标**：重构原有 TTS 逻辑，封装通用抽象接口，原有功能保持不变

### 新建分支
```bash
git checkout -b feature/tts-abstraction
```

### 执行步骤
1. 梳理原有 TTS 逻辑
   全局搜索 `flutter_tts`、`FlutterTts`、`tts`，理清：初始化逻辑、文本分句、WebView 高亮通信、播放进度回调、启停/暂停/恢复逻辑。

2. 定义 TTS 抽象接口
新建文件：`lib/service/tts/tts_engine.dart`
```dart
abstract class TtsEngine {
  String get name;
  bool get requiresModelDownload;

  Future init();
  Future speak(String text);
  Future stop();
  Future pause();
  Future resume();

  Stream get progressStream;

  Future<List> getVoices();
  Future setVoice(String voiceId);
  Future setSpeed(double rate);   // 语速范围：0.5 - 2.0
  Future setPitch(double pitch);

  Future dispose();
}

class TtsProgress {
  final int sentenceIndex;
  final int charStart;
  final int charEnd;
  final String currentText;

  TtsProgress({
    required this.sentenceIndex,
    required this.charStart,
    required this.charEnd,
    required this.currentText,
  });
}

class TtsVoice {
  final String id;
  final String name;
  final String language;
  final String gender;

  TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
  });
}
```

3. 实现系统 TTS 适配器
新建文件：`lib/service/tts/system_tts_engine.dart`，基于原有 `flutter_tts` 实现 `TtsEngine` 接口。

4. 全局改造调用方式
通过 Riverpod 统一注入引擎，隔离底层实现
```dart
final ttsEngineProvider = StateProvider((ref) {
  return SystemTtsEngine();
});
```

5. 全功能回归测试：朗读、暂停、恢复、停止、文字高亮、参数调节均正常。

### 验收 Checkpoint 2
- [ ] 所有 TTS 调用走新抽象接口，原有功能完全一致
- [ ] 除 `SystemTtsEngine` 内部外，业务代码无直接引入 `flutter_tts`
- [ ] 句子高亮、进度回调、语速/音调设置全部正常

### 提交代码
```bash
git commit -m "refactor: extract TtsEngine abstraction with SystemTtsEngine impl"
```

---

## Phase 3：接入离线 TTS（Week 2 下半段 - Week 3）
**目标**：基于 sherpa-onnx 实现离线 TTS 引擎，增加模型下载、句子级同步高亮

### 技术选型
- 核心库：`sherpa_onnx`（Apache 2.0 协议）
- TTS 模型：`vits-melo-tts-zh_en`（中英双语，约 160MB）
- 模型地址：https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
- 音频播放：复用现有 `audioplayers` + `audio_service`

### 新建分支
```bash
git checkout -b feature/sherpa-onnx
```

### 执行步骤
1. 独立 Demo 验证（优先操作）
   新建空白 Flutter 项目，验证 `sherpa_onnx` 依赖、模型加载、音频合成与播放，跑通后再集成进主项目。

2. 模型下载管理
   - 设置页新增「离线 TTS 模型管理」模块
   - 模型存储路径：`getApplicationSupportDirectory()/tts_models/`
   - 实现下载进度、文件校验、解压、模型删除功能

3. 实现 `SherpaOnnxTtsEngine`
   - `init()`：通过 Isolate 异步加载模型，避免主线程阻塞
   - `speak()`：文本分句 → 逐句合成音频 → 流式播放
   - `progressStream`：结合播放位置与句子边界，输出朗读进度

4. 文本分句工具
新建文件：`lib/service/tts/sentence_splitter.dart`
```dart
class SentenceSplitter {
  static List split(String text) {
    final regex = RegExp(r'(?<=[。!?.!?])\s*');
    return text.split(regex).where((s) => s.trim().isNotEmpty).toList();
  }
}
```
> 兼容引号、省略号、小数点、中英混合等特殊场景。

5. 句子级同步高亮
复用 foliate-js 标注 API，朗读当前句子实时高亮，切换句子同步更新。

6. 配套设置 UI
- 引擎选择：系统 TTS / 离线 TTS
- 音色、语速、音调调节
- 音频试听按钮

7. 引擎动态切换
```dart
final ttsEngineProvider = StateProvider((ref) {
  final type = ref.watch(ttsEngineTypeProvider);
  return switch (type) {
    TtsEngineType.system => SystemTtsEngine(),
    TtsEngineType.sherpaOnnx => SherpaOnnxTtsEngine(),
  };
});
```

8. 后台播放能力
复用项目原有 `audio_service`，支持后台播放、通知栏/锁屏控制。

### 验收 Checkpoint 3
- [ ] 模型下载、进度展示、校验、删除功能正常
- [ ] 离线 TTS 朗读稳定可用
- [ ] 句子高亮跟随延迟 < 200ms
- [ ] 暂停/恢复/停止逻辑正常
- [ ] 切换 TTS 引擎无需重启应用
- [ ] 后台播放、通知栏、锁屏控制可用

### 常见问题
- .so 动态库加载失败：参照 sherpa_onnx 官方文档配置
- APK 体积过大：仅打包 `arm64-v8a` 架构
- 模型加载缓慢：启用 Isolate 异步加载并展示进度
- 音频卡顿：采用流式合成 + 流式播放方案
- 分句异常：针对实际书籍文本迭代优化正则规则

### 提交代码
```bash
git commit -m "feat: add SherpaOnnxTtsEngine with model download flow"
git commit -m "feat: sentence-level highlight sync for TTS"
git commit -m "feat: TTS engine settings UI"
```

---

## Phase 4：视觉与交互优化（Week 3-4+）
**目标**：统一视觉风格、优化交互体验，达到自用舒适标准

### 新建分支
```bash
git checkout -b feature/ui-polish
```

### 优化优先级
1. 阅读页：菜单动画、翻页过渡、TTS 控制栏、进度条
2. 书架页：书籍封面布局、空状态、新增书籍入口
3. 设置页：卡片分组、图标统一、文字层级优化
4. 主题体系：Material 3 动态配色、深色模式(#121212)、护眼/纸张色系
5. 字体配置：思源宋体 / 霞鹜文楷
6. 微动效：基于 `flutter_animate` 实现按钮、页面切换动效

### 新增依赖
```yaml
flutter_animate: ^4.x.x
phosphor_flutter: ^2.x.x
```

### 设计节制原则
- 单页面每次只优化 3-5 个点，完成即止
- 风格优先「统一整洁」，不做过度视觉设计
- 全局统一圆角（12dp / 16dp 二选一）、阴影规则

### 验收 Checkpoint 4
- [ ] 整体交互、视觉使用舒适
- [ ] 无风格突兀页面
- [ ] 核心交互添加微动效
- [ ] 浅色/深色模式均完成适配优化

---

## Phase 5：正式打包分发（半天）
### 执行步骤
1. 生成 Release 签名密钥（多路径备份）
```bash
keytool -genkey -v -keystore release.keystore -alias my-fork \
-keyalg RSA -keysize 2048 -validity 10000
```
2. 配置 `android/key.properties`，并加入 `.gitignore` 避免提交密钥
3. 修改 `android/app/build.gradle`，启用 Release 签名配置
4. 仅编译 arm64-v8a 架构 Release 包
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```
5. 输出路径：`build/app/outputs/flutter-apk/`（最终体积 30-50MB）
6. 编写简易说明文档：安装步骤、模型下载指引、WebDAV 推荐（坚果云）
7. 分发方式：微信传 APK / GitHub Releases / 静态站点托管

---

## Phase 6：长期维护（持续）
- 定期同步上游源码：每月检查原仓库重要更新，按需合并
- Bug 修复：自用过程中发现问题即时修复
- 需求迭代：仅采纳亲友合理反馈，**不新增规划外功能**

### 同步上游代码命令
```bash
git remote add upstream https://github.com/Anxcye/anx-reader.git
git fetch upstream
git merge upstream/develop
```

---

## 整体时间规划
| 阶段 | 核心任务 | 预估工时 | 累计周期 |
| ---- | -------- | -------- | -------- |
| Phase 0 | 环境跑通、基线搭建 | 1-2 天 | 2 天 |
| Phase 1 | 精简冗余模块 | 3-5 天 | 1 周 |
| Phase 2 | TTS 接口抽象重构 | 2-3 天 | 1.5 周 |
| Phase 3 | 接入离线 TTS | 5-7 天 | 2.5 周 |
| Phase 4 | UI 样式&交互优化 | 5-7 天 | 3.5 周 |
| Phase 5 | 打包&分发 | 0.5 天 | 4 周 |

> 业余时间开发，整体 4-6 周可完成 1.0 正式版

---

## 阶段止损预案（任意阶段可终止）
- 停在 Phase 1：纯精简版安卓阅读器，满足基础自用
- 停在 Phase 2：完成 TTS 架构重构，技术沉淀可用
- 停在 Phase 3：实现核心目标——离线 TTS 阅读器
- 停在 Phase 4：完整成品，视觉交互全部优化
- 全程未完成：退回使用原版项目，无任何损失

> 任意节点终止，项目均具备使用价值。