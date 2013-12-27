## 0.4.2 [unreleased]

- Added `should_index?` method to control which records are indexed
- Added ability to temporarily disable callbacks

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
