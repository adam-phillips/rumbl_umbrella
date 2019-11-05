defmodule InfoSys.Backend do
  @doc """
    Typespecs that name the functions, types of args, and return values. `name`
    takes no args and returns a string. `compute` takes a String.t query, a
    Keyword.t list of options, and returns a list of %InfoSys.Result{} structs
  """
  @callback name() :: String.t()
  @callback compute(query :: String.t(), opts :: Keyword.t()) ::
              [%InfoSys.Result{}]
end
