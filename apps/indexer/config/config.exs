# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

require Logger

config :indexer,
  ecto_repos: [Explorer.Repo]

# config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :logger, :indexer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :indexer]

topics = ["evm-txs", "internal-txs", "token-transfers"]
kafka_brokers = System.get_env("KAFKA_BROKERS")
endpoints = case kafka_brokers do
  nil ->
    [{String.to_charlist("localhost"), 9092}]
  _ ->
    list_urls = kafka_brokers |> String.split(",")
    Enum.map(list_urls, fn url ->
      [ip, port] = url |> String.trim |> String.split(":")
      {ip |> String.to_charlist(), port |> String.to_integer()}
    end)
end

kafka_authen_type = System.get_env("KAFKA_AUTHEN_TYPE")
sasl = case kafka_authen_type do
  "SASL" ->
    [sasl:
      %{
        mechanism: :scram_sha_256,
        login: System.get_env("KAFKA_USER"),
        password: System.get_env("KAFKA_PASSWORD")
      }
    ]
  _ ->
    []
end

ssl = case kafka_authen_type do
  "SSL" ->
    System.put_env("KAFKA_URL", kafka_brokers)
    case File.read(System.get_env("KAFKA_TLS_CERT_PATH")) do
      {:ok, read_cert} ->
        System.put_env("KAFKA_CLIENT_CERT", read_cert)
      _ ->
        Logger.error("open #{System.get_env("KAFKA_TLS_CERT_PATH")}: no such file or directory")
    end
    case File.read(System.get_env("KAFKA_TLS_KEY_PATH")) do
      {:ok, read_key} ->
        System.put_env("KAFKA_CLIENT_CERT_KEY", read_key)
      _ ->
        Logger.error("open #{System.get_env("KAFKA_TLS_KEY_PATH")}: no such file or directory")
    end
    [heroku_kafka_env: true]
  _ ->
    []
end

producer_tmp = [
  topics: topics,

  # optional
  partition_strategy: :md5
]

producer = case kafka_authen_type do
  "SSL" ->
    producer_tmp ++ ssl
  "SASL" ->
    producer_tmp ++ sasl ++ [endpoints: endpoints] ++ [ssl: true]
  _ ->
    producer_tmp ++ [endpoints: endpoints]
end

config :kaffe,
  producer: producer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
