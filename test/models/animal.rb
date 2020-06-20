class Animal
  searchkick \
    inheritance: true,
    text_start: [:name],
    suggest: [:name],
    index_name: -> { "#{name.tableize}-#{Date.today.year}#{Searchkick.index_suffix}" },
    callbacks: :async,
    wordnet: ENV["WORDNET"]
end
