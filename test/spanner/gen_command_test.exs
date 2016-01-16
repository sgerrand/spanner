defmodule Spanner.GenCommand.Test do
  use ExUnit.Case

  alias Spanner.GenCommand

  defmodule TestCommand do
    use GenCommand.Base, bundle: "foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule NotACommand do
    def howdy, do: "Hello World"
  end

  defmodule CommandWithOption do
    use GenCommand.Base, bundle: "foo"
    option "my_option", type: "string", required: true
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithDefaultOption do
    use GenCommand.Base, bundle: "foo"
    option "default_option"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultipleOptions do
    use GenCommand.Base, bundle: "foo"

    option "my_option", type: "string", required: true
    option "another_option", type: "boolean"
    option "foooooo"

    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithPermission do
    use GenCommand.Base, bundle: "foo"
    permission "foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultiplePermissions do
    use GenCommand.Base, bundle: "foo"
    permission "foo"
    permission "bar"
    permission "baz"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultiplePermissionsDeclaredAtOnce do
    use GenCommand.Base, bundle: "foo"
    permission ["one", "two", "three"]
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMixOfPermissions do
    use GenCommand.Base, bundle: "foo"
    permission "a"
    permission ["b", "c"]
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithRules do
    use GenCommand.Base, bundle: "foo", name: "command-with-rules"
    permission "blah"
    rule "when command is foo:command-with-rules must have foo:blah"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultipleRules do
    use GenCommand.Base, bundle: "foo", name: "command-with-multiple-rules"
    permission "blah"

    rule "when command is foo:command-with-multiple-rules must have foo:blah"
    rule "when command is foo:command-with-multiple-rules with arg[0] == 'stuff' must have foo:admin"

    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  test "command modules are marked as such" do
    assert GenCommand.is_command?(TestCommand)
    refute GenCommand.is_command?(NotACommand)
  end

  test "commands can have no options" do
    assert [] = GenCommand.options(TestCommand)
  end

  test "commands can have one option" do
    assert [%{"name" => "my_option", "type" => "string", "required" => true}] = GenCommand.options(CommandWithOption)
  end

  test "options default to optional and string-typed" do
    assert [%{"name" => "default_option", "type" => "string", "required" => false}] = GenCommand.options(CommandWithDefaultOption)
  end

  test "commands can have multiple options" do
    assert [
      %{"name" => "my_option", "type" => "string", "required" => true},
      %{"name" => "another_option", "type" => "boolean", "required" => false},
      %{"name" => "foooooo", "type" => "string", "required" => false}
    ] == GenCommand.options(CommandWithMultipleOptions)
  end

  test "commands may require no permissions by default" do
    assert [] = TestCommand.permissions
  end

  test "can specify a single permission for a command" do
    assert ["foo"] = CommandWithPermission.permissions
  end

  test "can specify multiple permissions for a command" do
    assert ["foo", "bar", "baz"] = CommandWithMultiplePermissions.permissions
  end

  test "can specify multiple permissions for a command at once" do
    assert ["one", "two", "three"] = CommandWithMultiplePermissionsDeclaredAtOnce.permissions
  end

  test "permissions can be declared with a mix of singles and multiples" do
    assert ["a", "b", "c"] = CommandWithMixOfPermissions.permissions
  end

  test "permissions must be specified *without* a namespace" do
    contents = quote do
      use GenCommand.Base, bundle: "foo"
      permission "bundle:command" # not allowed!
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    error = catch_error(Module.create(BadPermissionCommand, contents, Macro.Env.location(__ENV__)))
    assert error.__struct__ == Spanner.GenCommand.ValidationError
    assert String.starts_with?(error.message, "Please specify permissions without the bundle namespace: `bundle:command`")

  end

  test "commands do not need to specify any rules" do
    assert [] = GenCommand.rules(TestCommand)
  end

  test "commands can specify a single rule" do
    assert ["when command is foo:command-with-rules must have foo:blah"] = GenCommand.rules(CommandWithRules)
  end

  test "commands can specify multiple rules" do
    assert ["when command is foo:command-with-multiple-rules with arg[0] == 'stuff' must have foo:admin",
            "when command is foo:command-with-multiple-rules must have foo:blah"] = GenCommand.rules(CommandWithMultipleRules)
  end

  test "can't compile without syntactically valid rules" do
    contents = quote do
      use GenCommand.Base, bundle: "foo"
      rule "not a rule, no way, no how"
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    error = catch_error(Module.create(BadRuleCommand, contents, Macro.Env.location(__ENV__)))
    assert error.__struct__ == Spanner.GenCommand.ValidationError
    assert String.starts_with?(error.message, "Bad rule for command \"badrulecommand\"")
  end

  test "can't compile if rule refers to a different command" do
    contents = quote do
      use GenCommand.Base, bundle: "foo", name: "my-name"
      rule "when command is foo:my-command must have foo:foo"
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    error = catch_error(Module.create(BadRuleCommand, contents, Macro.Env.location(__ENV__)))
    assert error.__struct__ == Spanner.GenCommand.ValidationError
    assert String.starts_with?(error.message, "Defining a rule for command \"foo:my-command\", but this command is \"my-name\"!")
  end


end
