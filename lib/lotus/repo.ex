defmodule Lotus.Repo do
  use Ecto.Repo,
    otp_app: :lotus,
    adapter: Ecto.Adapters.Postgres
end
