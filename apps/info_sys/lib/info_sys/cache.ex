defmodule InfoSys.Cache do
  use GenServer

  @doc """
    Handle writes to cache by calling `insert`, converting the GenServer name
    to a table name, and pass a key value pair as a tuple. Matching on a result
    of true ensures the write was successful and :ok returns
  """
  def put(name \\ __MODULE__, key, value) do
    true = :ets.insert(tab_name(name), {key, value})
    :ok
  end

  @doc """
    Fetch a value from the table with a given key, passing the one-based index
    of the value (2 in this case). Rescue the ArgumentError that ETS throws if
    trying to fetch a key that doesn't exist and translate to an :error value
  """
  def fetch(name \\ __MODULE__, key) do
    {:ok, :ets.lookup_element(tab_name(name), key, 2)}
  rescue
    ArgumentError -> :error
  end

  @doc """
    Ensure a name options is present to be used to name the GenServer. This is
    defaulted to the module name, allowing for the use of a generic single
    cache for now
  """
  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
    Build a map of state with the table, a timer, and an interval for clearing
    the cache - defaulted here to 60 seconds
  """
  @clear_interval :timer.seconds(60)

  def init(opts) do
    state = %{
      interval: opts[:clear_interval] || @clear_interval,
      timer: nil,
      table: new_table(opts[:name])
    }

    {:ok, schedule_clear(state)}
  end

  @doc """
    Clear the cache by deleting all objects, then reschedule the next clearing
  """
  def handle_info(:clear, state) do
    :ets.delete_all_objects(state.table)
    {:noreply, schedule_clear(state)}
  end

  @doc """
    After the interval milliseconds from the state have passed, send the
    process a message
  """
  defp schedule_clear(state) do
    %{state | timer: Process.send_after(self(), :clear, state.interval)}
  end

  @doc """
    Pass the name and a list of options to :ets.new. :set is a type of ETS
    table that acts as a key-value store, :named_table allows for location by
    name, :public lets processes other than the owner read and write, and
    read/write concurrency allows for concurrent workloads to boost performance
  """
  defp new_table(name) do
    name
    |> tab_name()
    |> :ets.new([
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true])
  end

  @doc """
    Returns an atom of the table name to use for the ETS table
  """
  defp tab_name(name), do: :"#{name}_cache"
end
