# Searchkick

:rocket: Intelligent search made easy

**Searchkick learns what your users are looking for.** As more people search, it gets smarter and the results get better. It’s friendly for developers - and magical for your users.

Searchkick handles:

- stemming - `tomatoes` matches `tomato`
- special characters - `jalapeno` matches `jalapeño`
- extra whitespace - `dishwasher` matches `dish washer`
- misspellings - `zuchini` matches `zucchini`
- custom synonyms - `qtip` matches `cotton swab`

Plus:

- query like SQL - no need to learn a new query language
- reindex without downtime
- easily personalize results for each user
- autocomplete
- “Did you mean” suggestions
- supports many languages
- works with ActiveRecord, Mongoid, and NoBrainer

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/searchkick.svg?branch=master)](https://travis-ci.org/ankane/searchkick)

## Contents

- [Getting Started](#getting-started)
- [Querying](#querying)
- [Indexing](#indexing)
- [Instant Search / Autocomplete](#instant-search--autocomplete)
- [Aggregations](#aggregations)
- [Deployment](#deployment)
- [Performance](#performance)
- [Elasticsearch DSL](#advanced)
- [Reference](#reference)
- [Testing](#testing)

## Getting Started

[Install Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/setup.html). For Homebrew, use:

```sh
brew install elasticsearch
brew services start elasticsearch
```

Add this line to your application’s Gemfile:

```ruby
gem 'searchkick'
```

The latest version works with Elasticsearch 6 and 7. For Elasticsearch 5, use version 3.1.3 and [this readme](https://github.com/ankane/searchkick/blob/v3.1.3/README.md).

Add searchkick to models you want to search.

```ruby
class Product < ApplicationRecord
  searchkick
end
```

Add data to the search index.

```ruby
Product.reindex
```

And to query, use:

```ruby
products = Product.search("apples")
products.each do |product|
  puts product.name
end
```

Searchkick supports the complete [Elasticsearch Search API](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-search.html). As your search becomes more advanced, we recommend you use the [Elasticsearch DSL](#advanced) for maximum flexibility.

## Querying

Query like SQL

```ruby
Product.search "apples", where: {in_stock: true}, limit: 10, offset: 50
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
  user_ids: {all: [1, 3]},    # all elements in array
  category: /frozen .+/,      # regexp
  _or: [{in_stock: true}, {backordered: true}]
}
```

Order

```ruby
order: {_score: :desc} # most relevant first - default
```

[All of these sort options are supported](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-sort.html)

Limit / offset

```ruby
limit: 20, offset: 40
```

Select

```ruby
select: [:name]
```

[These source filtering options are supported](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-source-filtering.html)

### Results

Searches return a `Searchkick::Results` object. This responds like an array to most methods.

```ruby
results = Product.search("milk")
results.size
results.any?
results.each { |result| ... }
```

By default, ids are fetched from Elasticsearch and records are fetched from your database. To fetch everything from Elasticsearch, use:

```ruby
Product.search("apples", load: false)
```

Get total results

```ruby
results.total_count
```

Get the time the search took (in milliseconds)

```ruby
results.took
```

Get the full response from Elasticsearch

```ruby
results.response
```

### Boosting

Boost important fields

```ruby
fields: ["title^10", "description"]
```

Boost by the value of a field (field must be numeric)

```ruby
boost_by: [:orders_count] # give popular documents a little boost
boost_by: {orders_count: {factor: 10}} # default factor is 1
```

Boost matching documents

```ruby
boost_where: {user_id: 1}
boost_where: {user_id: {value: 1, factor: 100}} # default factor is 1000
boost_where: {user_id: [{value: 1, factor: 100}, {value: 2, factor: 200}]}
```

Boost by recency

```ruby
boost_by_recency: {created_at: {scale: "7d", decay: 0.5}}
```

You can also boost by:

- [Conversions](#keep-getting-better)
- [Distance](#boost-by-distance)

### Get Everything

Use a `*` for the query.

```ruby
Product.search "*"
```

### Pagination

Plays nicely with kaminari and will_paginate.

```ruby
# controller
@products = Product.search "milk", page: params[:page], per_page: 20
```

View with kaminari

```erb
<%= paginate @products %>
```

View with will_paginate

```erb
<%= will_paginate @products %>
```

### Partial Matches

By default, results must match all words in the query.

```ruby
Product.search "fresh honey" # fresh AND honey
```

To change this, use:

```ruby
Product.search "fresh honey", operator: "or" # fresh OR honey
```

By default, results must match the entire word - `back` will not match `backpack`. You can change this behavior with:

```ruby
class Product < ApplicationRecord
  searchkick word_start: [:name]
end
```

And to search (after you reindex):

```ruby
Product.search "back", fields: [:name], match: :word_start
```

Available options are:

Option | Matches | Example
--- | --- | ---
`:word` | entire word | `apple` matches `apple`
`:word_start` | start of word | `app` matches `apple`
`:word_middle` | any part of word | `ppl` matches `apple`
`:word_end` | end of word | `ple` matches `apple`
`:text_start` | start of text | `gre` matches `green apple`, `app` does not match
`:text_middle` | any part of text | `een app` matches `green apple`
`:text_end` | end of text | `ple` matches `green apple`, `een` does not match

The default is `:word`. The most matches will happen with `:word_middle`.

### Exact Matches

To match a field exactly (case-sensitive), use:

```ruby
User.search query, fields: [{email: :exact}, :name]
```

### Phrase Matches

To only match the exact order, use:

```ruby
User.search "fresh honey", match: :phrase
```

### Language

Searchkick defaults to English for stemming. To change this, use:

```ruby
class Product < ApplicationRecord
  searchkick language: "german"
end
```

[See the list of stemmers](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-stemmer-tokenfilter.html)

A few languages require plugins:

- `chinese` - [analysis-ik plugin](https://github.com/medcl/elasticsearch-analysis-ik)
- `japanese` - [analysis-kuromoji plugin](https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-kuromoji.html)
- `korean` - [analysis-openkoreantext plugin](https://github.com/open-korean-text/elasticsearch-analysis-openkoreantext)
- `polish` - [analysis-stempel plugin](https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-stempel.html)
- `ukrainian` - [analysis-ukrainian plugin](https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-ukrainian.html)
- `vietnamese` - [analysis-vietnamese plugin](https://github.com/duydo/elasticsearch-analysis-vietnamese)

### Synonyms

```ruby
class Product < ApplicationRecord
  searchkick synonyms: [["burger", "hamburger"], ["sneakers", "shoes"]]
end
```

Call `Product.reindex` after changing synonyms.

Synonyms cannot be multiple words at the moment.

To read synonyms from a file, use:

```ruby
synonyms: -> { CSV.read("/some/path/synonyms.csv") }
```

For directional synonyms, use:

```ruby
synonyms: ["lightbulb => halogenlamp"]
```

### Tags and Dynamic Synonyms

The above approach works well when your synonym list is static, but in practice, this is often not the case. When you analyze search conversions, you often want to add new synonyms or tags without a full reindex. You can use a library like [ActsAsTaggableOn](https://github.com/mbleigh/acts-as-taggable-on) and do:

```ruby
class Product < ApplicationRecord
  acts_as_taggable
  scope :search_import, -> { includes(:tags) }

  def search_data
    {
      name_tagged: "#{name} #{tags.map(&:name).join(" ")}"
    }
  end
end
```

Search with:

```ruby
Product.search query, fields: [:name_tagged]
```

### Misspellings

By default, Searchkick handles misspelled queries by returning results with an [edit distance](https://en.wikipedia.org/wiki/Levenshtein_distance) of one.

You can change this with:

```ruby
Product.search "zucini", misspellings: {edit_distance: 2} # zucchini
```

To prevent poor precision and improve performance for correctly spelled queries (which should be a majority for most applications), Searchkick can first perform a search without misspellings, and if there are too few results, perform another with them.

```ruby
Product.search "zuchini", misspellings: {below: 5}
```

If there are fewer than 5 results, a 2nd search is performed with misspellings enabled. The result of this query is returned.

Turn off misspellings with:

```ruby
Product.search "zuchini", misspellings: false # no zucchini
```

Specify which fields can include misspellings with:

```ruby
Product.search "zucini", fields: [:name, :color], misspellings: {fields: [:name]}
```

> When doing this, you must also specify fields to search

### Bad Matches

If a user searches `butter`, they may also get results for `peanut butter`. To prevent this, use:

```ruby
Product.search "butter", exclude: ["peanut butter"]
```

You can map queries and terms to exclude with:

```ruby
exclude_queries = {
  "butter" => ["peanut butter"],
  "cream" => ["ice cream", "whipped cream"]
}

Product.search query, exclude: exclude_queries[query]
```

You can demote results by boosting by a factor less than one:

```ruby
Product.search("butter", boost_where: {category: {value: "pantry", factor: 0.5}})
```

### Emoji

Search :ice_cream::cake: and get `ice cream cake`!

Add this line to your application’s Gemfile:

```ruby
gem 'gemoji-parser'
```

And use:

```ruby
Product.search "🍨🍰", emoji: true
```

## Indexing

Control what data is indexed with the `search_data` method. Call `Product.reindex` after changing this method.

```ruby
class Product < ApplicationRecord
  belongs_to :department

  def search_data
    {
      name: name,
      department_name: department.name,
      on_sale: sale_price.present?
    }
  end
end
```

Searchkick uses `find_in_batches` to import documents. To eager load associations, use the `search_import` scope.

```ruby
class Product < ApplicationRecord
  scope :search_import, -> { includes(:department) }
end
```

By default, all records are indexed. To control which records are indexed, use the `should_index?` method together with the `search_import` scope.

```ruby
class Product < ApplicationRecord
  scope :search_import, -> { where(active: true) }

  def should_index?
    active # only index active records
  end
end
```

If a reindex is interrupted, you can resume it with:

```ruby
Product.reindex(resume: true)
```

For large data sets, try [parallel reindexing](#parallel-reindexing).

### To Reindex, or Not to Reindex

#### Reindex

- when you install or upgrade searchkick
- change the `search_data` method
- change the `searchkick` method

#### No need to reindex

- app starts

### Stay Synced

There are four strategies for keeping the index synced with your database.

1. Inline (default)

  Anytime a record is inserted, updated, or deleted

2. Asynchronous

  Use background jobs for better performance

  ```ruby
  class Product < ApplicationRecord
    searchkick callbacks: :async
  end
  ```

  Jobs are added to a queue named `searchkick`.

3. Queuing

  Push ids of records that need updated to a queue and reindex in the background in batches. This is more performant than the asynchronous method, which updates records individually. See [how to set up](#queuing).

4. Manual

  Turn off automatic syncing

  ```ruby
  class Product < ApplicationRecord
    searchkick callbacks: false
  end
  ```

You can also do bulk updates.

```ruby
Searchkick.callbacks(:bulk) do
  User.find_each(&:update_fields)
end
```

Or temporarily skip updates.

```ruby
Searchkick.callbacks(false) do
  User.find_each(&:update_fields)
end
```

#### Associations

Data is **not** automatically synced when an association is updated. If this is desired, add a callback to reindex:

```ruby
class Image < ApplicationRecord
  belongs_to :product

  after_commit :reindex_product

  def reindex_product
    product.reindex
  end
end
```

### Analytics

The best starting point to improve your search **by far** is to track searches and conversions.

[Searchjoy](https://github.com/ankane/searchjoy) makes it easy.

```ruby
Product.search "apple", track: {user_id: current_user.id}
```

[See the docs](https://github.com/ankane/searchjoy) for how to install and use.

Focus on:

- top searches with low conversions
- top searches with no results

### Keep Getting Better

Searchkick can use conversion data to learn what users are looking for. If a user searches for “ice cream” and adds Ben & Jerry’s Chunky Monkey to the cart (our conversion metric at Instacart), that item gets a little more weight for similar searches.

The first step is to define your conversion metric and start tracking conversions. The database works well for low volume, but feel free to use Redis or another datastore.

Searchkick automatically treats `apple` and `APPLE` the same.

Next, add conversions to the index.

```ruby
class Product < ApplicationRecord
  has_many :searches, class_name: "Searchjoy::Search", as: :convertable

  searchkick conversions: [:conversions] # name of field

  def search_data
    {
      name: name,
      conversions: searches.group(:query).uniq.count(:user_id)
      # {"ice cream" => 234, "chocolate" => 67, "cream" => 2}
    }
  end
end
```

Reindex and set up a cron job to add new conversions daily.

```ruby
rake searchkick:reindex CLASS=Product
```

**Note:** For a more performant (but more advanced) approach, check out [performant conversions](#performant-conversions).

### Personalized Results

Order results differently for each user. For example, show a user’s previously purchased products before other results.

```ruby
class Product < ApplicationRecord
  def search_data
    {
      name: name,
      orderer_ids: orders.pluck(:user_id) # boost this product for these users
    }
  end
end
```

Reindex and search with:

```ruby
Product.search "milk", boost_where: {orderer_ids: current_user.id}
```

### Instant Search / Autocomplete

Autocomplete predicts what a user will type, making the search experience faster and easier.

![Autocomplete](https://gist.github.com/ankane/b6988db2802aca68a589b31e41b44195/raw/40febe948427e5bc53ec4e5dc248822855fef76f/autocomplete.png)

**Note:** To autocomplete on general categories (like `cereal` rather than product names), check out [Autosuggest](https://github.com/ankane/autosuggest).

**Note 2:** If you only have a few thousand records, don’t use Searchkick for autocomplete. It’s *much* faster to load all records into JavaScript and autocomplete there (eliminates network requests).

First, specify which fields use this feature. This is necessary since autocomplete can increase the index size significantly, but don’t worry - this gives you blazing faster queries.

```ruby
class Movie < ApplicationRecord
  searchkick word_start: [:title, :director]
end
```

Reindex and search with:

```ruby
Movie.search "jurassic pa", fields: [:title], match: :word_start
```

Typically, you want to use a JavaScript library like [typeahead.js](https://twitter.github.io/typeahead.js/) or [jQuery UI](https://jqueryui.com/autocomplete/).

#### Here’s how to make it work with Rails

First, add a route and controller action.

```ruby
class MoviesController < ApplicationController
  def autocomplete
    render json: Movie.search(params[:query], {
      fields: ["title^5", "director"],
      match: :word_start,
      limit: 10,
      load: false,
      misspellings: {below: 5}
    }).map(&:title)
  end
end
```

**Note:** Use `load: false` and `misspellings: {below: n}` (or `misspellings: false`) for best performance.

Then add the search box and JavaScript code to a view.

```html
<input type="text" id="query" name="query" />

<script src="jquery.js"></script>
<script src="typeahead.bundle.js"></script>
<script>
  var movies = new Bloodhound({
    datumTokenizer: Bloodhound.tokenizers.whitespace,
    queryTokenizer: Bloodhound.tokenizers.whitespace,
    remote: {
      url: '/movies/autocomplete?query=%QUERY',
      wildcard: '%QUERY'
    }
  });
  $('#query').typeahead(null, {
    source: movies
  });
</script>
```

### Suggestions

![Suggest](https://gist.github.com/ankane/b6988db2802aca68a589b31e41b44195/raw/40febe948427e5bc53ec4e5dc248822855fef76f/recursion.png)

```ruby
class Product < ApplicationRecord
  searchkick suggest: [:name] # fields to generate suggestions
end
```

Reindex and search with:

```ruby
products = Product.search "peantu butta", suggest: true
products.suggestions # ["peanut butter"]
```

### Aggregations

[Aggregations](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html) provide aggregated search data.

![Aggregations](https://gist.github.com/ankane/b6988db2802aca68a589b31e41b44195/raw/40febe948427e5bc53ec4e5dc248822855fef76f/facets.png)

```ruby
products = Product.search "chuck taylor", aggs: [:product_type, :gender, :brand]
products.aggs
```

By default, `where` conditions apply to aggregations.

```ruby
Product.search "wingtips", where: {color: "brandy"}, aggs: [:size]
# aggregations for brandy wingtips are returned
```

Change this with:

```ruby
Product.search "wingtips", where: {color: "brandy"}, aggs: [:size], smart_aggs: false
# aggregations for all wingtips are returned
```

Set `where` conditions for each aggregation separately with:

```ruby
Product.search "wingtips", aggs: {size: {where: {color: "brandy"}}}
```

Limit

```ruby
Product.search "apples", aggs: {store_id: {limit: 10}}
```

Order

```ruby
Product.search "wingtips", aggs: {color: {order: {"_key" => "asc"}}} # alphabetically
```

**Note:** Use `_term` instead of `_key` in Elasticsearch 5

[All of these options are supported](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html#search-aggregations-bucket-terms-aggregation-order)

Ranges

```ruby
price_ranges = [{to: 20}, {from: 20, to: 50}, {from: 50}]
Product.search "*", aggs: {price: {ranges: price_ranges}}
```

Minimum document count

```ruby
Product.search "apples", aggs: {store_id: {min_doc_count: 2}}
```

Script support

```ruby
Product.search "*", aggs: {color: {script: {source: "'Color: ' + _value"}}}
```

Date histogram

```ruby
Product.search "pear", aggs: {products_per_year: {date_histogram: {field: :created_at, interval: :year}}}
```

For other aggregation types, including sub-aggregations, use `body_options`:

```ruby
Product.search "orange", body_options: {aggs: {price: {histogram: {field: :price, interval: 10}}}
```

### Highlight

Specify which fields to index with highlighting.

```ruby
class Product < ApplicationRecord
  searchkick highlight: [:name]
end
```

Highlight the search query in the results.

```ruby
bands = Band.search "cinema", highlight: true
```

View the highlighted fields with:

```ruby
bands.with_highlights.each do |band, highlights|
  highlights[:name] # "Two Door <em>Cinema</em> Club"
end
```

To change the tag, use:

```ruby
Band.search "cinema", highlight: {tag: "<strong>"}
```

To highlight and search different fields, use:

```ruby
Band.search "cinema", fields: [:name], highlight: {fields: [:description]}
```

By default, the entire field is highlighted. To get small snippets instead, use:

```ruby
bands = Band.search "cinema", highlight: {fragment_size: 20}
bands.with_highlights(multiple: true).each do |band, highlights|
  highlights[:name].join(" and ")
end
```

Additional options can be specified for each field:

```ruby
Band.search "cinema", fields: [:name], highlight: {fields: {name: {fragment_size: 200}}}
```

You can find available highlight options in the [Elasticsearch reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-highlighting.html#_highlighted_fragments).

### Similar Items

Find similar items.

```ruby
product = Product.first
product.similar(fields: [:name], where: {size: "12 oz"})
```

### Geospatial Searches

```ruby
class Restaurant < ApplicationRecord
  searchkick locations: [:location]

  def search_data
    attributes.merge(location: {lat: latitude, lon: longitude})
  end
end
```

Reindex and search with:

```ruby
Restaurant.search "pizza", where: {location: {near: {lat: 37, lon: -114}, within: "100mi"}} # or 160km
```

Bounded by a box

```ruby
Restaurant.search "sushi", where: {location: {top_left: {lat: 38, lon: -123}, bottom_right: {lat: 37, lon: -122}}}
```

**Note:** `top_right` and `bottom_left` also work

Bounded by a polygon

```ruby
Restaurant.search "dessert", where: {location: {geo_polygon: {points: [{lat: 38, lon: -123}, {lat: 39, lon: -123}, {lat: 37, lon: 122}]}}}
```

### Boost By Distance

Boost results by distance - closer results are boosted more

```ruby
Restaurant.search "noodles", boost_by_distance: {location: {origin: {lat: 37, lon: -122}}}
```

Also supports [additional options](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-function-score-query.html#_decay_functions)

```ruby
Restaurant.search "wings", boost_by_distance: {location: {origin: {lat: 37, lon: -122}, function: "linear", scale: "30mi", decay: 0.5}}
```

### Geo Shapes

You can also index and search geo shapes.

```ruby
class Restaurant < ApplicationRecord
  searchkick geo_shape: [:bounds]

  def search_data
    attributes.merge(
      bounds: {
        type: "envelope",
        coordinates: [{lat: 4, lon: 1}, {lat: 2, lon: 3}]
      }
    )
  end
end
```

See the [Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/geo-shape.html) for details.

Find shapes intersecting with the query shape

```ruby
Restaurant.search "soup", where: {bounds: {geo_shape: {type: "polygon", coordinates: [[{lat: 38, lon: -123}, ...]]}}}
```

Falling entirely within the query shape

```ruby
Restaurant.search "salad", where: {bounds: {geo_shape: {type: "circle", relation: "within", coordinates: [{lat: 38, lon: -123}], radius: "1km"}}}
```

Not touching the query shape

```ruby
Restaurant.search "burger", where: {bounds: {geo_shape: {type: "envelope", relation: "disjoint", coordinates: [{lat: 38, lon: -123}, {lat: 37, lon: -122}]}}}
```

## Inheritance

Searchkick supports single table inheritance.

```ruby
class Dog < Animal
end
```

In your parent model, set:

```ruby
class Animal < ApplicationRecord
  searchkick inheritance: true
end
```

The parent and child model can both reindex.

```ruby
Animal.reindex
Dog.reindex # equivalent, all animals reindexed
```

And to search, use:

```ruby
Animal.search "*"                   # all animals
Dog.search "*"                      # just dogs
Animal.search "*", type: [Dog, Cat] # just cats and dogs
```

**Notes:**

1. The `suggest` option retrieves suggestions from the parent at the moment.

    ```ruby
    Dog.search "airbudd", suggest: true # suggestions for all animals
    ```
2. This relies on a `type` field that is automatically added to the indexed document. Be wary of defining your own `type` field in `search_data`, as it will take precedence.

## Debugging Queries

To help with debugging queries, you can use:

```ruby
Product.search("soap", debug: true)
```

This prints useful info to `stdout`.

See how Elasticsearch scores your queries with:

```ruby
Product.search("soap", explain: true).response
```

See how Elasticsearch tokenizes your queries with:

```ruby
Product.search_index.tokens("Dish Washer Soap", analyzer: "searchkick_index")
# ["dish", "dishwash", "washer", "washersoap", "soap"]

Product.search_index.tokens("dishwasher soap", analyzer: "searchkick_search")
# ["dishwashersoap"] - no match

Product.search_index.tokens("dishwasher soap", analyzer: "searchkick_search2")
# ["dishwash", "soap"] - match!!
```

Partial matches

```ruby
Product.search_index.tokens("San Diego", analyzer: "searchkick_word_start_index")
# ["s", "sa", "san", "d", "di", "die", "dieg", "diego"]

Product.search_index.tokens("dieg", analyzer: "searchkick_word_search")
# ["dieg"] - match!!
```

See the [complete list of analyzers](https://github.com/ankane/searchkick/blob/31780ddac7a89eab1e0552a32b403f2040a37931/lib/searchkick/index_options.rb#L32).

## Deployment

Searchkick uses `ENV["ELASTICSEARCH_URL"]` for the Elasticsearch server. This defaults to `http://localhost:9200`.

### Heroku

Choose an add-on: [Bonsai](https://elements.heroku.com/addons/bonsai) or [Elastic Cloud](https://elements.heroku.com/addons/foundelasticsearch). [SearchBox](https://elements.heroku.com/addons/searchbox) does not work at the moment.

For Bonsai:

```sh
heroku addons:create bonsai
heroku config:set ELASTICSEARCH_URL=`heroku config:get BONSAI_URL`
```

For Elastic Cloud (previously Found):

```sh
heroku addons:create foundelasticsearch
heroku addons:open foundelasticsearch
```

Visit the Shield page and reset your password. You’ll need to add the username and password to your url. Get the existing url with:

```sh
heroku config:get FOUNDELASTICSEARCH_URL
```

And add `elastic:password@` right after `https://` and add port `9243` at the end:

```sh
heroku config:set ELASTICSEARCH_URL=https://elastic:password@12345.us-east-1.aws.found.io:9243
```

Then deploy and reindex:

```sh
heroku run rake searchkick:reindex CLASS=Product
```

### Amazon Elasticsearch Service

Create an initializer `config/initializers/elasticsearch.rb` with:

```ruby
ENV["ELASTICSEARCH_URL"] = "https://es-domain-1234.us-east-1.es.amazonaws.com"
```

To use signed requests, include in your Gemfile:

```ruby
gem 'faraday_middleware-aws-sigv4'
```

and add to your initializer:

```ruby
Searchkick.aws_credentials = {
  access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  region: "us-east-1"
}
```

Then deploy and reindex:

```sh
rake searchkick:reindex CLASS=Product
```

### Other

Create an initializer `config/initializers/elasticsearch.rb` with:

```ruby
ENV["ELASTICSEARCH_URL"] = "https://user:password@host"
```

Then deploy and reindex:

```sh
rake searchkick:reindex CLASS=Product
```

### Data Protection

We recommend encrypting data at rest and in transit (even inside your own network). This is especially important if you send [personal data](https://en.wikipedia.org/wiki/Personally_identifiable_information) of your users to Elasticsearch.

Bonsai, Elastic Cloud, and Amazon Elasticsearch all support encryption at rest and HTTPS.

### Automatic Failover

Create an initializer `config/initializers/elasticsearch.rb` with multiple hosts:

```ruby
ENV["ELASTICSEARCH_URL"] = "https://user:password@host1,https://user:password@host2"
```

See [elasticsearch-transport](https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-transport) for a complete list of options.

### Lograge

Add the following to `config/environments/production.rb`:

```ruby
config.lograge.custom_options = lambda do |event|
  options = {}
  options[:search] = event.payload[:searchkick_runtime] if event.payload[:searchkick_runtime].to_f > 0
  options
end
```

See [Production Rails](https://github.com/ankane/production_rails) for other good practices.

## Performance

### JSON Generation

Significantly increase performance with faster JSON generation. Add [Oj](https://github.com/ohler55/oj) to your Gemfile.

```ruby
gem 'oj'
```

This speeds up all JSON generation and parsing in your application (automatically!)

### Persistent HTTP Connections

Significantly increase performance with persistent HTTP connections. Add [Typhoeus](https://github.com/typhoeus/typhoeus) to your Gemfile and it’ll automatically be used.

```ruby
gem 'typhoeus'
```

To reduce log noise, create an initializer with:

```ruby
Ethon.logger = Logger.new(nil)
```

If you run into issues on Windows, check out [this post](https://www.rastating.com/fixing-issues-in-typhoeus-and-httparty-on-windows/).

### Searchable Fields

By default, all string fields are searchable (can be used in `fields` option). Speed up indexing and reduce index size by only making some fields searchable. This disables the `_all` field unless it’s listed.

```ruby
class Product < ApplicationRecord
  searchkick searchable: [:name]
end
```

### Filterable Fields

By default, all string fields are filterable (can be used in `where` option). Speed up indexing and reduce index size by only making some fields filterable.

```ruby
class Product < ApplicationRecord
  searchkick filterable: [:brand]
end
```

**Note:** Non-string fields are always filterable and should not be passed to this option.

### Parallel Reindexing

For large data sets, you can use background jobs to parallelize reindexing.

```ruby
Product.reindex(async: true)
# {index_name: "products_production_20170111210018065"}
```

Once the jobs complete, promote the new index with:

```ruby
Product.search_index.promote(index_name)
```

You can optionally track the status with Redis:

```ruby
Searchkick.redis = Redis.new
```

And use:

```ruby
Searchkick.reindex_status(index_name)
```

You can also have Searchkick wait for reindexing to complete

```ruby
Product.reindex(async: {wait: true})
```

You can use [ActiveJob::TrafficControl](https://github.com/nickelser/activejob-traffic_control) to control concurrency. Install the gem:

```ruby
gem 'activejob-traffic_control', '>= 0.1.3'
```

And create an initializer with:

```ruby
ActiveJob::TrafficControl.client = Searchkick.redis

class Searchkick::BulkReindexJob
  concurrency 3
end
```

This will allow only 3 jobs to run at once.

### Refresh Interval

You can specify a longer refresh interval while reindexing to increase performance.

```ruby
Product.reindex(async: true, refresh_interval: "30s")
```

**Note:** This only makes a noticable difference with parallel reindexing.

When promoting, have it restored to the value in your mapping (defaults to `1s`).

```ruby
Product.search_index.promote(index_name, update_refresh_interval: true)
```

### Queuing

Push ids of records needing reindexed to a queue and reindex in bulk for better performance. First, set up Redis in an initializer. We recommend using [connection_pool](https://github.com/mperham/connection_pool).

```ruby
Searchkick.redis = ConnectionPool.new { Redis.new }
```

And ask your models to queue updates.

```ruby
class Product < ApplicationRecord
  searchkick callbacks: :queue
end
```

Then, set up a background job to run.

```ruby
Searchkick::ProcessQueueJob.perform_later(class_name: "Product")
```

You can check the queue length with:

```ruby
Product.search_index.reindex_queue.length
```

For more tips, check out [Keeping Elasticsearch in Sync](https://www.elastic.co/blog/found-keeping-elasticsearch-in-sync).

### Routing

Searchkick supports [Elasticsearch’s routing feature](https://www.elastic.co/blog/customizing-your-document-routing), which can significantly speed up searches.

```ruby
class Business < ApplicationRecord
  searchkick routing: true

  def search_routing
    city_id
  end
end
```

Reindex and search with:

```ruby
Business.search "ice cream", routing: params[:city_id]
```

### Partial Reindexing

Reindex a subset of attributes to reduce time spent generating search data and cut down on network traffic.

```ruby
class Product < ApplicationRecord
  def search_data
    {
      name: name
    }.merge(search_prices)
  end

  def search_prices
    {
      price: price,
      sale_price: sale_price
    }
  end
end
```

And use:

```ruby
Product.reindex(:search_prices)
```

### Performant Conversions

Split out conversions into a separate method so you can use partial reindexing, and cache conversions to prevent N+1 queries. Be sure to use a centralized cache store like Memcached or Redis.

```ruby
class Product < ApplicationRecord
  def search_data
    {
      name: name
    }.merge(search_conversions)
  end

  def search_conversions
    {
      conversions: Rails.cache.read("search_conversions:#{self.class.name}:#{id}") || {}
    }
  end
end
```

Create a job to update the cache and reindex records with new conversions.

```ruby
class ReindexConversionsJob < ApplicationJob
  def perform(class_name)
    # get records that have a recent conversion
    recently_converted_ids =
      Searchjoy::Search.where("convertable_type = ? AND converted_at > ?", class_name, 1.day.ago)
      .order(:convertable_id).uniq.pluck(:convertable_id)

    # split into groups
    recently_converted_ids.in_groups_of(1000, false) do |ids|
      # fetch conversions
      conversions =
        Searchjoy::Search.where(convertable_id: ids, convertable_type: class_name)
        .group(:convertable_id, :query).uniq.count(:user_id)

      # group conversions by record
      conversions_by_record = {}
      conversions.each do |(id, query), count|
        (conversions_by_record[id] ||= {})[query] = count
      end

      # write to cache
      conversions_by_record.each do |id, conversions|
        Rails.cache.write("search_conversions:#{class_name}:#{id}", conversions)
      end

      # partial reindex
      class_name.constantize.where(id: ids).reindex(:search_conversions)
    end
  end
end
```

Run the job with:

```ruby
ReindexConversionsJob.perform_later("Product")
```

## Advanced

Searchkick makes it easy to use the Elasticsearch DSL on its own.

### Advanced Mapping

Create a custom mapping:

```ruby
class Product < ApplicationRecord
  searchkick mappings: {
    properties: {
      name: {type: "keyword"}
    }
  }
end
```
**Note:** If you use a custom mapping, you'll need to use [custom searching](#advanced-search) as well.

To keep the mappings and settings generated by Searchkick, use:

```ruby
class Product < ApplicationRecord
  searchkick merge_mappings: true, mappings: {...}
end
```

### Advanced Search

And use the `body` option to search:

```ruby
products = Product.search body: {query: {match: {name: "milk"}}}
```

View the response with:

```ruby
products.response
```

To modify the query generated by Searchkick, use:

```ruby
products = Product.search "milk", body_options: {min_score: 1}
```

or

```ruby
products =
  Product.search "apples" do |body|
    body[:min_score] = 1
  end
```

### Elasticsearch Gem

Searchkick is built on top of the [elasticsearch](https://github.com/elastic/elasticsearch-ruby) gem. To access the client directly, use:

```ruby
Searchkick.client
```

## Multi Search

To batch search requests for performance, use:

```ruby
products = Product.search("snacks", execute: false)
coupons = Coupon.search("snacks", execute: false)
Searchkick.multi_search([products, coupons])
```

Then use `products` and `coupons` as typical results.

**Note:** Errors are not raised as with single requests. Use the `error` method on each query to check for errors.

## Multiple Models

Search across multiple models with:

```ruby
Searchkick.search "milk", models: [Product, Category]
```

Boost specific models with:

```ruby
indices_boost: {Category => 2, Product => 1}
```

## Scroll API

Searchkick also supports the [scroll API](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-scroll.html). Scrolling is not intended for real time user requests, but rather for processing large amounts of data.

```ruby
Product.search("*", scroll: "1m").scroll do |batch|
  # process batch ...
end
```

You can also scroll batches manually.

```ruby
products = Product.search "*", scroll: "1m"
while products.any?
  # process batch ...

  products = products.scroll
end

products.clear_scroll
```

## Nested Data

To query nested data, use dot notation.

```ruby
User.search "san", fields: ["address.city"], where: {"address.zip_code" => 12345}
```

## Reference

Reindex one record

```ruby
product = Product.find(1)
product.reindex
```

Reindex multiple records

```ruby
Product.where(store_id: 1).reindex
```

Reindex associations

```ruby
store.products.reindex
```

Remove old indices

```ruby
Product.search_index.clean_indices
```

Use custom settings

```ruby
class Product < ApplicationRecord
  searchkick settings: {number_of_shards: 3}
end
```

Use a different index name

```ruby
class Product < ApplicationRecord
  searchkick index_name: "products_v2"
end
```

Use a dynamic index name

```ruby
class Product < ApplicationRecord
  searchkick index_name: -> { "#{name.tableize}-#{I18n.locale}" }
end
```

Prefix the index name

```ruby
class Product < ApplicationRecord
  searchkick index_prefix: "datakick"
end
```

For all models

```ruby
Searchkick.index_prefix = "datakick"
```

Use a different term for boosting by conversions

```ruby
Product.search("banana", conversions_term: "organic banana")
```

Multiple conversion fields

```ruby
class Product < ApplicationRecord
  has_many :searches, class_name: "Searchjoy::Search"

  # searchkick also supports multiple "conversions" fields
  searchkick conversions: ["unique_user_conversions", "total_conversions"]

  def search_data
    {
      name: name,
      unique_user_conversions: searches.group(:query).uniq.count(:user_id),
      # {"ice cream" => 234, "chocolate" => 67, "cream" => 2}
      total_conversions: searches.group(:query).count
      # {"ice cream" => 412, "chocolate" => 117, "cream" => 6}
    }
  end
end
```

and during query time:

```ruby
Product.search("banana") # boost by both fields (default)
Product.search("banana", conversions: "total_conversions") # only boost by total_conversions
Product.search("banana", conversions: false) # no conversion boosting
```

Change timeout

```ruby
Searchkick.timeout = 15 # defaults to 10
```

Set a lower timeout for searches

```ruby
Searchkick.search_timeout = 3
```

Change the search method name

```ruby
Searchkick.search_method_name = :lookup
```

Change search queue name

```ruby
Searchkick.queue_name = :search_reindex
```

Eager load associations

```ruby
Product.search "milk", includes: [:brand, :stores]
```

Eager load different associations by model

```ruby
Searchkick.search("*",  models: [Product, Store], model_includes: {Product => [:store], Store => [:product]})
```

Run additional scopes on results

```ruby
Product.search "milk", scope_results: ->(r) { r.with_attached_images }
```

Specify default fields to search

```ruby
class Product < ApplicationRecord
  searchkick default_fields: [:name]
end
```

Turn off special characters

```ruby
class Product < ApplicationRecord
  # A will not match Ä
  searchkick special_characters: false
end
```

Turn off stemming

```ruby
class Product < ApplicationRecord
  searchkick stem: false
end
```

Turn on stemming for conversions

```ruby
class Product < ApplicationRecord
  searchkick stem_conversions: true
end
```

Use a different [similarity algorithm](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-similarity.html) for scoring

```ruby
class Product < ApplicationRecord
  searchkick similarity: "classic"
end
```

Make search case-sensitive

```ruby
class Product < ApplicationRecord
  searchkick case_sensitive: true
end
```

**Note:** If misspellings are enabled (default), results with a single character case difference will match. Turn off misspellings if this is not desired.

Change import batch size

```ruby
class Product < ApplicationRecord
  searchkick batch_size: 200 # defaults to 1000
end
```

Create index without importing

```ruby
Product.reindex(import: false)
```

Use a different id

```ruby
class Product < ApplicationRecord
  def search_document_id
    custom_id
  end
end
```

Lazy searching

```ruby
products = Product.search("carrots", execute: false)
products.each { ... } # search not executed until here
```

Add [request parameters](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-uri-request.html), like `search_type` and `query_cache`

```ruby
Product.search("carrots", request_params: {search_type: "dfs_query_then_fetch"})
```

Set options across all models

```ruby
Searchkick.model_options = {
  batch_size: 200
}
```

Reindex conditionally

```ruby
class Product < ApplicationRecord
  searchkick callbacks: false

  # add the callbacks manually
  after_commit :reindex, if: -> (model) { model.previous_changes.key?("name") } # use your own condition
end
```

Reindex all models - Rails only

```sh
rake searchkick:reindex:all
```

Turn on misspellings after a certain number of characters

```ruby
Product.search "api", misspellings: {prefix_length: 2} # api, apt, no ahi
```

**Note:** With this option, if the query length is the same as `prefix_length`, misspellings are turned off

```ruby
Product.search "ah", misspellings: {prefix_length: 2} # ah, no aha
```

## Testing

For performance, only enable Searchkick callbacks for the tests that need it.

### Minitest

Add to your `test/test_helper.rb`:

```ruby
# reindex models
Product.reindex

# and disable callbacks
Searchkick.disable_callbacks
```

And use:

```ruby
class ProductTest < Minitest::Test
  def setup
    Searchkick.enable_callbacks
  end

  def teardown
    Searchkick.disable_callbacks
  end

  def test_search
    Product.create!(name: "Apple")
    Product.search_index.refresh
    assert_equal ["Apple"], Product.search("apple").map(&:name)
  end
end
```

### RSpec

Add to your `spec/spec_helper.rb`:

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    # reindex models
    Product.reindex

    # and disable callbacks
    Searchkick.disable_callbacks
  end

  config.around(:each, search: true) do |example|
    Searchkick.callbacks(true) do
      example.run
    end
  end
end
```

And use:

```ruby
describe Product, search: true do
  it "searches" do
    Product.create!(name: "Apple")
    Product.search_index.refresh
    assert_equal ["Apple"], Product.search("apple").map(&:name)
  end
end
```

### Factory Bot

Use a trait and an after `create` hook for each indexed model:

```ruby
FactoryBot.define do
  factory :product do
    # ...

    # Note: This should be the last trait in the list so `reindex` is called
    # after all the other callbacks complete.
    trait :reindex do
      after(:create) do |product, _evaluator|
        product.reindex(refresh: true)
      end
    end
  end
end

# use it
FactoryBot.create(:product, :some_trait, :reindex, some_attribute: "foo")
```

### Parallel Tests

Set:

```ruby
Searchkick.index_suffix = ENV["TEST_ENV_NUMBER"]
```

## Multi-Tenancy

Check out [this great post](https://www.tiagoamaro.com.br/2014/12/11/multi-tenancy-with-searchkick/) on the [Apartment](https://github.com/influitive/apartment) gem. Follow a similar pattern if you use another gem.

## Upgrading

See [how to upgrade to Searchkick 3](docs/Searchkick-3-Upgrade.md)

## Elasticsearch 6 to 7 Upgrade

1. Install Searchkick 4
2. Upgrade your Elasticsearch cluster

## Elasticsearch 5 to 6 Upgrade

Elasticsearch 6 removes the ability to reindex with the `_all` field. Before you upgrade, we recommend disabling this field manually and specifying default fields on your models.

```ruby
class Product < ApplicationRecord
  searchkick _all: false, default_fields: [:name]
end
```

If you need search across multiple fields, we recommend creating a similar field in your search data.

```ruby
class Product < ApplicationRecord
  def search_data
    {
      all: [name, size, quantity].join(" ")
    }
  end
end
```

## Elasticsearch Gotchas

### Consistency

Elasticsearch is eventually consistent, meaning it can take up to a second for a change to reflect in search. You can use the `refresh` method to have it show up immediately.

```ruby
product.save!
Product.search_index.refresh
```

### Inconsistent Scores

Due to the distributed nature of Elasticsearch, you can get incorrect results when the number of documents in the index is low. You can [read more about it here](https://www.elastic.co/blog/understanding-query-then-fetch-vs-dfs-query-then-fetch). To fix this, do:

```ruby
class Product < ApplicationRecord
  searchkick settings: {number_of_shards: 1}
end
```

For convenience, this is set by default in the test environment.

## History

View the [changelog](https://github.com/ankane/searchkick/blob/master/CHANGELOG.md).

## Thanks

Thanks to Karel Minarik for [Elasticsearch Ruby](https://github.com/elasticsearch/elasticsearch-ruby) and [Tire](https://github.com/karmi/retire), Jaroslav Kalistsuk for [zero downtime reindexing](https://gist.github.com/jarosan/3124884), and Alex Leschenko for [Elasticsearch autocomplete](https://github.com/leschenko/elasticsearch_autocomplete).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/searchkick/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/searchkick/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

If you’re looking for ideas, [try here](https://github.com/ankane/searchkick/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).

To get started with development and testing:

```sh
git clone https://github.com/ankane/searchkick.git
cd searchkick
bundle install
rake test
```
