defmodule WebDriverClient.JSONWireProtocolClient do
  @moduledoc """
  Low-level client for JSON wire protocol (JWP).

  Use `WebDriverClient` if you'd like to support both JWP
  and W3C protocols without changing code. This module is only
  intended for use if you need JWP specific functionality.

  Specification: https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol
  """

  import WebDriverClient.CompatibilityMacros
  import WebDriverClient.JSONWireProtocolClient.Guards

  alias Tesla.Env
  alias WebDriverClient.Config
  alias WebDriverClient.Element
  alias WebDriverClient.HTTPClientError
  alias WebDriverClient.JSONWireProtocolClient.LogEntry
  alias WebDriverClient.JSONWireProtocolClient.ResponseParser
  alias WebDriverClient.Session
  alias WebDriverClient.Size
  alias WebDriverClient.TeslaClientBuilder
  alias WebDriverClient.UnexpectedResponseFormatError
  alias WebDriverClient.UnexpectedStatusCodeError

  @type url :: String.t()

  @type basic_reason ::
          HTTPClientError.t()
          | UnexpectedResponseFormatError.t()
          | UnexpectedStatusCodeError.t()

  @doc """
  Fetches the url of the current page.

  Specification: https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#sessionsessionidurl
  """
  doc_metadata subject: :navigation
  @spec fetch_current_url(Session.t()) :: {:ok, url} | {:error, basic_reason}
  def fetch_current_url(%Session{id: id, config: %Config{} = config}) when is_session_id(id) do
    client = TeslaClientBuilder.build(config)

    url = "/session/#{id}/url"

    with {:ok, %Env{body: body}} <- Tesla.get(client, url),
         {:ok, url} <- ResponseParser.parse_url(body) do
      {:ok, url}
    end
  end

  @spec fetch_window_size(Session.t()) :: {:ok, Size.t()} | {:error, basic_reason}
  def fetch_window_size(%Session{id: id, config: %Config{} = config})
      when is_session_id(id) do
    client = TeslaClientBuilder.build(config)
    window_handle = "current"

    url = "/session/#{id}/window/#{window_handle}/size"

    with {:ok, %Env{body: body}} <- Tesla.get(client, url),
         {:ok, size} <- ResponseParser.parse_size(body) do
      {:ok, size}
    end
  end

  @type size_opt :: {:width, pos_integer} | {:height, pos_integer}

  @spec set_window_size(Session.t(), [size_opt]) :: :ok | {:error, basic_reason}
  def set_window_size(%Session{id: id, config: %Config{} = config}, opts \\ [])
      when is_list(opts) do
    window_handle = "current"
    url = "/session/#{id}/window/#{window_handle}/size"

    request_body = opts |> Keyword.take([:height, :width]) |> Map.new()

    config
    |> TeslaClientBuilder.build()
    |> Tesla.post(url, request_body)
    |> case do
      {:ok, %Env{}} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @type element_location_strategy :: :css_selector | :xpath
  @type element_selector :: String.t()

  @doc """
  Finds the elements using the given search strategy

  Specification: https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#post-sessionsessionidelements
  """
  doc_metadata subject: :elements

  @spec find_elements(Session.t(), element_location_strategy, element_selector) ::
          {:ok, [Element.t()]} | {:error, basic_reason}
  def find_elements(
        %Session{id: id, config: %Config{} = config},
        element_location_strategy,
        element_selector
      )
      when is_element_location_strategy(element_location_strategy) and
             is_element_selector(element_selector) do
    client = TeslaClientBuilder.build(config)
    url = "/session/#{id}/elements"

    request_body = %{
      "using" => element_location_strategy_to_string(element_location_strategy),
      "value" => element_selector
    }

    with {:ok, %Env{body: body}} <- Tesla.post(client, url, request_body),
         {:ok, elements} <- ResponseParser.parse_elements(body) do
      {:ok, elements}
    end
  end

  @type log_type :: String.t()

  @doc """
  Fetches the available log types.

  Specification: https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#sessionsessionidlogtypes
  """
  doc_metadata subject: :logging
  @spec fetch_log_types(Session.t()) :: {:ok, [log_type]} | {:error, basic_reason()}
  def fetch_log_types(%Session{id: id, config: %Config{} = config}) do
    client = TeslaClientBuilder.build(config)
    url = "/session/#{id}/log/types"

    with {:ok, %Env{body: body}} <- Tesla.get(client, url),
         {:ok, log_types} <- ResponseParser.parse_value(body) do
      {:ok, log_types}
    end
  end

  @doc """
  Fetches the log for a given type.

  Specification: https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#sessionsessionidlog
  """
  doc_metadata subject: :logging
  @spec fetch_logs(Session.t(), log_type) :: {:ok, [LogEntry.t()]} | {:error, basic_reason()}
  def fetch_logs(%Session{id: id, config: %Config{} = config}, log_type) do
    client = TeslaClientBuilder.build(config)
    url = "/session/#{id}/log"
    request_body = %{type: log_type}

    with {:ok, %Env{body: body}} <- Tesla.post(client, url, request_body),
         {:ok, logs} <- ResponseParser.parse_log_entries(body) do
      {:ok, logs}
    end
  end

  @spec element_location_strategy_to_string(element_location_strategy) :: String.t()
  defp element_location_strategy_to_string(:css_selector), do: "css selector"
  defp element_location_strategy_to_string(:xpath), do: "xpath"
end
