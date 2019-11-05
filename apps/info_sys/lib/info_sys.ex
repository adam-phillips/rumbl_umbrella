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

  alias InfoSys.Cache

  @doc """
    Main entry point for service. First the cache for each backend is read
    given a query, those values are joined to the fetched results, and new
    values are written to the cache. Maps over all backends and calls
    `async_query` for each one. `yield_many` waits on all tasks, taking no more
    than a given time for execution. So results from any backends that have
    crashed or are unresponsive get ignored. Those tasks are also killed
    immediately, with only successful results worked with

    When results are received, they're sorted by score and the top results are
    returned up to a given limit
  """
  def compute(query, opts \\ []) do
    timeout = opts[:timeout] || 10_000
    opts = Keyword.put_new(opts, :limit, 10)
    backends = opts[:backends] || @backends

    {uncached_backends, cached_results} =
      fetch_cached_results(backends, query, opts)

    uncached_backends
    |> Enum.map(&async_query(&1, query, opts))
    |> Task.yield_many(timeout)
    |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)
    |> Enum.flat_map(fn
      {:ok, results} -> results
      _ -> []
    end)
    |> write_results_to_cache(query, opts)
    |> Kernel.++(cached_results)
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(opts[:limit])
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

  @doc """
    Take all backends and accumulate the cached results for a given query, as
    well as the backends that contain no cached information. This returns both
    the cached result set and the backends that need fresh queries
  """
  defp fetch_cached_results(backends, query, opts) do
    {uncached_backends, results} =
      Enum.reduce(
        backends,
        {[], []},
        fn backend, {uncached_backends, acc_results} ->
          case Cache.fetch({backend.name(), query, opts[:limit]}) do
            {:ok, results} -> {uncached_backends, [results | acc_results]}
            :error -> {[backend | uncached_backends], acc_results}
          end
        end
      )

    {uncached_backends, List.flatten(results)}
  end

  @doc """
    Write uncached results to the cache using the backend, query, and relevant
    options as the cache key
  """
  defp write_results_to_cache(results, query, opts) do
    Enum.map(results, fn %Result{backend: backend} = result ->
      :ok = Cache.put({backend.name(), query, opts[:limit]}, result)

      result
    end)
  end
end
