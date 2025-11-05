defmodule Lotus.Repo do
  use AshPostgres.Repo,
    otp_app: :lotus,
    adapter: Ecto.Adapters.Postgres
end
