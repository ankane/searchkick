class Employee
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      properties: {
        name: {type: "keyword"},
        age: {type: "keyword"},
        reviews: {
          type: 'nested'
        },
        time_cards: {
          type: 'nested'
        }
      }
    }

  def search_document_id
    id
  end

  def search_routing
    name
  end

  def search_data
    serializable_hash.except("id", "_id").merge(
      name: name,
      reviews: {
        name: reviews.last.try(:name)
      },
      time_cards: {
        hours: time_cards.last.try(:hours)
      }
    )
  end
end
