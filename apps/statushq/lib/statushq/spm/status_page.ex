defmodule Statushq.SPM.StatusPage do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Statushq.Validators
  import WithPro
  import Ecto.Changeset
  with_pro do: use StatushqPro.SPM.StatusPage

  alias Statushq.Accounts.{UserStatusPage, User}
  alias Statushq.SPM.{Services.Service}

  @derive {Phoenix.Param, key: :subdomain}

  schema "status_pages" do
    field :name, :string
    field :url, :string
    field :subdomain, :string
    field :domain, :string
    with_pro do: StatushqPro.SPM.StatusPage.schema
    field :logo, StatushqWeb.Logo.Type
    field :time_zone, :string

    # design
    field :header_bg_color1, :string
    field :header_bg_color2, :string
    field :header_fg_color, :string
    field :incident_link_color, :string
    field :incident_header_color, :string
    field :display_uptime_graph, :boolean

    # twitter oauth
    field :twitter_screen_name, :string
    field :twitter_oauth_token, :string
    field :twitter_oauth_token_secret, :string

    has_many :users_status_pages, UserStatusPage, on_delete: :delete_all
    has_many :services, Service, on_delete: :delete_all
    many_to_many :users, User, join_through: UserStatusPage

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :domain, :subdomain, :time_zone, :logo, :header_bg_color1,
      :header_bg_color2, :header_fg_color, :incident_link_color, :incident_header_color,
      :display_uptime_graph])
    |> validate_required([:name, :url, :subdomain])
    |> cast_attachments(params, ~w(logo))
    |> cast_remove_logo(params)
    |> validate
  end

  def creation_changeset(struct, params \\ %{}, user_id) do
    member_cs = UserStatusPage.status_page_creation_changeset(
      %UserStatusPage{user_id: user_id, role: "o"}
    )
    service_cs = Service.changeset(%Service{name: "Web"})

    struct
    |> cast(params, [:name, :url, :subdomain, :time_zone])
    |> generate_subdomain_ce()
    |> validate_required([:name, :url, :subdomain, :time_zone])
    |> put_assoc(:users_status_pages, [member_cs])
    |> put_assoc(:services, [service_cs])
    |> validate
  end

  def twitter_oauth_changeset(struct, params) do
    struct
    |> cast(params, [:twitter_screen_name, :twitter_oauth_token, :twitter_oauth_token_secret])
  end

  def avatar_changeset(page, params) do
    page |> cast_attachments(params, ~w(logo), ~w())
  end

  def validate(page) do
    page
    |> validate_url(:url)
    |> unique_constraint(:subdomain)
    |> unique_constraint(:url)
    |> unique_constraint(:name)
  end

  def cast_remove_logo(struct, params) do
    if params["remove_logo"] == "true", do: put_change(struct, :logo, nil), else: struct
  end

  def generate_subdomain_ce(changeset) do
    if !WithPro.pro?() && !Map.has_key?(changeset.changes, :subdomain) do
      subdomain = changeset.changes.name
      |> String.normalize(:nfd)
      |> String.replace(~r/\W/u, "")
      |> URI.encode()
      put_change(changeset, :subdomain, subdomain)
    else
      changeset
    end
  end
end
