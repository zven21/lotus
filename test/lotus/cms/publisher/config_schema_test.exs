defmodule Lotus.CMS.Publisher.ConfigSchemaTest do
  use ExUnit.Case, async: true

  alias Lotus.CMS.Publisher.ConfigSchema

  describe "validate/1" do
    test "accepts valid minimal config" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author",
          "namespace" => "cms"
        },
        "storage" => %{
          "table" => "cms_authors"
        },
        "fields" => []
      }

      assert {:ok, _validated} = ConfigSchema.validate(config)
    end

    test "requires meta field" do
      config = %{
        "storage" => %{"table" => "cms_authors"},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :meta)
    end

    test "requires meta.version" do
      config = %{
        "meta" => %{
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :meta)
    end

    test "requires meta.name" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :meta)
    end

    test "requires meta.slug" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :meta)
    end

    test "requires storage field" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :storage)
    end

    test "requires storage.table" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :storage)
    end

    test "validates field structure" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [
          %{"name" => "email", "type" => "string", "nullable" => false}
        ]
      }

      assert {:ok, _validated} = ConfigSchema.validate(config)
    end

    test "requires field.name" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [
          %{"type" => "string"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :fields)
    end

    test "requires field.type" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [
          %{"name" => "email"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :fields)
    end

    test "validates field.type is valid" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [
          %{"name" => "email", "type" => "invalid_type"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :fields)
    end

    test "validates relationship structure" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Article",
          "slug" => "article"
        },
        "storage" => %{"table" => "cms_articles"},
        "fields" => [],
        "relationships" => [
          %{
            "name" => "author",
            "kind" => "belongs_to",
            "target" => %{"namespace" => "cms", "slug" => "author"}
          }
        ]
      }

      assert {:ok, _validated} = ConfigSchema.validate(config)
    end

    test "requires relationship.name" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Article",
          "slug" => "article"
        },
        "storage" => %{"table" => "cms_articles"},
        "fields" => [],
        "relationships" => [
          %{"kind" => "belongs_to"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :relationships)
    end

    test "requires relationship.kind" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Article",
          "slug" => "article"
        },
        "storage" => %{"table" => "cms_articles"},
        "fields" => [],
        "relationships" => [
          %{"name" => "author"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :relationships)
    end

    test "validates relationship.kind is valid" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Article",
          "slug" => "article"
        },
        "storage" => %{"table" => "cms_articles"},
        "fields" => [],
        "relationships" => [
          %{"name" => "author", "kind" => "invalid_kind"}
        ]
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :relationships)
    end

    test "validates meta.slug format" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "Invalid-Slug!"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => []
      }

      assert {:error, errors} = ConfigSchema.validate(config)
      assert Keyword.has_key?(errors, :meta)
    end

    test "accepts optional features field" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [],
        "features" => %{
          "audit" => true,
          "versioning" => %{"mode" => "snapshot"},
          "soft_delete" => true
        }
      }

      assert {:ok, _validated} = ConfigSchema.validate(config)
    end

    test "accepts optional policies field" do
      config = %{
        "meta" => %{
          "version" => "1.0.0",
          "name" => "Author",
          "slug" => "author"
        },
        "storage" => %{"table" => "cms_authors"},
        "fields" => [],
        "policies" => %{
          "read" => [
            %{"effect" => "allow", "role" => "admin"}
          ]
        }
      }

      assert {:ok, _validated} = ConfigSchema.validate(config)
    end
  end
end
