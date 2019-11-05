defmodule InfoSys.Counter do
  use GenServer

  @doc """
    GenServer `cast` is used to send an asynchronous message to increment or
    decrement the counter
  """
  def inc(pid), do: GenServer.cast(pid, :inc)

  def dec(pid), do: GenServer.cast(pid, :dec)

  @doc """
    Use GenServer to send synchronous messages that return the server state
  """
  def val(pid) do
    GenServer.call(pid, :val)
  end

  @doc """
    Start a GenServer, give it the current module name, and the counter. This
    spawns a new process and invokes InfoSys.Counter.init to set up initial
    state
  """
  def start_link(initial_val) do
    GenServer.start_link(__MODULE__, initial_val)
  end

  @doc """
    Handle cast for :inc or :dec to increment or decrement accordingly
  """
  def handle_cast(:inc, val) do
    {:noreply, val + 1}
  end

  def handle_cast(:dec, val) do
    {:noreply, val - 1}
  end

  @doc """
    Handle :val and specify the return value.
  """
  def handle_call(:val, _from, val) do
    {:reply, val, val}
  end
end
