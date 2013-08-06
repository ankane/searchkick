# Searchkick

:rocket: Intelligent search made easy

Searchkick learns what **your users** are looking for.  As more people search, it gets smarter and the results get better.  It’s friendly for developers - and magical for your users.

Searchkick handles:

- stemming - `tomatoes` matches `tomato`
- special characters - `jalapeno` matches `jalapeño`
- extra whitespace - `dishwasher` matches `dish washer`
- misspellings - `zuchini` matches `zucchini`
- custom synonyms - `qtip` matches `cotton swab`

Plus:

- query like SQL - no need to learn a new query language
- reindex without downtime
- easily personalize results for each user [master branch]
- autocomplete [master branch]
- “Did you mean” suggestions [master branch]

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
products = Product.search "2% Milk"
products.each do |product|
  puts product.name
end
```

### Queries

Query like SQL

```ruby
Product.search "2% Milk", where: {in_stock: true}, limit: 10, offset: 50
```

Search specific fields

```ruby
fields: [:name, :brand]
```

Where

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

Order

```ruby
order: {_score: :desc} # most relevant first - default
```

Limit / offset

```ruby
limit: 20, offset: 40
```

Boost by a field

```ruby
boost: "orders_count" # give popular documents a little boost
```

### Pagination

Plays nicely with kaminari and will_paginate.

```ruby
# controller
@products = Product.search "milk", page: params[:page], per_page: 20

# view
<%= paginate @products %>
```

### Partial Matches

By default, results must match all words in the query.

```ruby
Product.search "fresh honey" # fresh AND honey
```

To change this, use:

```ruby
Product.search "fresh honey", partial: true # fresh OR honey
```

### Autocomplete [master branch]

You must specify which fields use this feature since this can increase the index size significantly.  Don’t worry - this gives you blazing faster queries.

```ruby
class Product < ActiveRecord::Base
  searchkick autocomplete: [:name]
end
```

Reindex and search with:

```ruby
Product.search "puddi", autocomplete: true
```

### Synonyms

```ruby
class Product < ActiveRecord::Base
  searchkick synonyms: [["scallion", "green onion"], ["qtip", "cotton swab"]]
end
```

Call `Product.reindex` after changing synonyms.

### Indexing

Control what data is indexed with the `search_data` method. Call `Product.reindex` after changing this method.

```ruby
class Product < ActiveRecord::Base
  def search_data
    as_json only: [:name, :active], include: {brand: {only: [:city]}}
    # or equivalently
    {
      name: name,
      active: active,
      brand: {
        city: brand.city
      }
    }
  end
end
```

Searchkick uses `find_in_batches` to import documents.  To eager load associations, use the `search_import` scope.

```ruby
class Product < ActiveRecord::Base
  scope :search_import, includes(:searches)
end
```

### Keep Getting Better

Searchkick uses conversion data to learn what users are looking for.  If a user searches for “ice cream” and adds Ben & Jerry’s Chunky Monkey to the cart (our conversion metric at Instacart), that item gets a little more weight for similar searches.

The first step is to define your conversion metric and start tracking conversions.  The database works well for low volume, but feel free to use Redis or another datastore.

```ruby
class Search < ActiveRecord::Base
  belongs_to :product
  # fields: id, query, searched_at, converted_at, product_id
end
```

Add conversions to the index.

```ruby
class Product < ActiveRecord::Base
  has_many :searches

  def search_data
    {
      name: name,
      conversions: searches.group("query").count
      # {"ice cream" => 234, "chocolate" => 67, "cream" => 2}
    }
  end
end
```

Reindex and set up a cron job to add new conversions daily.

```ruby
rake searchkick:reindex CLASS=Product
```

### Personalized Results [master branch]

**Subject to change before the next gem release**

Order results differently for each user.  For example, show a user’s previously ordered products before other results.

```ruby
class Product < ActiveRecord::Base
  def search_data
    {
      name: name,
      user_ids: orders.pluck(:user_id) # boost this product for these users
      # [4, 8, 15, 16, 23, 42]
    }
  end
end
```

Reindex and search with:

```ruby
Product.search "milk", user_id: 8
```

### Suggestions [master branch]

Did you mean: :sunglasses:

```ruby
class Product < ActiveRecord::Base
  searchkick suggest: [:name] # fields to generate suggestions
end
```

Reindex and search with:

```ruby
products = Product.search "peantu butta", suggest: true
products.suggestion # peanut butter
```

Returns `nil` when there are no suggestions.

### Facets

```ruby
products = Product.search "2% Milk", facets: [:store_id, :aisle_id]
p products.facets
```

Advanced

```ruby
Product.search "2% Milk", facets: {store_id: {where: {in_stock: true}}}
```

## Deployment

### Heroku

Choose an add-on: [SearchBox](https://addons.heroku.com/searchbox), [Bonsai](https://addons.heroku.com/bonsai), or [Found](https://addons.heroku.com/foundelasticsearch).

```sh
# SearchBox
heroku addons:add searchbox:starter

# Bonsai
heroku addons:add bonsai

# Found
heroku addons:add foundelasticsearch
```

And create an initializer `config/initializers/elasticsearch.rb` with:

```ruby
# SearchBox
ENV["ELASTICSEARCH_URL"] = ENV["SEARCHBOX_URL"]

# Bonsai
ENV["ELASTICSEARCH_URL"] = ENV["BONSAI_URL"]

# Found
ENV["ELASTICSEARCH_URL"] = ENV["FOUNDELASTICSEARCH_URL"]
```

Then deploy and reindex:

```sh
heroku run rake searchkick:reindex CLASS=Product
```

## Reference

Reindex one record

```ruby
product = Product.find 10
product.reindex
```

Use a different index name

```ruby
class Product < ActiveRecord::Base
  searchkick index_name: "products_v2"
end
```

Eagar load associations

```ruby
Product.search "milk", include: [:brand, :stores]
```

Do not load models

```ruby
Product.search "milk", load: false
```

## Migrating from Tire

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
  class Product < ActiveRecord::Base
      searchkick
  end
  ```

3. Deploy and reindex

  ```ruby
  rake searchkick:reindex CLASS=Product # or Product.reindex in the console
  ```

4. Once it finishes, replace search calls w/ searchkick calls

## Elasticsearch Gotchas

### Inconsistent Scores

Due to the distributed nature of Elasticsearch, you can get incorrect results when the number of documents in the index is low.  You can [read more about it here](http://www.elasticsearch.org/blog/understanding-query-then-fetch-vs-dfs-query-then-fetch/).  To fix this, do:

```ruby
class Product < ActiveRecord::Base
  searchkick settings: {number_of_shards: 1}
end
```

## Thanks

Thanks to Karel Minarik for [Tire](https://github.com/karmi/tire), Jaroslav Kalistsuk for [zero downtime reindexing](https://gist.github.com/jarosan/3124884), and Alex Leschenko for [Elasticsearch autocomplete](https://github.com/leschenko/elasticsearch_autocomplete).

## TODO

- Make Searchkick work with any language

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
