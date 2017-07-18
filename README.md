# Searchkick

:rocket: Intelligent search made easy

Searchkick learns what **your users** are looking for. As more people search, it gets smarter and the results get better. It’s friendly for developers - and magical for your users.

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
- works with ActiveRecord, Mongoid, and NoBrainer

:speech_balloon: Get [handcrafted updates](http://chartkick.us7.list-manage.com/subscribe?u=952c861f99eb43084e0a49f98&id=6ea6541e8e&group[0][4]=true) for new features

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

The latest version works with Elasticsearch 2 and 5. For Elasticsearch 1, use version 1.5.1 and [this readme](https://github.com/ankane/searchkick/blob/v1.5.1/README.md).

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
products = Product.search "apples"
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

[Conversions](#keep-getting-better) are also a great way to boost.

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
class Product < ActiveRecord::Base
  searchkick word_start: [:name]
end
```

And to search (after you reindex):

```ruby
Product.search "back", fields: [:name], match: :word_start
```

Available options are:

```ruby
:word # default
:word_start
:word_middle
:word_end
:text_start
:text_middle
:text_end
```

### Exact Matches

To match a field exactly (case-insensitive), use:

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
class Product < ActiveRecord::Base
  searchkick language: "german"
end
```

[See the list of stemmers](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-stemmer-tokenfilter.html)

### Synonyms

```ruby
class Product < ActiveRecord::Base
  searchkick synonyms: [["scallion", "green onion"], ["qtip", "cotton swab"]]
end
```

Call `Product.reindex` after changing synonyms.

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
class Product < ActiveRecord::Base
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

### WordNet

Prepopulate English synonyms with the [WordNet database](https://en.wikipedia.org/wiki/WordNet).

Download [WordNet 3.0](http://wordnetcode.princeton.edu/3.0/WNprolog-3.0.tar.gz) to each Elasticsearch server and move `wn_s.pl` to the `/var/lib` directory.

```sh
cd /tmp
curl -o wordnet.tar.gz http://wordnetcode.princeton.edu/3.0/WNprolog-3.0.tar.gz
tar -zxvf wordnet.tar.gz
mv prolog/wn_s.pl /var/lib
```

Tell each model to use it:

```ruby
class Product < ActiveRecord::Base
  searchkick wordnet: true
end
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
class Product < ActiveRecord::Base
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
class Product < ActiveRecord::Base
  scope :search_import, -> { includes(:department) }
end
```

By default, all records are indexed. To control which records are indexed, use the `should_index?` method together with the `search_import` scope.

```ruby
class Product < ActiveRecord::Base
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

1. Immediate (default)

  Anytime a record is inserted, updated, or deleted

2. Asynchronous

  Use background jobs for better performance

  ```ruby
  class Product < ActiveRecord::Base
    searchkick callbacks: :async
  end
  ```

  And [install Active Job](https://github.com/ankane/activejob_backport) for Rails 4.1 and below. Jobs are added to a queue named `searchkick`.

3. Queuing

  Push ids of records that need updated to a queue and reindex in the background in batches. This is more performant than the asynchronous method, which updates records individually. See [how to set up](#queuing).

4. Manual

  Turn off automatic syncing

  ```ruby
  class Product < ActiveRecord::Base
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
class Image < ActiveRecord::Base
  belongs_to :product

  after_commit :reindex_product

  def reindex_product
    product.reindex # or reindex_async
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

You do **not** need to clean up the search queries. Searchkick automatically treats `apple` and `APPLES` the same.

Next, add conversions to the index.

```ruby
class Product < ActiveRecord::Base
  has_many :searches, class_name: "Searchjoy::Search", as: :convertable

  searchkick conversions: ["conversions"] # name of field

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
class Product < ActiveRecord::Base
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

![Autocomplete](https://raw.githubusercontent.com/ankane/searchkick/gh-pages/autocomplete.png)

**Note:** To autocomplete on general categories (like `cereal` rather than product names), check out [Autosuggest](https://github.com/ankane/autosuggest).

**Note 2:** If you only have a few thousand records, don’t use Searchkick for autocomplete. It’s *much* faster to load all records into JavaScript and autocomplete there (eliminates network requests).

First, specify which fields use this feature. This is necessary since autocomplete can increase the index size significantly, but don’t worry - this gives you blazing faster queries.

```ruby
class Movie < ActiveRecord::Base
  searchkick word_start: [:title, :director]
end
```

Reindex and search with:

```ruby
Movie.search "jurassic pa", fields: [:title], match: :word_start
```

Typically, you want to use a JavaScript library like [typeahead.js](http://twitter.github.io/typeahead.js/) or [jQuery UI](http://jqueryui.com/autocomplete/).

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

![Suggest](https://raw.githubusercontent.com/ankane/searchkick/gh-pages/recursion.png)

```ruby
class Product < ActiveRecord::Base
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

![Aggregations](https://raw.githubusercontent.com/ankane/searchkick/gh-pages/facets.png)

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
Product.search "wingtips", aggs: {color: {order: {"_term" => "asc"}}} # alphabetically
```

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

Date histogram

```ruby
Product.search "pear", aggs: {products_per_year: {date_histogram: {field: :created_at, interval: :year}}}
```

#### Moving From Facets

1. Replace `facets` with `aggs` in searches. **Note:** Stats facets are not supported at this time.

  ```ruby
  products = Product.search "chuck taylor", facets: [:brand]
  # to
  products = Product.search "chuck taylor", aggs: [:brand]
  ```

2. Replace the `facets` method with `aggs` for results.

  ```ruby
  products.facets
  # to
  products.aggs
  ```

  The keys in results differ slightly. Instead of:

  ```json
  {
    "_type":"terms",
    "missing":0,
    "total":45,
    "other":34,
    "terms":[
      {"term":14.0,"count":11}
    ]
  }
  ```

  You get:

  ```json
  {
    "doc_count":45,
    "doc_count_error_upper_bound":0,
    "sum_other_doc_count":34,
    "buckets":[
      {"key":14.0,"doc_count":11}
    ]
  }
  ```

  Update your application to handle this.

3. By default, `where` conditions apply to aggregations. This is equivalent to `smart_facets: true`. If you have `smart_facets: true`, you can remove it. If this is not desired, set `smart_aggs: false`.

4. If you have any range facets with dates, change the key from `ranges` to `date_ranges`.

  ```ruby
  facets: {date_field: {ranges: date_ranges}}
  # to
  aggs: {date_field: {date_ranges: date_ranges}}
  ```

### Highlight

Specify which fields to index with highlighting.

```ruby
class Product < ActiveRecord::Base
  searchkick highlight: [:name]
end
```

Highlight the search query in the results.

```ruby
bands = Band.search "cinema", fields: [:name], highlight: true
```

**Note:** The `fields` option is required, unless highlight options are given - see below.

View the highlighted fields with:

```ruby
bands.each do |band|
  band.search_highlights[:name] # "Two Door <em>Cinema</em> Club"
end
```

To change the tag, use:

```ruby
Band.search "cinema", fields: [:name], highlight: {tag: "<strong>"}
```

To highlight and search different fields, use:

```ruby
Band.search "cinema", fields: [:name], highlight: {fields: [:description]}
```

Additional options, including fragment size, can be specified for each field:

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
class Restaurant < ActiveRecord::Base
  searchkick locations: [:location]

  def search_data
    attributes.merge location: {lat: latitude, lon: longitude}
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
class Restaurant < ActiveRecord::Base
  searchkick geo_shape: {
    bounds: {tree: "geohash", precision: "1km"}
  }

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

Containing the query shape (Elasticsearch 2.2+)

```ruby
Restaurant.search "fries", where: {bounds: {geo_shape: {type: "envelope", relation: "contains", coordinates: [{lat: 38, lon: -123}, {lat: 37, lon: -122}]}}}
```

## Inheritance

Searchkick supports single table inheritance.

```ruby
class Dog < Animal
end
```

The parent and child model can both reindex.

```ruby
Animal.reindex
Dog.reindex # equivalent
```

And to search, use:

```ruby
Animal.search "*"                   # all animals
Dog.search "*"                      # just dogs
Animal.search "*", type: [Dog, Cat] # just cats and dogs
```

**Note:** The `suggest` option retrieves suggestions from the parent at the moment.

```ruby
Dog.search "airbudd", suggest: true # suggestions for all animals
```

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

Choose an add-on: [SearchBox](https://elements.heroku.com/addons/searchbox), [Bonsai](https://elements.heroku.com/addons/bonsai), or [Elastic Cloud](https://elements.heroku.com/addons/foundelasticsearch).

```sh
# SearchBox
heroku addons:create searchbox:starter
heroku config:set ELASTICSEARCH_URL=`heroku config:get SEARCHBOX_URL`

# Bonsai
heroku addons:create bonsai
heroku config:set ELASTICSEARCH_URL=`heroku config:get BONSAI_URL`

# Found
heroku addons:create foundelasticsearch
heroku config:set ELASTICSEARCH_URL=`heroku config:get FOUNDELASTICSEARCH_URL`
```

Then deploy and reindex:

```sh
heroku run rake searchkick:reindex CLASS=Product
```

### Amazon Elasticsearch Service

Include `elasticsearch 1.0.15` or greater in your Gemfile.

```ruby
gem 'elasticsearch', '>= 1.0.15'
```

Create an initializer `config/initializers/elasticsearch.rb` with:

```ruby
ENV["ELASTICSEARCH_URL"] = "https://es-domain-1234.us-east-1.es.amazonaws.com"
```

To use signed request, include in your Gemfile:

```ruby
gem 'faraday_middleware-aws-signers-v4'
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
ENV["ELASTICSEARCH_URL"] = "http://username:password@api.searchbox.io"
```

Then deploy and reindex:

```sh
rake searchkick:reindex CLASS=Product
```

### Automatic Failover

Create an initializer `config/initializers/elasticsearch.rb` with multiple hosts:

```ruby
ENV["ELASTICSEARCH_URL"] = "http://localhost:9200,http://localhost:9201"

Searchkick.client_options = {
  retry_on_failure: true
}
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
Ethon.logger = Logger.new("/dev/null")
```

If you run into issues on Windows, check out [this post](https://www.rastating.com/fixing-issues-in-typhoeus-and-httparty-on-windows/).

### Searchable Fields

By default, all string fields are searchable (can be used in `fields` option). Speed up indexing and reduce index size by only making some fields searchable. This disables the `_all` field unless it’s listed.

```ruby
class Product < ActiveRecord::Base
  searchkick searchable: [:name]
end
```

### Filterable Fields

By default, all string fields are filterable (can be used in `where` option). Speed up indexing and reduce index size by only making some fields filterable.

```ruby
class Product < ActiveRecord::Base
  searchkick filterable: [:brand]
end
```

**Note:** Non-string fields will always be filterable and should not be passed to this option.

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
class Product < ActiveRecord::Base
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
class Business < ActiveRecord::Base
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
class Product < ActiveRecord::Base
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
class Product < ActiveRecord::Base
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
class ReindexConversionsJob < ActiveJob::Base
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
class Product < ActiveRecord::Base
  searchkick mappings: {
    product: {
      properties: {
        name: {type: "string", analyzer: "keyword"}
      }
    }
  }
end
```
**Note:** If you use a custom mapping, you'll need to use [custom searching](#advanced-search) as well.

To keep the mappings and settings generated by Searchkick, use:

```ruby
class Product < ActiveRecord::Base
  searchkick merge_mappings: true, mappings: {...}
end
```

### Advanced Search

And use the `body` option to search:

```ruby
products = Product.search body: {match: {name: "milk"}}
```

**Note:** This replaces the entire body, so other options are ignored.

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
fresh_products = Product.search("fresh", execute: false)
frozen_products = Product.search("frozen", execute: false)
Searchkick.multi_search([fresh_products, frozen_products])
```

Then use `fresh_products` and `frozen_products` as typical results.

**Note:** Errors are not raised as with single requests. Use the `error` method on each query to check for errors. Also, if you use the `below` option for misspellings, misspellings will be disabled.

## Multiple Indices

Search across multiple indices with:

```ruby
Searchkick.search "milk", index_name: [Product, Category]
```

Boost specific indices with:

```ruby
indices_boost: {Category => 2, Product => 1}
```

## Nested Data

To query nested data, use dot notation.

```ruby
User.search "san", fields: ["address.city"], where: {"address.zip_code" => 12345}
```

## Search Concepts

### Precision and Recall

[Precision and recall](https://en.wikipedia.org/wiki/Precision_and_recall) are two key concepts in search (also known as *information retrieval*). To help illustrate, let’s walk through an example.

You have a store with 16 types of apples. A user searches for `apples` gets 10 results. 8 of the results are for apples, and 2 are for apple juice.

**Precision** is the fraction of documents in the results that are relevant. There are 10 results and 8 are relevant, so precision is 80%.

**Recall** is the fraction of relevant documents in the results out of all relevant documents. There are 16 apples and only 8 in the results, so recall is 50%.

There’s typically a trade-off between the two. As you tweak your search to increase precision (not return irrelevant documents), there’s are greater chance a relevant document also isn’t returned, which decreases recall. The opposite also applies. As you try to increase recall (return a higher number of relevent documents), there’s a greater chance you also return an irrelevant document, decreasing precision.

## Reference

Reindex one record

```ruby
product = Product.find(1)
product.reindex
# or to reindex in the background
product.reindex_async
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
class Product < ActiveRecord::Base
  searchkick settings: {number_of_shards: 3}
end
```

Use a different index name

```ruby
class Product < ActiveRecord::Base
  searchkick index_name: "products_v2"
end
```

Use a dynamic index name

```ruby
class Product < ActiveRecord::Base
  searchkick index_name: -> { "#{name.tableize}-#{I18n.locale}" }
end
```

Prefix the index name

```ruby
class Product < ActiveRecord::Base
  searchkick index_prefix: "datakick"
end
```

Use a different term for boosting by conversions

```ruby
Product.search("banana", conversions_term: "organic banana")
```

Multiple conversion fields

```ruby
class Product < ActiveRecord::Base
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

Turn off special characters

```ruby
class Product < ActiveRecord::Base
  # A will not match Ä
  searchkick special_characters: false
end
```

Use a different [similarity algorithm](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-similarity.html) for scoring

```ruby
class Product < ActiveRecord::Base
  searchkick similarity: "classic"
end
```

Change import batch size

```ruby
class Product < ActiveRecord::Base
  searchkick batch_size: 200 # defaults to 1000
end
```

Create index without importing

```ruby
Product.reindex(import: false)
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

Reindex conditionally

```ruby
class Product < ActiveRecord::Base
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
    Searchkick.enable_callbacks
    example.run
    Searchkick.disable_callbacks
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

### Factory Girl

Use a trait and an after `create` hook for each indexed model:

```ruby
FactoryGirl.define do
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
FactoryGirl.create(:product, :some_trait, :reindex, some_attribute: "foo")
```

### Parallel Tests

Set:

```ruby
Searchkick.index_suffix = ENV["TEST_ENV_NUMBER"]
```

## Multi-Tenancy

Check out [this great post](https://www.tiagoamaro.com.br/2014/12/11/multi-tenancy-with-searchkick/) on the [Apartment](https://github.com/influitive/apartment) gem. Follow a similar pattern if you use another gem.

## Upgrading

View the [changelog](https://github.com/ankane/searchkick/blob/master/CHANGELOG.md).

Important notes are listed below.

### 2.0.0

- Added support for `reindex` on associations

#### Breaking Changes

- Removed support for Elasticsearch 1 as it reaches [end of life](https://www.elastic.co/support/eol)
- Removed facets, legacy options, and legacy methods
- Invalid options now throw an `ArgumentError`
- The `query` and `json` options have been removed in favor of `body`
- The `include` option has been removed in favor of `includes`
- The `personalize` option has been removed in favor of `boost_where`
- The `partial` option has been removed in favor of `operator`
- Renamed `select_v2` to `select` (legacy `select` no longer available)
- The `_all` field is disabled if `searchable` option is used (for performance)
- The `partial_reindex(:method_name)` method has been replaced with `reindex(:method_name)`
- The `unsearchable` and `only_analyzed` options have been removed in favor of `searchable` and `filterable`
- `load: false` no longer returns an array in Elasticsearch 2

### 1.0.0

- Added support for Elasticsearch 2.0
- Facets are deprecated in favor of [aggregations](#aggregations) - see [how to upgrade](#moving-from-facets)

#### Breaking Changes

- **ActiveRecord 4.1+ and Mongoid 3+:** Attempting to reindex with a scope now throws a `Searchkick::DangerousOperation` error to keep your from accidentally recreating your index with only a few records.

  ```ruby
  Product.where(color: "brandy").reindex # error!
  ```

  If this is what you intend to do, use:

  ```ruby
  Product.where(color: "brandy").reindex(accept_danger: true)
  ```

- Misspellings are enabled by default for [partial matches](#partial-matches). Use `misspellings: false` to disable.
- [Transpositions](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance) are enabled by default for misspellings. Use `misspellings: {transpositions: false}` to disable.

### 0.6.0 and 0.7.0

If running Searchkick `0.6.0` or `0.7.0` and Elasticsearch `0.90`, we recommend upgrading to Searchkick `0.6.1` or `0.7.1` to fix an issue that causes downtime when reindexing.

### 0.3.0

Before `0.3.0`, locations were indexed incorrectly. When upgrading, be sure to reindex immediately.

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
class Product < ActiveRecord::Base
  searchkick settings: {number_of_shards: 1}
end
```

For convenience, this is set by default in the test environment.

## Thanks

Thanks to Karel Minarik for [Elasticsearch Ruby](https://github.com/elasticsearch/elasticsearch-ruby) and [Tire](https://github.com/karmi/retire), Jaroslav Kalistsuk for [zero downtime reindexing](https://gist.github.com/jarosan/3124884), and Alex Leschenko for [Elasticsearch autocomplete](https://github.com/leschenko/elasticsearch_autocomplete).

## Roadmap

- Reindex API
- Incorporate human eval

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
