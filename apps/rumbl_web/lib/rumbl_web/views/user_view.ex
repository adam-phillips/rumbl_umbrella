defmodule RumblWeb.UserView do
  use RumblWeb, :view
  alias Rumbl.Accounts

  @doc """
    Return the first name of a user, split on a space if present. Return value
    is the first element of the result of the split
  """
  def first_name(%Accounts.User{name: name}) do
    name
    |> String.split(" ")
    |> Enum.at(0)
  end

  @doc """
    Template for rendering a user
  """
  def render("user.json", %{user: user}) do
    %{id: user.id, username: user.username}
  end
end
