# NotionParser

The notion parser script will ask you for a notion url.

If this notion url is found will filter all paragraphs that have an → in its content.

Then will split the words in two properties swedish and english and we'll push the results to a database in the same page

## Requirements

You'll need an API_KEY from notion.

Check their [Getting Started Guide](https://developers.notion.com/docs/getting-started) to get your credentials

## Installation

```sh
mix deps.get
```

## Run

```sh
source .env.dev && mix run lib/notion_parser.exs
```
