# Searchkick

Search made easy

## Usage

### Reindex with Zero Downtime

Elasticsearch has a feature called aliases that allows you to reindex with no downtime.

```ruby
Book.tire.reindex
```

This creates a new index `books_20130714181054` and points the `books` alias to the new index when complete - an atomic operation :)

**First time:** If books is an existing index, it will be replaced by an alias.

Searchkick uses `find_in_batches` to import documents.  To filter documents or eagar load associations, use the `tire_import` scope.

```ruby
class Book < ActiveRecord::Base
  scope :tire_import, where(active: true).includes(:author, :chapters)
end
```

There is also a rake task.

```sh
rake searchkick:reindex CLASS=Book
```

[Thanks to Jaroslav Kalistsuk for the original source](https://gist.github.com/jarosan/3124884)

#### Gotchas

When changing the mapping in a model, you must create a new index for the changes to take place.  Elasticsearch does not support updates to the mapping.  For zero downtime, use the `reindex` method above which creates a new index and swaps it in once built.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "searchkick"
```

And then execute:

```sh
bundle
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
