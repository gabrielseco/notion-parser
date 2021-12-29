defmodule NotionUrlId do
  @moduledoc """
  Should parse a notion url and raise an error if it's not correct
  """
  def call(notion_url) do
    notion_url |> String.trim() |> String.split("-") |> List.last()
  end
end

defmodule NotionHttpClient do
  @notion_api_key System.get_env("NOTION_API_KEY")

  @moduledoc """
    HttpClient to call the notion api
  """
  use Tesla

  adapter(Tesla.Adapter.Hackney, recv_timeout: 30_000)

  plug(Tesla.Middleware.BaseUrl, "https://api.notion.com/v1/")

  plug(Tesla.Middleware.Headers, [
    # Need to config the Authorization tokens
    {"Authorization", "Bearer #{@notion_api_key}"},
    {"Notion-Version", "2021-05-11"}
  ])

  plug(Tesla.Middleware.JSON)

  def get_page(id) do
    get("/pages/" <> id)
  end

  def get_blocks(id) do
    get("/blocks/" <> id)
  end

  def get_blocks_children(id) do
    get("/blocks/" <> id <> "/children")
  end

  def create_database(page_id, title) do
    post("/databases", %{
      parent: %{type: "page_id", page_id: page_id},
      title: [%{type: "text", text: %{content: title, link: nil}}],
      properties: %{
        Swedish: %{title: %{}},
        English: %{rich_text: %{}},
        Fonetic: %{rich_text: %{}}
      }
    })
  end

  def populate_database(database_id, params) do
    IO.inspect(params)

    %{english_word: english_word, swedish_word: swedish_word} = params

    post("/pages", %{
      parent: %{type: "database_id", database_id: database_id},
      properties: %{
        Swedish: %{title: [%{type: "text", text: %{content: swedish_word}}]},
        English: %{
          rich_text: [%{type: "text", text: %{content: english_word}}]
        },
        Fonetic: %{
          rich_text: [%{type: "text", text: %{content: ""}}]
        }
      }
    })
  end
end

defmodule ParseContent do
  def filter_empty(result) do
    case result do
      [] -> nil
      _ -> result
    end
  end

  def detect_words(result) do
    case :binary.match(result, "→") do
      :nomatch -> nil
      _ -> result
    end
  end
end

defmodule NormalizeContent do
  def normalize(result) do
    [swedish_word, english_word] = String.split(result, "→")

    %{swedish_word: String.trim(swedish_word), english_word: String.trim(english_word)}
  end
end

defmodule NotionParser do
  @moduledoc """
  Documentation for `NotionParser`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> NotionParser.hello()
      :world

  """
  def main do
    # Ask for a notion url

    notion_url = IO.gets("Give me notion url: ")

    IO.puts(notion_url)

    page_id = NotionUrlId.call(notion_url)

    IO.puts(page_id)

    response =
      case NotionHttpClient.get_blocks_children(page_id) do
        {:ok, response} -> response
        {:error, error_message} -> IO.inspect(error_message)
      end

    IO.inspect(response)

    ## detect if the response gives an error
    response =
      cond do
        response.body["status"] >= 200 && response.body["status"] >= 503 ->
          response

        response.body["status"] == 404 ->
          throw("You forgot to give permissions to this page")

        true ->
          throw(
            "There's been an error while searching this page, status code #{response.body["status"]}"
          )
      end

    # get content

    results = response.body["results"]

    # filter paragraphs blocks
    # filter paragraphs with the structure word -> word

    paragraphs =
      Enum.filter(results, fn result ->
        result["type"] == "paragraph" && !result["has_children"] &&
          ParseContent.filter_empty(result["paragraph"]["text"]) &&
          ParseContent.detect_words(Enum.at(result["paragraph"]["text"], 0)["plain_text"])
      end)

    # Make an array of content
    # normalize content

    paragraphs =
      Enum.map(paragraphs, fn result ->
        Enum.at(result["paragraph"]["text"], 0)["plain_text"] |> NormalizeContent.normalize()
      end)

    # create notion database
    db_response =
      case NotionHttpClient.create_database(page_id, "Vocabulary") do
        {:ok, response} -> response
        {:error, error_message} -> IO.inspect(error_message)
      end

    db_id = db_response.body["id"]

    IO.inspect(db_id, label: "POPULATE")

    # populate notion database

    Enum.map(paragraphs, fn result ->
      case NotionHttpClient.populate_database(db_id, result) do
        {:ok, response} -> response
        {:error, error_message} -> IO.inspect(error_message)
      end
    end)
  catch
    error -> IO.puts(error)
  end
end

NotionParser.main()
