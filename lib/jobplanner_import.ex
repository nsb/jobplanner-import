defmodule JobplannerImport.Client do
  @derive [Poison.Encoder]
  defstruct [:id, :business, :first_name, :last_name, :email, :phone, :notes, :properties]
end

defmodule JobplannerImport.Property do
  @derive [Poison.Encoder]
  defstruct [:id, :client, :address1, :address2, :city, :zip_code, :country]
end

defmodule JobplannerImport do
  require Logger
  alias JobplannerImport.Client
  alias JobplannerImport.Property

  # @base_url System.get_env("JOBPLANNER_API") || "https://api.myjobplanner.com/v1/"
  # @base_url "https://api.myjobplanner.com/v1/"
  @base_url "http://localhost:8000/v1/"
  @headers [{"Content-Type", "application/json"}]
  @options [
    hackney: [
      pool: :default,
      basic_auth: {"abc", "fixme"}
    ]
  ]

  def run(path) do
    HTTPoison.start()

    import_from_csv(path)
    |> post_clients()
  end

  def import_from_csv(path) do
    File.stream!(path)
    |> CSV.decode(separator: ?;, headers: true)
  end

  def post_clients(clients_data) do
    Enum.map(
      clients_data,
      fn {:ok, row} ->
        IO.puts(row["\uFEFFKontaktnavn"])
        client_name = String.split(row["\uFEFFKontaktnavn"], " ", parts: 2)

        client = %Client{
          business: 0,
          first_name: Enum.at(client_name, 0),
          last_name: Enum.at(client_name, 1),
          email: row["E-mail"],
          notes: "",
          phone: row["Telefon"],
          properties: []
        }

        property = %Property{
          address1: row["Adresse"],
          address2: "",
          city: row["By"],
          # row["Landekode"],
          country: "Danmark",
          zip_code: row["Postnummer"]
        }

        with {:ok, client_response} <- post_client(client),
             {:ok, _} <- post_property(%{property | client: client_response.id}),
             do: {:ok, client_response}
      end
    )
  end

  def post_client(client) do
    Logger.info("Posting client " <> client.first_name)

    ret = HTTPoison.post(@base_url <> "clients/", Poison.encode!(client), @headers, @options)

    case ret do
      {:ok, response} -> Poison.decode(response.body, as: %Client{})
      {:error, reason} -> IO.inspect(reason)
    end
  end

  def post_property(property) do
    Logger.info("Posting property " <> property.address1)

    ret =
      HTTPoison.post(
        @base_url <> "properties/",
        Poison.encode!(property),
        @headers,
        @options
      )

    case ret do
      {:ok, response} -> Poison.decode(response.body, as: %Property{})
      {:error, reason} -> IO.inspect(reason)
    end
  end
end
