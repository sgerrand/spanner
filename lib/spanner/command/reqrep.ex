defmodule Spanner.Command.Request do

  use Spanner.Marshalled

  require Logger

  defmarshalled [:room, :requestor, :command, :args, :options, :command_config, :reply_to, :cog_env]

  defp validate(request) do
    cond do
      request.room == nil ->
        {:error, {:empty_field, :room}}
      request.requestor == nil ->
        {:error, {:empty_field, :requestor}}
      request.command == nil ->
        {:error, {:empty_field, :command}}
      request.reply_to == nil ->
        {:error, {:empty_field, :reply_to}}
      true -> populate_config(request)
    end
  end

  defp populate_config(request) do
    case get_config(request) do
      {:ok, command_config} -> {:ok, %{request | command_config: command_config}}
      error -> error
    end
  end

  defp get_config(request) do
    case open_config(request) do
      {:ok, ""} -> {:ok, %{}}
      {:ok, config} -> decode_config(request, config)
      {:error, error} ->
        err = "Unable to read the command config file 'config.json' for the command '#{request.command}'. #{inspect error}"
        Logger.error(err)
        {:error, err}
    end
  end

  defp decode_config(request, config) do
    case Poison.decode(config) do
      {:ok, cmd_config} -> {:ok, cmd_config}
      {:error, error} ->
        err = "Unable to load configuration data for #{request.command}. Please verify the configuration data is in valid json format. #{inspect error}"
        Logger.error(err)
        {:error, err}
    end
  end

  defp open_config(request) do
    case Application.get_env(:spanner, :command_config_root) do
      nil -> {:ok, ""}
      path -> read_config(request, path)
    end
  end

  defp read_config(request, config_path) do
    [bundle, _cmd] = String.split(request.command, ":")
    cmd_config_file = Path.join([config_path, bundle, "config.json"])
    case File.exists?(cmd_config_file) do
      true ->
        File.open(cmd_config_file, [:read], fn(file) ->
          IO.read(file, :all)
        end)
      false -> {:ok, ""}
    end
  end

end

defmodule Spanner.Command.Response do

  use Spanner.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
