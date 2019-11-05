defmodule InfoSys.Counter do
  def inc(pid), do: send(pid, :inc)

  def dec(pid), do: send(pid, :dec)

  @doc """
    Send a request for the value of the counter by creating a unique reference,
    and send a message to the counter with the command, pid, and reference.
    Await a response matching the exact ref and if there is no match then exit
    the current process with :timeout
  """
  def val(pid, timeout \\ 5000) do
    ref = make_ref() # make_ref/0 is an Erlang function
    send(pid, {:val, self(), ref})

    receive do
      {^ref, val} -> val
    after
      timeout -> exit(:timeout)
    end
  end

  @doc """
    Required by OTP; accept the initial state of the counter, spawn a process,
    and return :ok and the pid identifying the newly spawned process. The
    spawned process calls the private `listen` function, listening for
    messages to process
  """
  def start_link(initial_val) do
    {:ok, spawn_link(fn -> listen(initial_val) end)}
  end

  defp listen(val) do
    receive do
      :inc ->
        listen(val + 1)

      :dec ->
        listen(val - 1)

      {:val, sender, ref} ->
        send(sender, {ref, val})
        listen(val)
    end
  end
end
