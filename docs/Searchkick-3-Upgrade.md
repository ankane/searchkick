# Searchkick 3 Upgrade

## Before You Upgrade

Searchkick 3 no longer uses types, since they are deprecated in Elasticsearch 6.

If you use inheritance, add to your parent model:

```ruby
class Animal < ApplicationRecord
  searchkick inheritance: true
end
```

And do a full reindex before upgrading.

## Upgrading

Update your Gemfile:

```ruby
gem 'searchkick', '~> 3'
```

And run:

```sh
bundle update searchkick
```

We recommend you don’t stem conversions anymore, so conversions for `pepper` don’t affect `peppers`, but if you want to keep the old behavior, use:

```ruby
Searchkick.model_options = {
  stem_conversions: true
}
```

Searchkick 3 disables the `_all` field by default, since Elasticsearch 6 removes the ability to reindex with it. If you’re on Elasticsearch 5 and still need it, add to your model:

```ruby
class Product < ApplicationRecord
  searchkick _all: true
end
```

If you use `record.reindex_async` or `record.reindex(async: true)`, replace it with:

```ruby
record.reindex(mode: :async)
```

If you use `log: true` with `boost_by`, replace it with `modifier: "ln2p"`.

If you use the `body` option and have warnings about incompatible options, remove them, as they now throw an `ArgumentError`.

Check out the [changelog](https://github.com/ankane/searchkick/blob/master/CHANGELOG.md) for the full list of changes.
