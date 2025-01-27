defmodule MixTestWatch.PortRunner do
  @moduledoc """
  Run the tasks in a new OS process via ports
  """

  alias MixTestWatch.Config

  @doc """
  Run tests using the runner from the config.
  """
  def run(%Config{} = config) do
    command = build_tasks_cmds(config)
    env = config.env |> Atom.to_string()

    case :os.type() do
      {:win32, _} ->
        System.cmd("cmd", ["/C", "set MIX_ENV=#{env}&& mix test"], into: IO.stream(:stdio, :line))

      _ ->
        Path.join(:code.priv_dir(:mix_test_watch), "zombie_killer")
        |> System.cmd(["sh", "-c", command], into: IO.stream(:stdio, :line))
    end

    :ok
  end

  @doc """
  Build a shell command that runs the desired mix task(s).

  Colour is forced on- normally Elixir would not print ANSI colours while
  running inside a port.
  """
  def build_tasks_cmds(config = %Config{}) do
    config.tasks
    |> Enum.map(&task_command(&1, config))
    |> Enum.join(" && ")
  end

  defp task_command(task, config) do
    args = Enum.join(config.cli_args, " ")

    ansi =
      case Enum.member?(config.cli_args, "--no-start") do
        true -> "run --no-start -e 'Application.put_env(:elixir, :ansi_enabled, true);'"
        false -> "run -e 'Application.put_env(:elixir, :ansi_enabled, true);'"
      end

    env = config.env |> Atom.to_string()

    [config.cli_executable, "do", ansi <> ",", task, args]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> (fn command -> "MIX_ENV=#{env} #{command}" end).()
    |> String.trim()
  end
end
