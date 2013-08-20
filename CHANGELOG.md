## 0.2.4 [unreleased]

- Use `to_hash` instead of `as_json` for default `search_data` method
- Works for Mongoid 1.3

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
