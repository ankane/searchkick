class Animal
  searchkick \
    inheritance: true,
    text_start: [:name],
    suggest: [:name]

  def full_name_data
    { full_name: "#{name} the #{type}" }
  end
end
