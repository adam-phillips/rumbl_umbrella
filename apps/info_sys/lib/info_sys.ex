defmodule InfoSys do
  @moduledoc"""
    Generic module to spawn computations for queries
  """

  @backends [InfoSys.Wolfram]

  @doc """
    Struct for holding each search result with a score for relevance, text to
    describe the result, and the backend to use for the computation
  """
  defmodule Result do
    defstruct score: 0, text: nil, backend: nil
  end

  @doc """
    Main entry point for service. Maps over all backends and calls
    `async_query` for each one
  """
  def compute(query, opts \\ []) do
    opts = Keyword.put_new(opts, :limit, 10)
    backends = opts[:backends] || @backends

    backends
    |> Enum.map(&async_query(&1, query, opts))
  end

  @doc """
    Spawns a task to do the work. Invoking the task requires the module,
    function, and args.`.async_nolink` spawns the new task in a new process,
    calling the specified function. Query and limit attributes are also
    included. `async_nolink` spawns the task in isolation from the caller so
    clients don't need to worry about a crash or unexpected error
  """
  defp async_query(backend, query, opts) do
    Task.Supervisor.async_nolink(InfoSys.TaskSupervisor, backend, :compute,
      [query, opts], shutdown: :brutal_kill)
  end
end
