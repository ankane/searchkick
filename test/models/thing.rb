class Thing
  searchkick \
    text_start: [:name],
    suggest: [:name],
    callbacks: :async
end
