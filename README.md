# Searchkick

:rocket: Search made easy

Searchkick provides sensible search defaults out of the box.  It handles:

- stemming - `tomatoes` matches `tomato`
- special characters - `jalapenos` matches `jalapeños`
- extra whitespace - `dishwasher` matches `dish washer`
- misspellings - `zuchini` matches `zucchini`
- custom synonyms - `qtip` matches `cotton swab`

Runs on Elasticsearch

:tangerine: Battle-tested at [Instacart](https://www.instacart.com)

## Usage

```ruby
class Product < ActiveRecord::Base
  searchkick
end
```

And to query, use:

```ruby
Product.search "2% Milk"
```

or only search specific fields:

```ruby
Product.search "Butter", fields: [:name, :brand]
```

### Query Like SQL

```ruby
Product.search "2% Milk", where: {in_stock: true}, limit: 10, offset: 50
```

#### Where

```ruby
where: {
  expires_at: {gt: Time.now}, # lt, gte, lte also available
  orders_count: 1..10,        # equivalent to {gte: 1, lte: 10}
  store_id: {not: 2},
  aisle_id: {in: [10, 11]},
  or: [
    {in_stock: true},
    {backordered: true}
  ]
}
```

#### Order

```ruby
order: {_score: :desc} # most relevant first - default
```

#### Explain

```ruby
explain: true
```

### Facets

```ruby
Product.search "2% Milk", facets: [:store_id, :aisle_id]
```

### Synonyms

```ruby
class Product < ActiveRecord::Base
  searchkick synonyms: [["scallion", "green onion"], ["qtip", "cotton swab"]]
end
```

You must call `Product.reindex` after changing synonyms.

### Make Searches Better Over Time

Improve results with analytics on conversions and give popular documents a little boost.

First, you must keep track of search conversions.  The database works well for low volume, but feel free to use redis or another datastore.

```ruby
class Search < ActiveRecord::Base
  belongs_to :product
  # fields: id, query, searched_at, converted_at, product_id
end
```

Add the conversions to the index.

```ruby
class Product < ActiveRecord::Base
  has_many :searches

  searchkick conversions: true

  def to_indexed_json
    {
      name: name,
      conversions: searches.group("query").count.map{|query, count| {query: query, count: count} }, # TODO fix
      _boost: Math.log(orders_count) # boost more popular products a bit
    }
  end
end
```

After the reindex is complete (to prevent errors), tell the search method to use conversions.

```ruby
Product.search "Fat Free Milk", conversions: true
```

### Zero Downtime Changes

```ruby
Product.reindex
```

Behind the scenes, this creates a new index `products_20130714181054` and points the `products` alias to the new index when complete - an atomic operation :)

Searchkick uses `find_in_batches` to import documents.  To filter documents or eagar load associations, use the `searchkick_import` scope.

```ruby
class Product < ActiveRecord::Base
  scope :searchkick_import, where(active: true).includes(:searches)
end
```

There is also a rake task.

```sh
rake searchkick:reindex CLASS=Product
```

Thanks to Jaroslav Kalistsuk for the [original implementation](https://gist.github.com/jarosan/3124884).

## Elasticsearch Gotchas

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
