defmodule InfoSys.Wolfram do
  import SweetXml
  alias InfoSys.Result

  @doc """
    Establishes module as an implementation of InfoSys.Backend
  """
  @behaviour InfoSys.Backend

  @base "http://api.wolframalpha.com/v2/query"

  @impl true
  def name, do: "wolfram"

  @doc """
    Build pipe to take our query, fetch the XML, use the `xpath` function from
    SweetXml to extract the results, and build the results.

    The `@impl true`
    notation indicates the function as an implementation of a behaviour
  """
  @impl true
  def compute(query_str, _opts) do
    query_str
    |> fetch_xml()
    |> xpath(~x"/queryresult/pod[contains(@title, 'Result') or
                                 contains(@title, 'Definitions')]
                            /subpod/plaintext/text()")
    |> build_results()
  end

  @doc """
    Build a list of result structs, with the form depending on whether or not
    results are obtained. Matching is done on the first argument in the
    function head - if it's nil just return an empty list.

    If there is a match, build a list of Result structs with expected results
    and score, then return to the caller
  """
  defp build_results(nil), do: []

  defp build_results(answer) do
    [%Result{backend: __MODULE__, score: 95, text: to_string(answer)}]
  end

  @doc """
    Contact WolframAlpha with the query string using :httpc, part of the
    Erlang standard library. This is a straight HTTP request and it matches
    against :ok and the body that's returned to the calling client

    Look up an :http_client module from the mix config and default it to the
    :httpc module, which is available via @http module attribute
  """
  @http Application.get_env(:info_sys, :wolfram)[:http_client] || :httpc
  defp fetch_xml(query) do
    {:ok, {_, _, body}} = @http.request(String.to_charlist(url(query)))

    body
  end

  defp url(input) do
    "#{@base}?" <>
    URI.encode_query(appid: id(), input: input, format: "plaintext")
  end

  defp id, do: Application.fetch_env!(:info_sys, :wolfram)[:app_id]
end
