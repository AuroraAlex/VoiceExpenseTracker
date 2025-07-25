# 语音记账应用 (Voice Expense Tracker)

一个基于 Flutter 开发的智能语音记账应用，支持语音识别和 AI 智能解析，让记账变得更加简单高效。

## ✨ 主要功能

- 🎤 **语音记账** - 支持中文语音识别，说话即可记账
- 🤖 **AI 智能解析** - 自动识别金额、类别和描述信息
- 📊 **数据统计** - 支持按日期、类别查看支出统计
- 🚗 **车辆管理** - 专门的车辆相关支出管理
- ☁️ **数据同步** - 支持 WebDAV 云端数据同步
- 🎨 **美观界面** - Material Design 3 设计风格

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK (用于 Android 构建)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/AuroraAlex/VoiceExpenseTracker.git
   cd VoiceExpenseTracker
   ```

2. **配置环境变量**
   ```bash
   # 复制环境变量模板文件
   cp .env_temp .env
   
   # 编辑 .env 文件，填入您的配置信息
   nano .env
   ```

3. **安装依赖**
   ```bash
   flutter pub get
   ```

4. **运行应用**
   ```bash
   flutter run
   ```

## ⚙️ 配置说明

### 环境变量配置 (.env)

应用需要配置以下环境变量，请将 `.env_temp` 重命名为 `.env` 并填入实际值：

```env
# AI 服务配置
AI_SERVICE_TYPE=openai
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-3.5-turbo

# WebDAV 同步配置（可选）
WEBDAV_URL=your_webdav_server_url
WEBDAV_USERNAME=your_username
WEBDAV_PASSWORD=your_password
```

### Android 权限

应用需要以下 Android 权限：
- `RECORD_AUDIO` - 语音识别
- `INTERNET` - 网络访问
- `MICROPHONE` - 麦克风访问

## 🎯 使用方法

### 语音记账

1. 点击主界面的红色麦克风按钮
2. 对着手机说出记账内容，例如：
   - "今天买了一杯咖啡花了25元"
   - "加油费用200块钱"
   - "午餐花了35元"
3. 语音识别完成后，可以长按文字进行编辑
4. 点击"确认记账"完成添加

### AI 智能解析

应用会自动解析语音内容中的：
- **金额** - 自动提取数字金额
- **类别** - 智能判断支出类别（餐饮、交通、购物等）
- **描述** - 生成简洁的支出描述

### 数据管理

- **查看统计** - 在统计页面查看支出趋势
- **车辆管理** - 专门管理车辆相关支出
- **数据同步** - 配置 WebDAV 实现多设备同步

## 🛠️ 技术架构

### 核心技术栈

- **Flutter** - 跨平台 UI 框架
- **GetX** - 状态管理和路由
- **SQLite** - 本地数据存储
- **speech_to_text** - 语音识别
- **OpenAI API** - AI 智能解析

### 项目结构

```
lib/
├── models/          # 数据模型
├── services/        # 业务服务
├── ui/
│   ├── screens/     # 页面
│   └── widgets/     # 组件
└── main.dart        # 应用入口
```

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📝 更新日志

### v1.0.0
- ✅ 基础语音记账功能
- ✅ AI 智能解析
- ✅ 数据统计和管理
- ✅ WebDAV 云端同步
- ✅ 车辆支出管理

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- Flutter 团队提供的优秀框架
- OpenAI 提供的 AI 服务
- 所有开源库的贡献者们

---

如果这个项目对您有帮助，请给个 ⭐️ Star 支持一下！