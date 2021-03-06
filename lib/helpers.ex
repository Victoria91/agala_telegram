defmodule Agala.Provider.Telegram.Helpers do
  alias Agala.Provider.Telegram.Conn.Response
  @base_url "https://api.telegram.org/bot"

  defp bootstrap(bot) do
    case bot.config() do
      {:ok, bot_params} ->
        {:ok,
         Map.put(bot_params, :private, %{
           http_opts:
             (get_in(bot_params, [:provider_params, :hackney_opts]) || [])
             |> Keyword.put(
               :recv_timeout,
               get_in(bot_params, [:provider_params, :response_timeout]) || 5000
             ),
           offset: 0,
           timeout: get_in(bot_params, [:provider_params, :poll_timeout])
         })}

      error ->
        error
    end
  end

  defp base_url(route) do
    fn token -> @base_url <> token <> route end
  end

  defp create_body(map, opts) when is_map(map) do
    Map.merge(map, Enum.into(opts, %{}), fn _, v1, _ -> v1 end)
  end

  defp create_body_multipart(map, opts) when is_map(map) do
    multipart =
      create_body(map, opts)
      |> Enum.map(fn
        {key, {:file, file}} ->
          {:file, file, {"form-data", [{:name, key}, {:filename, Path.basename(file)}]}, []}

        {key, value} ->
          {to_string(key), to_string(value)}
      end)

    {:multipart, multipart}
  end

  defp body_encode(body) when is_bitstring(body) or is_tuple(body), do: body
  defp body_encode(body) when is_map(body), do: body |> Jason.encode!()
  defp body_encode(_), do: ""

  defp url_encode(%Agala.Conn{response: %{payload: %{url: url}}}, bot_params)
       when is_function(url) do
    url.(bot_params.provider_params.token)
  end

  defp perform_request(
         %Agala.Conn{
           responser: bot,
           response: %{method: method, payload: %{url: url, body: body} = payload}
         } = conn
       ) do
    {:ok, bot_params} = bootstrap(bot)

    case HTTPoison.request(
      method,
      url.(bot_params.provider_params.token),
      body_encode(body),
      Map.get(payload, :headers, []),
      Map.get(payload, :http_opts) || Map.get(bot_params.private, :http_opts) || []
    ) do
      {:ok, %HTTPoison.Response{body: body}} -> Jason.decode(body)
      error -> error
    end
  end

  @spec send_message(conn :: Agala.Conn.t(), message :: String.t(), opts :: Enum.t()) ::
          Agala.Conn.t()
  def send_message(conn, chat_id, message, opts \\ []) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/sendMessage"),
        body: create_body(%{chat_id: chat_id, text: message}, opts),
        headers: [{"Content-Type", "application/json"}]
      }
    })
    |> perform_request()
  end

  @spec delete_message(
          conn :: Agala.Conn.t(),
          chat_id :: String.t() | integer,
          message_id :: String.t() | integer
        ) :: Agala.Conn.t()
  def delete_message(conn, chat_id, message_id) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/deleteMessage"),
        body: create_body(%{chat_id: chat_id, message_id: message_id}, []),
        headers: [{"Content-Type", "application/json"}]
      }
    })
    |> perform_request()
  end

  @spec send_chat_action(
          conn :: Agala.Conn.t(),
          chat_id :: String.t() | integer,
          action :: String.t()
        ) :: Agala.Conn.t()
  def send_chat_action(conn, chat_id, action) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/sendChatAction"),
        body: create_body(%{chat_id: chat_id, action: action}, []),
        headers: [{"Content-Type", "application/json"}]
      }
    })
    |> perform_request()
  end

  def kick_chat_member(conn, chat_id, user_id, opts \\ []) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/kickChatMember"),
        body: create_body(%{chat_id: chat_id, user_id: user_id}, opts),
        headers: [{"Content-Type", "application/json"}]
      }
    })
    |> perform_request()
  end

  @spec send_photo(
          conn :: Agala.Conn.t(),
          chat_id :: String.t() | integer,
          photo :: {:file, String.t()}
        ) :: Agala.Conn.t()
  def send_photo(conn, chat_id, {:file, photo}, opts \\ []) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/sendPhoto"),
        body: create_body_multipart(%{chat_id: chat_id, photo: {:file, photo}}, opts)
      }
    })
    |> perform_request()
  end

  @spec send_document(
          conn :: Agala.Conn.t(),
          chat_id :: String.t() | integer,
          document :: {:file, String.t()}
        ) :: Agala.Conn.t()
  def send_document(conn, chat_id, {:file, document}, opts \\ []) do
    Map.put(conn, :response, %Response{
      method: :post,
      payload: %{
        url: base_url("/sendDocument"),
        body: create_body_multipart(%{chat_id: chat_id, document: {:file, document}}, opts),
        headers: []
      }
    })
    |> perform_request()
  end

  @spec get_file(conn :: Agala.Conn.t(), file_id :: String.t()) :: Agala.Conn.t()
  def get_file(conn, file_id) do
    Map.put(conn, :response, %Response{
      method: :get,
      payload: %{
        url: base_url("/getFile"),
        body: create_body(%{file_id: file_id}, []),
        headers: [{"Content-Type", "application/json"}]
      }
    })
    |> perform_request()
  end
end
