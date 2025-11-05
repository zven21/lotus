# Lotus

<div align="center">
**基于 Elixir/Phoenix/Ash 的元数据驱动代码生成框架**

**A metadata-driven code generation framework built with Elixir, Phoenix, and Ash Framework**

</div>

---

**Language**: [English](./README.md) | 中文

## 📖 简介

Lotus 是一个灵活的元数据驱动框架，参考了 Strapi 的设计思路，基于 Elixir、Phoenix 和 Ash Framework 构建。它采用"元数据驱动"的方式定义类型、字段与关系，并通过 Publisher 一键生成可版本化的 Elixir 资源代码与数据库迁移，同时自动暴露 JSON:API 与 GraphQL 接口。

**核心理念**：模型即真相。建模产出即为代码真相，可审阅、可追踪、可扩展，兼具高并发与低延迟的运行时特性。

### 演示视频

<video width="100%" controls>
  <source src="./docs/intr.mov" type="video/quicktime">
  您的浏览器不支持视频播放。请 <a href="./docs/intr.mov">下载视频</a> 查看。
</video>

### 应用场景

Lotus 设计灵活，可以适应多种场景。虽然可以用作 Headless CMS，但不仅限于此：

- **低代码平台底层**：在 Lotus 的元数据驱动架构之上构建你的低代码平台
- **AI 架构**：作为需要动态生成 Schema 的 AI 应用的底层基础
- **内部快速脚手架**：从元数据定义快速生成公司内部工具和应用
- **内容管理**：作为传统 Headless CMS 用于内容驱动的应用

**说明**：项目仍在演进中，尚未定型。我们正在探索不同的应用场景，欢迎贡献来共同塑造其发展方向。

## ✨ 特性

### ✅ 已实现

- **📊 元数据驱动建模**
  - 通过可视化 Builder 界面或配置文件定义类型、字段和关系

- **🚀 一键发布**
  - 生成可版本化的 `.ex` 资源文件和数据库迁移

- **🔄 关系自动反向**
  - `manyToOne` 自动生成 `oneToMany` 反向关系

- **🌐 双协议输出**
  - 内置 JSON:API 和 GraphQL 支持（包含 GraphiQL Playground）

- **📝 可视化内容管理**
  - Entries 界面进行直观的 CRUD 操作

- **🔍 配置验证**
  - JSON Schema 校验配置完整性

- **📈 增量迁移**
  - 支持配置 diff 和增量迁移生成

### ⏳ 规划中

- 更多字段类型（枚举、富文本、JSON schema）
- 权限控制（RBAC/ABAC）
- 草稿/发布工作流
- 媒体资产管理
- 多环境配置对齐
- Webhooks/Events
- 插件化机制

## 🏗️ 架构

### 核心组件

```
┌─────────────────────────────────────────────────────────┐
│                    Builder (UI)                          │
│          ContentType / ContentField / ContentRelation     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    Publisher                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Config     │  │  Generators  │  │ Migrations   │   │
│  │  Loader      │  │  (AST)       │  │  Generator   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌───────────┴───────────┐
          ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  生成代码         │    │  数据库 Schema    │
│  (Ash Resources)  │    │  (Ecto Migrations)│
└──────────────────┘    └──────────────────┘
          │                       │
          └───────────┬───────────┘
                      ▼
          ┌──────────────────────┐
          │  JSON:API / GraphQL  │
          └──────────────────────┘
```

## 🚀 快速开始

### 前置要求

- Elixir ~> 1.15
- Erlang/OTP 24+
- PostgreSQL 12+
- Node.js (用于前端资源构建)

### 安装

```bash
# 克隆仓库
git clone https://github.com/zven21/lotus.git
cd lotus

# 安装依赖
mix deps.get

# 设置数据库
mix ecto.setup

# 启动服务器
mix phx.server

# 打开浏览器
open http://localhost:4000/cms/
```

### 使用流程

#### 1. 定义内容类型

访问 `/cms/builder` 创建内容类型：

- 创建 ContentType（如 `article`, `author`）
- 添加 ContentField（如 `title`, `body`, `email`）
- 定义 ContentRelation（如 `article.author` → `manyToOne`）

#### 2. 管理内容

访问 `/cms/:slug/entries` 进行内容管理：

- 创建、编辑、删除条目
- 关系字段自动以下拉选择器呈现

#### 3. 使用 API

**JSON:API**
```bash
# 获取所有文章
GET /api/article

# 获取单篇文章
GET /api/article/:id
```

**GraphQL**
```graphql
# 访问 GraphiQL Playground
GET /api/graphiql

# 查询示例
query {
  articles {
    id
    title
    body
    author {
      name
      email
    }
  }
}
```

## 📁 项目结构

```
lotus/
├── lib/
│   ├── lotus/
│   │   ├── cms/
│   │   │   ├── ash/              # Ash 资源定义
│   │   │   ├── publisher/        # 发布系统核心
│   │   │   │   ├── application/  # 应用层（检查、钩子）
│   │   │   │   ├── generators/   # 代码生成器
│   │   │   │   ├── infrastructure/ # 基础设施
│   │   │   │   └── interfaces/   # 接口层
│   │   │   └── config_monitor.ex
│   │   ├── generated/            # 生成的资源代码
│   │   └── dynamic_module.ex     # 动态模块生成
│   └── lotus_web/
│       ├── controllers/          # Phoenix 控制器
│       ├── live/                 # LiveView 页面
│       └── router.ex             # 路由定义
├── priv/
│   ├── cms/
│   │   └── config/               # 配置文件目录
│   └── repo/
│       └── migrations/           # 数据库迁移
├── test/                         # 测试文件
└── docs/                         # 文档
```

## 🛠️ 技术栈

### 核心框架

- **Elixir** ~> 1.15 - 函数式编程语言
- **Phoenix** ~> 1.8 - Web 框架
- **Ash Framework** ~> 3.7 - 资源定义和 API 生成

### 数据库

- **PostgreSQL** - 通过 Ecto/Postgrex

### 前端

- **Phoenix LiveView** - 实时 UI
- **Tailwind CSS** - 样式框架

## 🤝 贡献

我们欢迎所有形式的贡献！请查看 [CONTRIBUTING.md](./CONTRIBUTING.md) 了解详情。

## 📄 许可证

本项目采用 [MIT License](./LICENSE)。

## 🙏 致谢

- 受 [Strapi](https://strapi.io/) 的设计思路启发
- 基于 [Ash Framework](https://ash-hq.org/) 的强大能力
- 使用 [Phoenix Framework](https://www.phoenixframework.org/) 构建

<div align="center">

**Made with ❤️ using Elixir & Phoenix**

</div>
