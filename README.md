# TradeLens (交易透镜)

一款专为 macOS 设计的合约交易复盘软件，帮助交易者系统化记录、分析和改进交易策略。

## 功能特性

### ✅ 核心功能（P1）

- **交易记录管理**
  - 快速录入交易信息（交易对、方向、价格、杠杆、盈亏等）
  - 交易列表展示，支持筛选和排序
  - 自动计算盈亏金额和盈亏率

- **复盘编辑器**
  - Markdown 格式编辑
  - 支持图片粘贴和拖拽
  - 支持链接嵌入
  - 自定义标签系统

- **资金曲线可视化**
  - 自动生成净值曲线图
  - 支持多时间维度查看（日/周/月/季度）
  - 关键指标展示（胜率、盈亏比、最大回撤等）

- **AI 智能复盘**
  - 基于 Gemini API 的智能分析
  - 近期交易总结
  - 策略改进建议
  - 支持指数退避重试机制

- **模板管理**
  - 预设模板（标准日内复盘、趋势跟踪复盘、大幅亏损分析）
  - 自定义模板创建和编辑
  - 支持变量替换（{{交易对}}、{{盈亏金额}}等）

### 🔄 计划功能（P2）

- 情绪/心理分析
- 一键生成复盘草稿
- 资金曲线与复盘联动
- 交易所 API 自动导入（Binance、OKX）

### 🚀 未来迭代（P3）

- iCloud 多设备同步
- 自定义交易指标
- 图表标注工具
- 社交分享功能

## 技术栈

- **UI**: SwiftUI
- **数据持久化**: Core Data
- **图表**: Swift Charts
- **AI 服务**: Google Gemini API
- **安全**: Keychain Services（API Key 存储）

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon (M 系列芯片) 或 Intel 处理器

## 安装与运行

1. 克隆仓库
```bash
git clone <repository-url>
cd TradeLens
```

2. 使用 Xcode 打开项目
```bash
open TradeLens.xcodeproj
```

3. 配置 API Key
   - 运行应用后，进入「设置」页面
   - 配置 Gemini API Key（可在 [Google AI Studio](https://makersuite.google.com/app/apikey) 获取）

4. 构建并运行
   - 在 Xcode 中选择目标设备
   - 按 `Cmd + R` 运行

## 项目结构

```
TradeLens/
├── App/                    # 应用入口
│   ├── TradeLensApp.swift
│   └── RootView.swift
├── Features/               # 功能模块
│   ├── TradeLog/          # 交易记录
│   ├── ReviewEditor/      # 复盘编辑器
│   ├── Capital/           # 资金曲线
│   ├── AIReview/          # AI 智能复盘
│   ├── Templates/         # 模板管理
│   └── Settings/          # 设置
├── Services/              # 服务层
│   ├── AI/                # AI 服务
│   │   ├── GeminiClient.swift
│   │   ├── AIService.swift
│   │   └── PromptBuilder.swift
│   └── Security/          # 安全服务
│       └── SecurityService.swift
├── Models/                # 数据模型
│   └── TradeLens.xcdatamodeld
└── Persistence/           # 持久化
    └── PersistenceController.swift
```

## 使用说明

### 记录交易

1. 进入「交易记录」页面
2. 点击「新建交易」或使用快捷键 `Cmd + N`
3. 填写交易信息（交易对、方向、价格、杠杆等）
4. 系统自动计算盈亏金额和盈亏率

### 创建复盘

1. 进入「复盘编辑器」页面
2. 点击「+」创建新复盘，或选择已有复盘
3. 使用 Markdown 格式编写复盘内容
4. 支持图片粘贴（`Cmd + Shift + V`）和拖拽
5. 添加标签便于后续检索

### AI 分析

1. 进入「AI 智能复盘」页面
2. 选择分析范围（过去 7 天、30 天或最近 N 笔）
3. 点击「开始分析」
4. 查看 AI 生成的总结和改进建议

### 查看资金曲线

1. 进入「资金曲线」页面
2. 选择时间范围（周/月/季度/全部）
3. 查看净值曲线和关键指标

## 数据安全

- 所有数据存储在本地（Core Data）
- API Key 使用系统 Keychain 安全存储
- 不会上传任何数据到服务器

## 开发计划

- [x] 项目基础架构
- [x] 核心数据模型
- [x] 交易记录模块
- [x] 复盘编辑器（基础版）
- [x] 资金曲线可视化
- [x] AI 智能复盘（基础版）
- [x] 模板管理
- [ ] 图片内联显示优化
- [ ] 链接预览卡片
- [ ] 情绪分析功能
- [ ] 一键生成复盘草稿

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题或建议，请通过 GitHub Issues 反馈。

