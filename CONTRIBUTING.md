# Contributing

First, thanks for wanting to contribute. You’re awesome! :heart:

## Help

We’re not able to provide support through GitHub Issues. If you’re looking for help with your code, try posting on [Stack Overflow](https://stackoverflow.com/).

All features should be documented. If you don’t see a feature in the docs, assume it doesn’t exist.

## Bugs

Think you’ve discovered a bug?

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

- Recreate the problem by forking [this gist](https://gist.github.com/ankane/f80b0923d9ae2c077f41997f7b704e5c). Include a link to your gist and the output in the issue.
- For exceptions, include the complete backtrace.

## New Features

If you’d like to discuss a new feature, create an issue and start the title with `[Idea]`.

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
