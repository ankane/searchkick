# Searchkick [alpha]

:rocket: Search made easy

Searchkick provides sensible search defaults out of the box.  It handles:

- stemming - `tomatoes` matches `tomato`
- special characters - `jalapenos` matches `jalapeños`
- extra whitespace - `dishwasher` matches `dish washer`
- misspellings - `zuchini` matches `zucchini`
- custom synonyms - `qtip` matches `cotton swab`

Runs on Elasticsearch

:tangerine: Battle-tested at [Instacart](https://www.instacart.com)

## Get Started

[Install Elasticsearch](http://www.elasticsearch.org/guide/reference/setup/installation/). For Homebrew, use:

```sh
brew install elasticsearch
```

Add this line to your application’s Gemfile:

```ruby
gem "searchkick"
```

Add searchkick to models you want to search.

```ruby
class Product < ActiveRecord::Base
  searchkick
end
```

Add data to the search index.

```ruby
Product.reindex
```

And to query, use:

```ruby
search = Product.search "2% Milk"
search[:hits].each do |product|
  puts product.name
  puts product._score # added by searchkick
end
```

### Queries

Queries are just like SQL.

```ruby
Product.search "2% Milk", where: {in_stock: true}, limit: 10, offset: 50
```

Search specific fields

```ruby
fields: [:name, :brand]
```

Add conditions

```ruby
where: {
  expires_at: {gt: Time.now}, # lt, gte, lte also available
  orders_count: 1..10,        # equivalent to {gte: 1, lte: 10}
  aisle_id: [25, 30],         # in
  store_id: {not: 2},         # not
  aisle_id: {not: [25, 30]},  # not in
  or: [
    [{in_stock: true}, {backordered: true}]
  ]
}
```

Order results

```ruby
order: {_score: :desc} # most relevant first - default
```

Paginate

```ruby
limit: 50, offset: 1000
```

### Facets

```ruby
search = Product.search "2% Milk", facets: [:store_id, :aisle_id]
search[:facets].each do |facet|
  p facet # TODO
end
```

Advanced

```ruby
Product.search "2% Milk", facets: {store_id: {where: {in_stock: true}}}
```

### Synonyms

```ruby
class Product < ActiveRecord::Base
  searchkick synonyms: [["scallion", "green onion"], ["qtip", "cotton swab"]]
end
```

You must call `Product.reindex` after changing synonyms.

### Indexing

Choose what data gets indexed.

```ruby
class Product < ActiveRecord::Base
  def _source
    as_json(only: [:name, :active])
  end
end
```

Searchkick uses `find_in_batches` to import documents.  To filter documents or eagar load associations, use the `searchkick_import` scope.

```ruby
class Product < ActiveRecord::Base
  scope :searchkick_import, where(active: true).includes(:searches)
end
```

### Get Better Over Time

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

  def _source
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

### Reference

Reindex rake task

```sh
rake searchkick:reindex CLASS=Product
```

Reindex one item

```ruby
product = Product.find(1)
product.reindex
```

Partial matches (needs better name)

```ruby
Item.search "fresh honey", partial: true # matches organic honey
```

### Migrating from Tire

1. Change `search` methods to `tire.search` and add index name in existing search calls

  ```ruby
  Product.search "fruit"
  ```

  should be replaced with

  ```ruby
  Product.tire.search "fruit", index: "products"
  ```

2. Replace tire mapping w/ searchkick method

  ```ruby
  searchkick index_name: "products_v2"
  ```

3. Deploy and reindex

  ```ruby
  rake searchkick:reindex CLASS=Product # or Product.reindex in the console
  ```

4. Once it finishes, replace search calls w/ searchkick calls

## Elasticsearch Gotchas

### Inconsistent Scores

Due to the distributed nature of Elasticsearch, you can get incorrect results when the number of documents in the index is low.  You can [read more about it here](http://www.elasticsearch.org/blog/understanding-query-then-fetch-vs-dfs-query-then-fetch/).  To fix this, set the search type to `dfs_query_and_fetch`.  Alternatively, you can just use one shard with `settings: {number_of_shards: 1}`.

## TODO

- Autocomplete
- Option to turn off fuzzy matching (should this be default?)
- Option to disable callbacks
- Exact phrase matches (in order)
- Focus on results format (load: true?)
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
