defmodule Lotus.DynamicModule do
  @moduledoc """
  NOTE: This module is copied from [ArcBlock/dynamic_module](https://github.com/ArcBlock/dynamic_module).
  Generate a new module based on AST.
  """

  @doc """
  Generate `.beam` and `.ex` files based on:

    * `mod_name` - the module name
    * `preamble` - the module attibutes and directives in AST, e.g. `use GenServer`, `require Logger`, etc
    * `contents` - the module body in AST

  ## Options

    * `:doc` - the documents to the module. Defaults to `false`
    * `:path` - the path for generated `.ex` files. Defaults to `""`
    * `:create` - a boolean value indicates whether to create `.beam` file. Defaults to `true`
  """
  defmacro gen(mod_name, preamble, contents, opts \\ []) do
    quote bind_quoted: [
            mod_name: mod_name,
            preamble: preamble,
            contents: contents,
            opts: opts
          ] do
      mod_doc = Keyword.get(opts, :doc, false)
      path = Keyword.get(opts, :path, "")
      filename_opt = Keyword.get(opts, :filename, nil)
      create? = Keyword.get(opts, :create, true)
      format? = Keyword.get(opts, :format, true)
      output? = Keyword.get(opts, :output, true)

      moduledoc =
        quote do
          @moduledoc unquote(mod_doc)
        end

      name = String.to_atom("Elixir.#{mod_name}")

      if create? do
        Module.create(
          name,
          [moduledoc] ++ [preamble] ++ [contents],
          Macro.Env.location(__ENV__)
        )
      end

      case File.mkdir_p(path) do
        {:error, :enoent} ->
          [:cyan, "Module [#{mod_name}] is generated."]
          |> IO.ANSI.format()
          |> IO.puts()

        :ok ->
          filename =
            case filename_opt do
              nil -> Path.join(path, "#{mod_name}.ex")
              custom -> Path.join(path, custom)
            end

          # 确保自定义文件名包含的子目录存在（例如 generated/xxx.ex）
          filename |> Path.dirname() |> File.mkdir_p!()

          term =
            if is_list(contents) do
              quote do
                defmodule unquote(name) do
                  unquote(moduledoc)
                  unquote(preamble)
                  unquote_splicing(contents)
                end
              end
            else
              quote do
                defmodule unquote(name) do
                  unquote(moduledoc)
                  unquote(preamble)
                  unquote(contents)
                end
              end
            end

          term =
            term
            |> Macro.to_string()
            |> String.replace(~r/(\(\s|\s\))/, "")
            |> String.replace(
              ~r/(def|defp|defmodule|create|create_if_not_exists|get|post|patch|delete|object|enum|schema)\((.*?)\) do/,
              "\\1 \\2 do"
            )
            |> String.replace(
              ~r/(alias|require|import|pipe|use|plug|forward|field|has_one|has_many|add|timestamps|drop|drop_if_exists)\((.*?)\)\n/,
              "\\1 \\2\n"
            )

          File.write!(filename, term)

          if format? do
            Mix.Tasks.Format.run([filename])
          end

          if output? do
            [:cyan, "Module [#{mod_name}] is generated. File created at #{filename}."]
            |> IO.ANSI.format()
            |> IO.puts()
          end
      end
    end
  end

  @doc """
  Generate module name based on `app`, `prefix` and `name`. The `postfix` is optional.

  ## Examples

      iex> DynamicModule.gen_module_name(:app, "Prefix", "name")
      "App.Prefix.Name"

      iex> DynamicModule.gen_module_name(:app, "Prefix", "name", "Postfix")
      "App.Prefix.Name.Postfix"
  """
  @spec gen_module_name(atom(), String.t(), String.t(), String.t()) :: String.t()
  def gen_module_name(app, prefix, name, postfix \\ "") do
    app = app |> Atom.to_string() |> Recase.to_pascal()
    name = Recase.to_pascal(name)

    case postfix do
      "" -> "#{app}.#{prefix}.#{name}"
      _ -> "#{app}.#{prefix}.#{name}.#{postfix}"
    end
  end

  @doc """
  Normalize name to atom.

  ## Examples

      iex> DynamicModule.normalize_name("a")
      :a

      iex> DynamicModule.normalize_name(:abc)
      :abc
  """
  @spec normalize_name(String.t() | atom()) :: atom()
  def normalize_name(nil), do: nil
  def normalize_name(name) when is_atom(name), do: name
  def normalize_name(name), do: String.to_atom(name)
end
