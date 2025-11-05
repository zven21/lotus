# Lotus

<div align="center">
**A metadata-driven code generation framework built with Elixir, Phoenix, and Ash Framework**

</div>

---

**Language**: English | [中文](./README_CN.md)

## 📖 Introduction

Lotus is a flexible metadata-driven framework inspired by Strapi, built on Elixir, Phoenix, and Ash Framework. It adopts a "metadata-driven" approach to define types, fields, and relationships, and generates versionable Elixir resource code and database migrations through the Publisher with one click, while automatically exposing JSON:API and GraphQL interfaces.

**Core Philosophy**: Models as Truth. The modeling output becomes the code truth, reviewable, traceable, and extensible, with high concurrency and low latency runtime characteristics.

### Use Cases

Lotus is designed to be flexible and adaptable. While it can serve as a Headless CMS, it's not limited to that:

- **Low-Code Platform Foundation**: Build your low-code platform on top of Lotus's metadata-driven architecture
- **AI Architecture**: Use as a foundation for AI-powered applications that need dynamic schema generation
- **Internal Rapid Scaffolding**: Generate company-internal tools and applications quickly from metadata definitions
- **Content Management**: Use as a traditional Headless CMS for content-driven applications

**Note**: The project is still evolving and not yet finalized. We're exploring different use cases and welcome contributions to shape its direction.

## ✨ Features

### ✅ Implemented

- **📊 Metadata-Driven Modeling**
  - Define types, fields, and relationships through visual Builder interface or configuration files

- **🚀 One-Click Publishing**
  - Generate versionable `.ex` resource files and database migrations

- **🔄 Automatic Relationship Reversal**
  - `manyToOne` automatically generates `oneToMany` reverse relationships

- **🌐 Dual Protocol Output**
  - Built-in JSON:API and GraphQL support (includes GraphiQL Playground)

- **📝 Visual Content Management**
  - Intuitive CRUD operations through Entries interface

- **🔍 Configuration Validation**
  - JSON Schema validation for configuration integrity

- **📈 Incremental Migrations**
  - Support for configuration diff and incremental migration generation

### ⏳ Planned

- More field types (enum, rich text, JSON schema)
- Permission control (RBAC/ABAC)
- Draft/Publish workflow
- Media asset management
- Multi-environment configuration alignment
- Webhooks/Events
- Plugin mechanism

## 🏗️ Architecture

### Core Components

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
│  Generated Code   │    │  Database Schema  │
│  (Ash Resources)  │    │  (Ecto Migrations)│
└──────────────────┘    └──────────────────┘
          │                       │
          └───────────┬───────────┘
                      ▼
          ┌──────────────────────┐
          │  JSON:API / GraphQL  │
          └──────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Elixir ~> 1.15
- Erlang/OTP 24+
- PostgreSQL 12+
- Node.js (for frontend asset building)

### Installation

```bash
# Clone repository
git clone https://github.com/zven21/lotus.git
cd lotus

# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start server
mix phx.server

# Open browser
open http://localhost:4000/cms/
```

### Usage Flow

#### 1. Define Content Type

Visit `/cms/builder` to create content types:

- Create ContentType (e.g., `article`, `author`)
- Add ContentField (e.g., `title`, `body`, `email`)
- Define ContentRelation (e.g., `article.author` → `manyToOne`)

#### 2. Manage Content

Visit `/cms/:slug/entries` for content management:

- Create, edit, delete entries
- Relationship fields automatically displayed as dropdown selectors

#### 3. Use APIs

**JSON:API**
```bash
# Get all articles
GET /api/article

# Get single article
GET /api/article/:id
```

**GraphQL**
```graphql
# Visit GraphiQL Playground
GET /api/graphiql

# Query example
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

## 📁 Project Structure

```
lotus/
├── lib/
│   ├── lotus/
│   │   ├── cms/
│   │   │   ├── ash/              # Ash resource definitions
│   │   │   ├── publisher/        # Publisher system core
│   │   │   │   ├── application/  # Application layer (checks, hooks)
│   │   │   │   ├── generators/   # Code generators
│   │   │   │   ├── infrastructure/ # Infrastructure
│   │   │   │   └── interfaces/   # Interface layer
│   │   │   └── config_monitor.ex
│   │   ├── generated/            # Generated resource code
│   │   └── dynamic_module.ex     # Dynamic module generation
│   └── lotus_web/
│       ├── controllers/          # Phoenix controllers
│       ├── live/                 # LiveView pages
│       └── router.ex             # Route definitions
├── priv/
│   ├── cms/
│   │   └── config/               # Configuration file directory
│   └── repo/
│       └── migrations/           # Database migrations
├── test/                         # Test files
└── docs/                         # Documentation
```

## 🛠️ Tech Stack

### Core Frameworks

- **Elixir** ~> 1.15 - Functional programming language
- **Phoenix** ~> 1.8 - Web framework
- **Ash Framework** ~> 3.7 - Resource definitions and API generation

### Database

- **PostgreSQL** - via Ecto/Postgrex

### Frontend

- **Phoenix LiveView** - Real-time UI
- **Tailwind CSS** - Styling framework

## 🤝 Contributing

We welcome all kinds of contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

## 🙏 Acknowledgments

- Inspired by [Strapi](https://strapi.io/) design philosophy
- Built on the powerful [Ash Framework](https://ash-hq.org/)
- Constructed with [Phoenix Framework](https://www.phoenixframework.org/)

<div align="center">

**Made with ❤️ using Elixir & Phoenix**

</div>
