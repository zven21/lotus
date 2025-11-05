### 基于 ContentType.config 作为唯一真源的内容建模与生成架构设计

#### 目标与原则
- **唯一真源**: 使用 `ContentType.config (json)` 统一声明字段、关系、索引、策略、审计/版本等，驱动迁移与代码生成。
- **投影读取**: 保留 `ContentField`、`ContentRelation` 作为从 `config` 派生的“规范化投影”，便于查询、校验与运营。
- **演进友好**: 以“配置 diff → 迁移计划”支持字段新增、重命名、类型变更、索引/约束调整与数据回填。
- **可审阅/可回滚**: 版本化配置、生成 SQL 预览、校验和一致性检查与回滚策略。

---

### 配置模型（strapi 风格，伪 JSON）
```json
{
  "meta": {
    "version": "1.3.0",
    "name": "Author",
    "slug": "author",
    "namespace": "cms"
  },
  "storage": {
    "table": "cms_authors",
    "primary_key": { "name": "id", "type": "uuid", "default": "uuid_generate_v4()" },
    "indexes": [
      { "name": "authors_email_unique", "type": "unique", "columns": ["email"] },
      { "name": "authors_search_gin", "type": "gin", "using": "gin", "expression": "to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(email,''))" }
    ],
    "constraints": [
      { "name": "email_format_chk", "type": "check", "expression": "email ~* '^[^@]+@[^@]+\\.[^@]+$'" }
    ]
  },
  "features": {
    "audit": true,
    "versioning": { "mode": "snapshot", "draft_publish": true },
    "soft_delete": true,
    "i18n": false,
    "search": { "engine": "pg", "strategy": "tsvector" }
  },
  "fields": [
    {
      "name": "name",
      "type": "string",
      "length": 120,
      "nullable": false,
      "default": null,
      "searchable": true,
      "filterable": true,
      "sortable": true,
      "unique": false,
      "validations": { "minLength": 1 }
    },
    {
      "name": "email",
      "type": "string",
      "length": 255,
      "nullable": false,
      "default": null,
      "searchable": true,
      "filterable": true,
      "sortable": true,
      "unique": true,
      "validations": { "format": "email" }
    },
    {
      "name": "mobile",
      "type": "string",
      "length": 20,
      "nullable": true,
      "default": null,
      "searchable": true,
      "filterable": true,
      "sortable": false,
      "unique": false,
      "validations": { "pattern": "^\\+?[0-9\\-]{7,20}$" }
    },
    {
      "name": "bio",
      "type": "text",
      "nullable": true,
      "default": null,
      "searchable": true,
      "filterable": false,
      "sortable": false
    }
  ],
  "relationships": [
    {
      "name": "posts",
      "kind": "has_many",
      "target": { "namespace": "cms", "slug": "post" },
      "foreign_key": { "column": "author_id", "target_pk": "id" },
      "on_delete": "nilify",
      "required": false,
      "inverse": { "name": "author", "kind": "belongs_to" }
    }
  ],
  "policies": {
    "read": [
      { "effect": "allow", "role": "admin" },
      { "effect": "allow", "role": "editor" },
      { "effect": "allow", "condition": "owns(record)" }
    ],
    "create": [
      { "effect": "allow", "role": "admin" },
      { "effect": "allow", "role": "editor" }
    ],
    "update": [
      { "effect": "allow", "role": "admin" },
      { "effect": "allow", "condition": "owns(record)" }
    ],
    "delete": [
      { "effect": "allow", "role": "admin" }
    ]
  },
  "validation": {
    "cross_field": [
      { "name": "email_or_mobile_required", "expression": "coalesce(email,'') <> '' OR coalesce(mobile,'') <> ''" }
    ]
  },
  "ops": {
    "data_migrations": [
      {
        "version": "1.3.0",
        "name": "backfill_mobile_from_legacy",
        "phase": "post_add_column",
        "strategy": "sql",
        "sql": "update cms_authors set mobile = legacy_mobile where mobile is null and legacy_mobile is not null"
      }
    ],
    "seed": [
      { "name": "Default Admin", "email": "admin@example.com" }
    ],
    "compat": {
      "renames": [
        { "from": "phone", "to": "mobile", "since": "1.2.0", "remove_in": "2.0.0" }
      ],
      "deprecations": [
        { "name": "legacy_mobile", "since": "1.3.0", "remove_in": "2.0.0" }
      ]
    }
  }
}
```

