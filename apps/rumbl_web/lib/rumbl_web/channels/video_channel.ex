defmodule RumblWeb.VideoChannel do
  use RumblWeb, :channel
  alias Rumbl.{Accounts, Multimedia}
  alias RumblWeb.AnnotationView

  @doc """
    Join the Video channel, matching the video_id. Assign the socket and
    video_id. Fetch the video from the Multimedia context, list its
    annotations and use them to build a list and render each list item. The
    AnnotationView serves as each individual annotation. Accept a
    `last_seen_id` from the client representing the id of the last annotation
    seen, or use 0 as a default. Use this value when retrieving needed
    annotations from the Multimedia context
  """
  def join("videos:" <> video_id, params, socket) do
    send(self(), :after_join)
    last_seen_id = params["last_seen_id"] || 0
    video_id = String.to_integer(video_id)
    video = Multimedia.get_video!(video_id)

    annotations =
      video
      |> Multimedia.list_annotations(last_seen_id)
      |> Phoenix.View.render_many(AnnotationView, "annotation.json")

    {:ok, %{annotations: annotations}, assign(socket, :video_id, video_id)}
  end

  @doc """
    Handle after user joins. Pass a socket, key to track, and a map of
    metadata. The key to track is is a unique user identity - in this case a
    user_id. Browser is hardcoded as the device as Rumbl only supports web
    clients currently. Finally, return the socket unchanged - this function
    only tracks users as they come and go and passes those messages to the
    client
  """
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", RumblWeb.Presence.list(socket))
    {:ok, _} = RumblWeb.Presence.track(
      socket,
      socket.assigns.user_id,
      %{device: "browser"})
    {:noreply, socket}
  end

  @doc """
    Fetch User to ensure all incoming events have the current user, then
    include it in call to the 4 param `handle_in` function
  """
  def handle_in(event, params, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    handle_in(event, params, user, socket)
  end

  @doc """
    Call `annotate_video` and if annotation is successfully added,
    broadcast to all users, including user that added it. Otherwise, return
    changeset errors
  """
  def handle_in("new_annotation", params, user, socket) do
    case Multimedia.annotate_video(user, socket.assigns.video_id, params) do
      {:ok, annotation} ->
        broadcast!(socket, "new_annotation", %{
          id: annotation.id,
          user: RumblWeb.UserView.render("user.json", %{user: user}),
          body: annotation.body,
          at: annotation.at
        })
        {:reply, :ok, socket}

        {:error, changeset} ->
          {:reply, {:error, %{errors: changeset}}, socket}
    end
  end
end
