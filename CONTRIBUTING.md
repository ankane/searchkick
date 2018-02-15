# Contributing

First, thanks for wanting to contribute. You’re awesome! :heart:

## Questions

Use [Stack Overflow](https://stackoverflow.com/) with the tag `searchkick`.

## Feature Requests

Create an issue. Start the title with `[Idea]`.

## Issues

Think you’ve discovered an issue?

1. Search existing issues to see if it’s been reported.
2. Try the `master` branch to make sure it hasn’t been fixed.

```rb
gem "searchkick", github: "ankane/searchkick"
```

3. Try the `debug` option when searching. This can reveal useful info.

```ruby
Product.search("something", debug: true)
```

If the above steps don’t help, create an issue.

- For incorrect search results, recreate the problem by forking [this gist](https://gist.github.com/ankane/f80b0923d9ae2c077f41997f7b704e5c). Include a link to your gist and the output in the issue.
- For exceptions, include the complete backtrace.

## Pull Requests

Fork the project and create a pull request. A few tips:

- Keep changes to a minimum. If you have multiple features or fixes, submit multiple pull requests.
- Follow the existing style. The code should read like it’s written by a single person.
- Add one or more tests if possible. Make sure existing tests pass with:

```sh
bundle exec rake test
```

Feel free to open an issue to get feedback on your idea before spending too much time on it.

---

This contributing guide is released under [CCO](https://creativecommons.org/publicdomain/zero/1.0/) (public domain). Use it for your own project without attribution.