---

### 用 Content* 三表表达（不写代码，结构化说明）
- **ContentType（真源 + 核心投影）**
  - `id`, `namespace`, `slug`, `name`, `table`
  - `meta_version`: 配置版本号
  - `features`: 审计/版本/软删/i18n/search 等开关的投影
  - `policies`: 可冗余投影（或仅在 `config` 中）
  - `config`: 上述完整 JSON
  - `checksum`: 工件校验和（迁移与资源一致性）

- **ContentField（从 config.fields 派生）**
  - `type_id` → `ContentType.id`
  - `name`, `data_type`, `length`, `nullable`, `default`, `unique`
  - `searchable`, `filterable`, `sortable`, `i18n`
  - `validations`（minLength/format/pattern…）
  - `index_hint`（可选）
  - `ui_hints`（可选）
  - `compat_tag`（如 `renamed_from`、`deprecated`）

- **ContentRelation（从 config.relationships 派生）**
  - `type_id` → `ContentType.id`
  - `name`, `kind`（belongs_to/has_many/many_to_many）
  - `target_namespace`, `target_slug`
  - `foreign_key_column`, `target_pk`, `through_table`
  - `on_delete`, `required`
  - `inverse_name`, `inverse_kind`, `cardinality`
  - `index_hint`（可选）
  - `compat_tag`（可选）

- **索引/约束**
  - 若未单独建表，则保留在 `config.storage.indexes/constraints`，由迁移生成器读取。
  - `ContentField.unique=true` 可派生单列唯一；组合唯一从 `storage.indexes` 提供。

- **策略/权限**
  - 常驻 `config.policies`；必要时投影为策略加载表或缓存。

- **特性（审计/版本/软删/搜索）**
  - 在 `ContentType.features` 做开关投影；生成器依据 `config.features` 产出迁移/资源/索引。

- **数据迁移与兼容**
  - 保留在 `config.ops.data_migrations` 与 `config.ops.compat`。
  - 可新增 `ContentPlan/ContentRevision` 记录 A→B 的计划产物（SQL 预览、脚本名、校验和）。

---

### 变更与迁移流程（配置 diff → 迁移计划）
- **变更识别**
  - 字段新增/删除/重命名/类型变更/默认值与 null 约束变化
  - 关系/外键/索引/唯一约束/检查约束更新
- **生成计划**
  - DB 迁移（分阶段：加列→回填→切换→删旧）
  - 数据迁移脚本（回填、拆分、合并、格式化）
  - 资源/策略/路由/搜索索引的再生成清单
- **审阅与执行**
  - SQL 预览、危险变更提示、回滚策略
  - 执行迁移 → 再生成代码 → 校验一致性（checksum）

---

### 推荐工作流
- **编辑配置**: 通过 UI 或直接编辑 `ContentType.config`
- **静态校验**: 结构/关系闭包/索引合理性/危险变更检查
- **生成计划**: 输出 DB/数据迁移与生成清单
- **审阅批准**: 人工审核计划与 SQL 预览
- **执行与发布**: 产出 migration、生成资源与策略，记录 `checksum`
- **回溯与回滚**: 版本与工件校验，支持安全回滚

---

### 关键取舍
- **不合并为单表“Content”**：保留 `ContentType` 为真源，`ContentField/ContentRelation` 为投影，避免双写、保留易用查询。
- **强约束一致性**：仅允许写 `config`，其他表只做同步派生。
- **演进优先**：提供重命名与弃用的兼容期策略，多阶段在线迁移，安全变更。

---

### 最小闭环建议
- **定义 JSON Schema**: 为 `config` 制定校验规则。
- **实现配置 diff**: 覆盖新增字段/索引/searchable 基础场景。
- **生成器打通**: 产出 Ecto migration + Ash Resource；开启基础审计/搜索链路。
- **CI dry-run**: 自动校验与 SQL 预览，阻断危险变更。

