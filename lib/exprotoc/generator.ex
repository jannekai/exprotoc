defmodule Exprotoc.Generator do
  @moduledoc "Given a structured AST, generate code files into an output dir."

  def generate_code({ ast, full_ast }, dir, namespace) do
    File.mkdir_p dir
    generate_modules { [], full_ast }, [], HashDict.to_list(ast), dir, namespace
  end
  def generate_code({ package, ast, full_ast}, dir, namespace) do
    dir = create_package_dir package, dir
    { [], ast } = ast[package]
    generate_modules { [], full_ast }, [package], HashDict.to_list(ast), dir, namespace
  end

  defp create_package_dir(package, dir) do
    package_name = to_enum_type package
    dir = dir |> Path.join(package_name)
    File.mkdir_p dir
    dir
  end

  defp generate_modules(_, _, [], _, _) do end
  defp generate_modules(ast, scope, [module|modules], dir, namespace) do
    { name, _ } = module
    new_scope = [ name | scope ]
    module_filename = name |> Atom.to_string |> to_module_filename
    path = Path.join dir, module_filename
    module_text = generate_module ast, new_scope, module, 0, false, namespace
    File.write path, module_text
    generate_modules ast, scope, modules, dir, namespace
  end

  defp generate_module(_, scope, { _, { :enum, enum_values } }, level, sub, namespace) do
    fullname = scope |> Enum.reverse |> get_module_name(namespace)
    if sub do
      [name|_] = scope
      name = Atom.to_string name
    else
      name = fullname
    end
    i = indent level
    { acc1, acc2, acc3, acc4 } =
      List.foldl enum_values, { "", "", "", [] },
           fn({k, v}, { a1, a2, a3, a4 }) ->
               enum_atom = to_enum_type k
               a1 = a1 <>
               "#{i}  def to_i({ #{fullname}, :#{enum_atom} }), do: #{v}\n"
               a2 = a2 <>
               "#{i}  def to_symbol(#{v}), do: { #{fullname}, :#{enum_atom} }\n"
               a3 = a3 <>
               "#{i}  def #{enum_atom}, do: { #{fullname}, :#{enum_atom} }\n"
               a4 = [enum_atom|a4]
               { a1, a2, a3, a4 }
           end
    enum_funs = acc1 <> acc2 <> acc3
    enum_types = Enum.reverse acc4
    first_field = Enum.at(enum_types, 0)
    types = Enum.map_join enum_types, " | ", fn(enum_type) ->
                                               ":" <> enum_type
                                             end
    members = Enum.map_join enum_types, ", ", fn(enum_type) -> ":" <> enum_type end
    """
#{i}defmodule #{name} do
#{i}  @type t :: {#{fullname}, #{types}}
#{i}  def decode(value), do: to_symbol value
#{i}  def first(), do: #{first_field}
#{i}  def to_a({ #{fullname}, atom }), do: atom
#{i}  def from_a( atom ), do: { #{fullname}, atom }
#{i}  def members(), do: [ #{members} ]
#{enum_funs}#{i}end
"""
  end
  defp generate_module(ast, scope, module, level, sub, namespace) do
    if sub do
      [name|_] = scope
      name = Atom.to_string name
    else
      name = scope |> Enum.reverse |> get_module_name(namespace)
    end
    i = indent level
    fields_text = process_fields ast, scope, module, level, namespace
    submodules = module |> elem(1) |> elem(1) |> HashDict.to_list
    submodule_text = List.foldl submodules, "",
                          fn(m = { n, _ }, acc) ->
                              acc <> generate_module(ast, [n|scope],
                                                     m, level + 1, true, namespace)
                          end

    """
#{i}defmodule #{name} do
#{i}  @type t :: %#{name}{message: HashDict.t}
#{i}  defstruct message: HashDict.new
#{i}  def encode(msg) do
#{i}    p = List.foldl get_keys, [], fn(key, acc) ->
#{i}          fnum = get_fnum key
#{i}          type = get_type fnum
#{i}          value = msg.message[fnum]
#{i}          if value == nil do
#{i}            if get_ftype(fnum) == :required do
#{i}              raise \"Missing field \#{key} when encoding ${__MODULE__}\"
#{i}            end
#{i}            acc
#{i}          else
#{i}            [ { fnum, { type, value } } | acc ]
#{i}          end
#{i}        end
#{i}    Exprotoc.Protocol.encode_message p
#{i}  end

#{i}  def decode(payload) do
#{i}    m = Exprotoc.Protocol.decode_payload payload, __MODULE__
#{i}    %#{name}{message: m}
#{i}  end

#{i}  def new, do: %#{name}{}
#{i}  def new(enum) do
#{i}    new new(), enum
#{i}  end
#{i}  def new(msg, enum) do
#{i}    Enum.reduce enum, msg, fn({k, v}, acc) ->
#{i}      put acc, k, v
#{i}    end
#{i}  end
#{i}  def get(msg, keys) when is_list(keys) do
#{i}    Enum.map keys, &( get(msg, &1) )
#{i}  end
#{i}  def get(msg, key) when is_atom(key) do
#{i}      do_get(msg.message, key)
#{i}  end
#{i}  def do_get(m, key) do
#{i}    f_num = get_fnum key
#{i}    if HashDict.has_key?(m, f_num) do
#{i}      if get_ftype(f_num) == :repeated do
#{i}        elem m[f_num], 1
#{i}      else
#{i}        m[f_num]
#{i}      end
#{i}    else
#{i}      if get_ftype(f_num) == :repeated do
#{i}        []
#{i}      else
#{i}        get_default f_num
#{i}      end
#{i}    end
#{i}  end
#{i}  def has_key(msg, key) do
#{i}    f_num = get_fnum key
#{i}    m = msg.message
#{i}    HashDict.has_key?(m, f_num)
#{i}  end
#{i}  def put(msg, key, value) do
#{i}    f_num = get_fnum key
#{i}    m = msg.message
#{i}    m = put_key m, f_num, value
#{i}    %#{name}{msg | message: m}
#{i}  end
#{i}  def delete(msg, key) do
#{i}    f_num = get_fnum key
#{i}    m = msg.message
#{i}    m = HashDict.delete m, f_num
#{i}    %#{name}{msg | message: m}
#{i}  end

#{fields_text}#{submodule_text}#{i}end

#{i}defimpl Inspect, for: #{name} do
#{i}  def inspect(msg, opts), do: Exprotoc.Inspect.inspect(#{name}, msg, opts)
#{i}end

#{i}defimpl Enumerable, for: #{name} do
#{i}  def count(msg), do: {:ok, Dict.size msg.message}
#{i}  def member?(msg, key), do: {:ok, #{name}.has_key(msg, key)}
#{i}  def reduce(%#{name}{message: dict}, acc, fun), do: do_reduce(Dict.keys(dict), dict, acc, fun)
#{i}  def do_reduce(_,     _, {:halt, acc}, _fun),   do: {:halted, acc}
#{i}  def do_reduce(list,  d, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, d, &1, fun)}
#{i}  def do_reduce([],    _, {:cont, acc}, _fun),   do: {:done, acc}
#{i}  def do_reduce([h|t], d, {:cont, acc}, fun) do
#{i}    k = #{name}.get_fname(h)
#{i}    do_reduce(t, d, fun.({k, #{name}.do_get(d, k)}, acc), fun)
#{i}  end
#{i}end

#{i}defimpl Access, for: #{name} do
#{i}  def get(msg, key), do: #{name}.get(msg, key)
#{i}  def get_and_update(msg, key, update_fun) do
#{i}   {get, update} = update_fun.(get(msg, key))
#{i}   {get, #{name}.new(msg, [{key, update}])}
#{i}  end
#{i}end
"""
  end

  def get_module_name(names, namespace) do
    prepend_namespace(names, namespace) |> get_module_name
  end

  def get_module_name(names) do
    Enum.join names, "."
  end

  def prepend_namespace(names, nil) do
    names
  end
  def prepend_namespace(names, namespace) do
    [namespace|names]
  end

  defp process_fields(ast, scope, { _, { fields, _ } }, level, namespace) do
    process_fields ast, scope, fields, level, namespace
  end
  defp process_fields(ast, scope, fields, level, namespace) do
    i = indent level + 1
    ftype_acc = """
#{i}def get_ftype(-1), do: :required
#{i}def get_ftype(-2), do: :repeated
#{i}def get_ftype(-3), do: :optional
"""
    acc = { "", "", ftype_acc, "", "", [] , ""}
    { acc1, acc2, acc3, acc4, acc5, acc6, acc7 } =
      List.foldl fields, acc,
           &process_field(ast, scope, &1, &2, i, namespace)
    acc5 = acc5 <> "#{i}def get_default(_), do: nil\n"
    key_string = generate_keystring acc6, i
    acc1 <> acc2 <> acc7 <>  acc3 <> acc4 <> acc5 <> key_string
  end

  defp generate_keystring(keys, i) do
    keys = Enum.map keys, fn(key) -> ":" <> Atom.to_string(key) end
    center = Enum.join keys, ", "
    """
#{i}def get_keys, do: [ #{center} ]
"""
  end

  defp process_field(ast, scope, { :field, ftype, type, name, fnum, opts } = _arg,
                     { acc1, acc2, acc3, acc4, acc5, acc6, acc7 } , i, namespace) do
    type_term = type_to_term ast, scope, type, namespace
    type = type_term_to_string type_term
    if ftype == :repeated do
      acc1 = acc1 <> """
#{i}defp put_key(msg, #{fnum}, []) do
#{i}  msg
#{i}end
#{i}defp put_key(msg, #{fnum}, values) when is_list(values) do
#{i}  HashDict.put msg, #{fnum}, { :repeated, values }
#{i}end
"""
    else
      acc1 = acc1 <> """
#{i}defp put_key(msg, #{fnum}, value) do
#{i}  HashDict.put msg, #{fnum}, value
#{i}end
"""
    end
    acc2 = acc2 <> "#{i}def get_fnum(:#{name}), do: #{fnum}\n"
    acc3 = acc3 <> "#{i}def get_ftype(#{fnum}), do: :#{ftype}\n"
    acc4 = acc4 <> "#{i}def get_type(#{fnum}), do: #{type}\n"
    acc5 = acc5 <> generate_default_value(i, fnum, type_term, opts)
    acc7 = acc7 <> "#{i}def get_fname(#{fnum}), do: :#{name}\n"
    { acc1, acc2, acc3, acc4, acc5, [ name | acc6 ], acc7}
  end

  defp generate_default_value(i, fnum, type, opts) do
    default = do_generate_default_value type, opts
    if default != nil do
      "#{i}def get_default(#{fnum}), do: #{default}\n"
    else
      ""
    end
  end

  defp do_generate_default_value(:bool, opts) do
    generate_default(opts[:default], false)
  end
  defp do_generate_default_value({:enum, name}, opts) do
    Kernel.inspect(name) <> "." <> to_enum_type(generate_default(opts[:default], :first))
  end
  defp do_generate_default_value(:string, opts) do
    generate_default(opts[:default], "\"\"")
  end
  defp do_generate_default_value(type, opts)
  when type in [:int32, :int64, :uint32, :uint64, :sint32,
                :sint64, :fixed32, :fixed64, :sfixed32, :sfixed64] do
    generate_default(opts[:default], 0)
  end
  defp do_generate_default_value(type, opts)
  when type in [:double, :float] do
    generate_default(opts[:default], 0.0)
  end
  defp do_generate_default_value(_type, opts) do
    opts[:default]
  end
  # TODO
  # default for bytes?

  defp generate_default(nil, default) do
    default
  end
  defp generate_default(custom_default, _default) do
    custom_default
  end

  defp indent(level), do: String.duplicate("  ", level)

  defp type_term_to_string(term) do
      Kernel.inspect term
  end

  defp type_to_term(ast, scope, type, namespace) when is_list(type) do
    { module, pointer } = Exprotoc.AST.search_ast ast, scope, type
    modulename = "Elixir." <> get_module_name(pointer, namespace)
             |> String.to_atom
    if elem(module, 0) == :enum do
      { :enum, modulename }
    else
      { :message, modulename }
    end
  end
  defp type_to_term(ast, scope, type, namespace) do
    if Exprotoc.Protocol.wire_type(type) == :custom do
      type_to_term ast, scope, [type], namespace
    else
      type
    end
  end

  defp to_module_filename(module) do
    module = String.downcase module
    Regex.replace(~r/\./, module, "_") <> ".ex"
  end

  defp to_enum_type(name) do
    name
      |> Atom.to_string
      |> String.downcase
  end
end
