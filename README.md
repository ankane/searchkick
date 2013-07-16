# Searchkick

Search made easy

## Usage

Searchkick provides sensible search defaults out of the box.  It handles:

- stemming - `tomatoes` matches `tomato`
- special characters - `jalapenos` matches `jalapeños`
- extra whitespace - `dishwasher` matches `dish washer`
- misspellings - `zuchini` matches `zucchini`
- custom synonyms - `qtip` matches `cotton swab`

```ruby
class Book < ActiveRecord::Base
  searchkick :name
end
```

And to query, use:

```ruby
Book.search("Nobody Listens to Andrew")
```

**Note:** We recommend reindexing when changing synonyms for best results.

### Make Searches Better Over Time

Use analytics on search conversions to improve results.

Also, give popular documents a little boost.

Keep track of searches.  The database works well for low volume, but feel free to use redis or another datastore.

```ruby
class Search < ActiveRecord::Base
  belongs_to :item
  # fields: id, query, searched_at, converted_at, item_id
end
```

Add the conversions to the index.

```ruby
class Book < ActiveRecord::Base
  has_many :searches

  tire do
    settings Searchkick.settings
    mapping do
      indexes :title, analyzer: "searchkick"
      indexes :conversions, type: "nested" do
        indexes :query, analyzer: "searchkick_keyword"
        indexes :count, type: "integer"
      end
    end
  end

  def to_indexed_json
    {
      title: title,
      conversions: searches.group("query").count.map{|query, count| {query: query, count: count} }, # TODO fix
      _boost: Math.log(copies_sold_count) # boost more popular books a bit
    }
  end
end
```

After the reindex is complete (to prevent errors), tell the search query to use conversions.

```ruby
Book.search do
  searchkick_query ["title"], "Nobody Listens to Andrew", true
end
```

### Zero Downtime Changes

Elasticsearch has a feature called aliases that allows you to change mappings with no downtime.

```ruby
Book.reindex
```

This creates a new index `books_20130714181054` and points the `books` alias to the new index when complete - an atomic operation :)

**First time:** If books is an existing index, it will be replaced by an alias.

Searchkick uses `find_in_batches` to import documents.  To filter documents or eagar load associations, use the `searchkick_import` scope.

```ruby
class Book < ActiveRecord::Base
  scope :searchkick_import, where(active: true).includes(:author, :chapters)
end
```

There is also a rake task.

```sh
rake searchkick:reindex CLASS=Book
```

Thanks to Jaroslav Kalistsuk for the [original implementation](https://gist.github.com/jarosan/3124884) and Clinton Gormley for a [good post](http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/) on this.

## Elasticsearch Gotchas

### Mappings

When changing the mapping in a model, you must create a new index for the changes to take place.  Elasticsearch does not support updates to mappings.  For zero downtime, use the `reindex` method above, which creates a new index and swaps it in after it's built.  To view the current mapping, use:

```sh
curl "http://localhost:9200/books/_mapping?pretty=1"
```

### Inconsistent Scores

Due to the distributed nature of Elasticsearch, you can get incorrect results when the number of documents in the index is low.  You can [read more about it here](http://www.elasticsearch.org/blog/understanding-query-then-fetch-vs-dfs-query-then-fetch/).  To fix this, set the search type to `dfs_query_and_fetch`.  Alternatively, you can just use one shard with `settings: {number_of_shards: 1}`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "searchkick"
```

And then execute:

```sh
bundle
```

## TODO

- Test helpers - everyone should test their own search
- Searchkick w/o Tire (Elasticsearch JSON)
- Built-in synonyms from WordNet
- Dashboard w/ real-time analytics?
- [Suggest API](http://www.elasticsearch.org/guide/reference/api/search/suggest/) "Did you mean?"
- Allow for "exact search" with quotes
- Make updates to old and new index while reindexing [possibly with an another alias](http://www.kickstarter.com/backing-and-hacking)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
