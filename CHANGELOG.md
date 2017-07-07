## 2.3.1

- Added support for `reindex(async: true)` for non-numeric primary keys
- Added `conversions_term` option
- Added support for passing fields to `suggest` option
- Fixed `page_view_entries` for Kaminari

## 2.3.0

- Fixed analyzer on dynamically mapped fields
- Fixed error with `similar` method and `_all` field
- Throw error when fields are needed
- Added `queue_name` option
- No longer require synonyms to be lowercase

## 2.2.1

- Added `avg`, `cardinality`, `max`, `min`, and `sum` aggregations
- Added `load: {dumpable: true}` option
- Added `index_suffix` option
- Accept string for `exclude` option

## 2.2.0

- Fixed bug with text values longer than 256 characters and `_all` field - see [#850](https://github.com/ankane/searchkick/issues/850)
- Fixed issue with `_all` field in `searchable`
- Fixed `exclude` option with `word_start`

## 2.1.1

- Fixed duplicate notifications
- Added support for `connection_pool`
- Added `exclude` option

## 2.1.0

- Background reindexing and queues are officially supported
- Log updates and deletes

## 2.0.4

- Added support for queuing updates [experimental]
- Added `refresh_interval` option to `reindex`
- Prefer `search_index` over `searchkick_index`

## 2.0.3

- Added `async` option to `reindex` [experimental]
- Added `misspellings?` method to results

## 2.0.2

- Added `retain` option to `reindex`
- Added support for attributes in highlight tags
- Fixed potentially silent errors in reindex job
- Improved syntax for `boost_by_distance`

## 2.0.1

- Added `search_hit` and `search_highlights` methods to models
- Improved reindex performance

## 2.0.0

- Added support for `reindex` on associations

Breaking changes

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

## 1.5.1

- Added `client_options`
- Added `refresh` option to `reindex` method
- Improved syntax for partial reindex

## 1.5.0

- Added support for geo shape indexing and queries
- Added `_and`, `_or`, `_not` to `where` option

## 1.4.2

- Added support for directional synonyms
- Easier AWS setup
- Fixed `total_docs` method for ES 5+
- Fixed exception on update errors

## 1.4.1

- Added `partial_reindex` method
- Added `debug` option to `search` method
- Added `profile` option

## 1.4.0

- Official support for Elasticsearch 5
- Boost exact matches for partial matching
- Added `searchkick_debug` method
- Added `geo_polygon` filter

## 1.3.6

- Fixed `Job adapter not found` error

## 1.3.5

- Added support for Elasticsearch 5.0 beta
- Added `request_params` option
- Added `filterable` option

## 1.3.4

- Added `resume` option to reindex
- Added search timeout to payload

## 1.3.3

- Fix for namespaced models (broken in 1.3.2)

## 1.3.2

- Added `body_options` option
- Added `date_histogram` aggregation
- Added `indices_boost` option
- Added support for multiple conversions

## 1.3.1

- Fixed error with Ruby 2.0
- Fixed error with indexing large fields

## 1.3.0

- Added support for Elasticsearch 5.0 alpha
- Added support for phrase matches
- Added support for procs for `index_prefix` option

## 1.2.1

- Added `multi_search` method
- Added support for routing for Elasticsearch 2
- Added support for `search_document_id` and `search_document_type` in models
- Fixed error with instrumentation for searching multiple models
- Fixed instrumentation for bulk updates

## 1.2.0

- Fixed deprecation warnings with `alias_method_chain`
- Added `analyzed_only` option for large text fields
- Added `encoder` option to highlight
- Fixed issue in `similar` method with `per_page` option
- Added basic support for multiple models

## 1.1.2

- Added bulk updates with `callbacks` method
- Added `bulk_delete` method
- Added `search_timeout` option
- Fixed bug with new location format for `boost_by_distance`

## 1.1.1

- Added support for `{lat: lat, lon: lon}` as preferred format for locations

## 1.1.0

- Added `below` option to misspellings to improve performance
- Fixed synonyms for `word_*` partial matches
- Added `searchable` option
- Added `similarity` option
- Added `match` option
- Added `word` option
- Added highlighted fields to `load: false`

## 1.0.3

- Added support for Elasticsearch 2.1

## 1.0.2

- Throw `Searchkick::ImportError` for errors when importing records
- Errors now inherit from `Searchkick::Error`
- Added `order` option to aggregations
- Added `mapping` method

## 1.0.1

- Added aggregations method to get raw response
- Use `execute: false` for lazy loading
- Return nil when no aggs
- Added emoji search

## 1.0.0

- Added support for Elasticsearch 2.0
- Added support for aggregations
- Added ability to use misspellings for partial matches
- Added `fragment_size` option for highlight
- Added `took` method to results

Breaking changes

- Raise `Searchkick::DangerousOperation` error when calling reindex with scope
- Enabled misspellings by default for partial matches
- Enabled transpositions by default for misspellings

## 0.9.1

- `and` now matches `&`
- Added `transpositions` option to misspellings
- Added `boost_mode` and `log` options to `boost_by`
- Added `prefix_length` option to `misspellings`
- Added ability to set env

## 0.9.0

- Much better performance for where queries if no facets
- Added basic support for regex
- Added support for routing
- Made `Searchkick.disable_callbacks` thread-safe

## 0.8.7

- Fixed Mongoid import

## 0.8.6

- Added support for NoBrainer
- Added `stem_conversions: false` option
- Added support for multiple `boost_where` values on the same field
- Added support for array of values for `boost_where`
- Fixed suggestions with partial match boost
- Fixed redefining existing instance methods in models

## 0.8.5

- Added support for Elasticsearch 1.4
- Added `unsearchable` option
- Added `select: true` option
- Added `body` option

## 0.8.4

- Added `boost_by_distance`
- More flexible highlight options
- Better `env` logic

## 0.8.3

- Added support for ActiveJob
- Added `timeout` setting
- Fixed import with no records

## 0.8.2

- Added `async` to `callbacks` option
- Added `wordnet` option
- Added `edit_distance` option to eventually replace `distance` option
- Catch misspelling of `misspellings` option
- Improved logging

## 0.8.1

- Added `search_method_name` option
- Fixed `order` for array of hashes
- Added support for Mongoid 2

## 0.8.0

- Added support for Elasticsearch 1.2

## 0.7.9

- Added `tokens` method
- Added `json` option
- Added exact matches
- Added `prev_page` for Kaminari pagination
- Added `import` option to reindex

## 0.7.8

- Added `boost_by` and `boost_where` options
- Added ability to boost fields - `name^10`
- Added `select` option for `load: false`

## 0.7.7

- Added support for automatic failover
- Fixed `operator` option (and default) for partial matches

## 0.7.6

- Added `stats` option to facets
- Added `padding` option

## 0.7.5

- Do not throw errors when index becomes out of sync with database
- Added custom exception types
- Fixed `offset` and `offset_value`

## 0.7.4

- Fixed reindex with inheritance

## 0.7.3

- Fixed multi-index searches
- Fixed suggestions for partial matches
- Added `offset` and `length` for improved pagination

## 0.7.2

- Added smart facets
- Added more fields to `load: false` result
- Fixed logging for multi-index searches
- Added `first_page?` and `last_page?` for improved Kaminari support

## 0.7.1

- Fixed huge issue w/ zero-downtime reindexing on 0.90

## 0.7.0

- Added support for Elasticsearch 1.1
- Dropped support for Elasticsearch below 0.90.4 (unfortunate side effect of above)

## 0.6.3

- Removed patron since no support for Windows
- Added error if `searchkick` is called multiple times

## 0.6.2

- Added logging
- Fixed index_name option
- Added ability to use proc as the index name

## 0.6.1

- Fixed huge issue w/ zero-downtime reindexing on 0.90 and elasticsearch-ruby 1.0
- Restore load: false behavior
- Restore total_entries method

## 0.6.0

- Moved to elasticsearch-ruby
- Added support for modifying the query and viewing the response
- Added support for page_entries_info method

## 0.5.3

- Fixed bug w/ word_* queries

## 0.5.2

- Use after_commit hook for ActiveRecord to prevent data inconsistencies

## 0.5.1

- Replaced stop words with common terms query
- Added language option
- Fixed bug with empty array in where clause
- Fixed bug with MongoDB integer _id
- Fixed reindex bug when callbacks disabled

## 0.5.0

- Better control over partial matches
- Added merge_mappings option
- Added batch_size option
- Fixed bug with nil where clauses

## 0.4.2

- Added `should_index?` method to control which records are indexed
- Added ability to temporarily disable callbacks
- Added custom mappings

## 0.4.1

- Fixed issue w/ inheritance mapping

## 0.4.0

- Added support for Mongoid 4
- Added support for multiple locations

## 0.3.5

- Added facet ranges
- Added all operator

## 0.3.4

- Added highlighting
- Added :distance option to misspellings
- Fixed issue w/ BigDecimal serialization

## 0.3.3

- Better error messages
- Added where: {field: nil} queries

## 0.3.2

- Added support for single table inheritance
- Removed Tire::Model::Search

## 0.3.1

- Added index_prefix option
- Fixed ES issue with incorrect facet counts
- Added option to turn off special characters

## 0.3.0

- Fixed reversed coordinates
- Added bounded by a box queries
- Expanded `or` queries

## 0.2.8

- Added option to disable callbacks
- Fixed bug with facets with Elasticsearch 0.90.5

## 0.2.7

- Added limit to facet
- Improved similar items

## 0.2.6

- Added option to disable misspellings

## 0.2.5

- Added geospartial searches
- Create alias before importing document if no alias exists
- Fixed exception when :per_page option is a string
- Check `RAILS_ENV` if `RACK_ENV` is not set

## 0.2.4

- Use `to_hash` instead of `as_json` for default `search_data` method
- Works for Mongoid 1.3
- Use one shard in test environment for consistent scores

## 0.2.3

- Setup Travis
- Clean old indices before reindex
- Search for `*` returns all results
- Fixed pagination
- Added `similar` method

## 0.2.2

- Clean old indices after reindex
- More expansions for fuzzy queries

## 0.2.1

- Added Rails logger
- Only fetch ids when `load: true`

## 0.2.0

- Added autocomplete
- Added “Did you mean” suggestions
- Added personalized searches

## 0.1.4

- Bug fix

## 0.1.3

- Changed edit distance to one for misspellings
- Raise errors when indexing fails
- Fixed pagination
- Fixed :include option

## 0.1.2

- Launch