---

### TODO List（实施计划）

按重要性和基础性排序，采用 TDD 方式逐步实现：

#### 基础性任务（增量能力）
1. ✅ **Define ContentType.config JSON Schema and validator** - 定义配置 JSON Schema 和校验器（已完成）
   - ✅ 定义 JSON Schema 结构
   - ✅ 实现配置校验函数 (`Lotus.CMS.Publisher.ConfigSchema`)
   - ✅ 覆盖必填字段、类型、格式校验（meta, storage, fields, relationships）
   - ✅ 测试覆盖：18个测试用例全部通过

2. ✅ **Build config→projection sync for ContentField and ContentRelation** - 实现配置到投影表的同步（已完成）
   - ✅ 字段同步：顺序映射至 `order`，传递 `nullable/unique/default/options`，幂等更新与删除多余项
   - ✅ 关系同步：支持 `belongs_to/has_*`，默认外键（缺省为 `name_id`），传递 `target/target_field/on_delete/through/options`，幂等更新与删除多余项
   - ✅ 测试：`projection_sync_test.exs` 覆盖顺序、唯一性、默认外键、增删改路径

3. ⏳ **Implement config diff engine for schema changes** - 实现配置差异检测引擎（进行中）
   - ✅ 已完成：字段新增/删除/类型变更、关系新增/删除（`DiffEngine` + 测试）
   - ✅ 已完成：字段重命名（`ops.compat.renames` → `fields.rename`）
   - ✅ 已完成：唯一索引新增/删除（`storage.indexes` → `indexes.add/remove`）
   - ⏳ 待扩展：字段重命名自动推断、组合唯一/检查约束、关系变更细粒度（kind/target 变化）

4. ⏳ **Generate migration plan from diff, incl. data migrations** - 从差异生成迁移计划（进行中）
   - ✅ 已完成：字段 add/drop/alter，belongs_to 外键列与索引（`MigrationPlan` + 测试）
   - ✅ 已完成：字段重命名 → `{:rename_column, from, to}`
   - ✅ 已完成：唯一索引 add/remove → `{:create_unique_index, cols, name}` / `{:drop_unique_index, cols, name}`
   - ⏳ 待扩展：数据迁移 hooks、组合唯一/复杂索引、检查约束

5. ⏳ **Implement migration executor and checksum consistency tracking** - 实现迁移执行器和校验和跟踪（进行中）
   - ✅ 已完成：计划到 Ecto 代码片段（`MigrationCodegen`）
   - ✅ 已完成：plan/config 校验和（sha256）
   - ✅ 已完成：编排器（`MigrationOrchestrator`）串联 diff→plan→codegen+checksums
   - ✅ 已完成：写文件（`MigrationWriter`），带 checksum 头注释，沙箱输出
   - ⏳ 待接入：发布流程 dry-run 输出与 revision/发布记录（checksum 落库）

#### 核心功能（Search 和 Relationship）
6. ⏳ **Implement searchable fields → DB indexes and API filters** - 实现可搜索字段的索引和 API 过滤
   - 生成全文搜索索引（GIN/tsvector）
   - 生成 API 过滤查询
   - 搜索字段配置验证

7. ⏳ **Implement relationships generation: FKs, join tables, actions** - 实现关系生成
   - 外键约束生成
   - 多对多联结表生成
   - 关系查询 actions 生成

#### 安全与访问控制（Policy）
8. ⏳ **Map config policies to Ash policies with enforcement** - 映射配置策略到 Ash 策略
   - 从 `config.policies` 生成 Ash Policy
   - 策略验证和加载
   - 运行时授权检查

#### 工具与质量保证
9. ⏳ **Add CI dry-run with SQL preview and danger checks** - 添加 CI dry-run 和 SQL 预览
   - 生成 SQL 预览
   - 危险变更检测
   - 自动测试集成

10. ⏳ **Document workflows and provide example configs** - 文档化和示例配置
    - 完整工作流文档
    - 示例配置文件
    - 最佳实践指南
