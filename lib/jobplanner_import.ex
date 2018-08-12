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

  @base_url System.get_env("JOBPLANNER_API") || "https://api.myjobplanner.com/v1/"
  @headers [{"Content-Type", "application/json"}]
  @options [
    hackney: [
      basic_auth: {System.get_env("JOBPLANNER_USERNAME"), System.get_env("JOBPLANNER_PASSWORD")}
    ]
  ]

  def run(path) do
    HTTPoison.start()

    import_from_csv(path)
    |> post_clients()
  end

  def import_from_csv(path) do
    File.stream!(path)
    |> CSV.decode(headers: true)
  end

  def post_clients(clients_data) do
    Enum.map(
      clients_data,
      fn {:ok, row} ->
        client = %Client{
          business: 1,
          first_name: row["First Name"],
          last_name: row["Last Name"],
          email: row["E-mails"],
          notes: "",
          phone: row["Main Phone #s"],
          properties: []
        }

        property = %Property{
          address1: row["Service Street 1"],
          address2: row["Service Street 2"],
          city: row["Service City"],
          country: row["Service Country"],
          zip_code: row["Service Postcode"]
        }

        with {:ok, client_response} <- post_client(client),
             {:ok, _} <- post_property(%{property | client: client_response.id}),
             do: {:ok, client_response}
      end
    )
  end

  def post_client(client) do
    Logger.info("Posting client " <> client.first_name)

    {:ok, response} =
      HTTPoison.post(@base_url <> "clients/", Poison.encode!(client), @headers, @options)

    Poison.decode(response.body, as: %Client{})
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
