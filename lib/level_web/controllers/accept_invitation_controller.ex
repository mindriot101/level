defmodule LevelWeb.AcceptInvitationController do
  use LevelWeb, :controller

  alias Level.Teams

  plug :fetch_team

  def create(conn, %{"id" => id, "user" => user_params}) do
    invitation = Teams.get_pending_invitation!(conn.assigns[:team], id)

    case Teams.accept_invitation(invitation, user_params) do
      {:ok, %{user: user}} ->
        conn
        |> LevelWeb.Auth.sign_in(invitation.team, user)
        |> redirect(to: thread_path(conn, :index))

      {:error, :user, changeset, _} ->
        conn
        |> assign(:changeset, changeset)
        |> assign(:invitation, invitation)
        |> render(LevelWeb.InvitationView, "show.html")

      _ ->
        conn
        |> put_flash(:error, "Oops! Something went wrong. Please try again.")
        |> redirect(to: invitation_path(conn, :show, invitation))
    end
  end
end