require_relative "test_helper"

class SqlTest < Minitest::Test
  def test_operator
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], operator: "or"
  end

  def test_operator_scoring
    store_names ["Big Red Circle", "Big Green Circle", "Small Orange Circle"]
    assert_order "big red circle", ["Big Red Circle", "Big Green Circle", "Small Orange Circle"], operator: "or"
  end

  def test_fields_operator
    store [
      {name: "red", color: "red"},
      {name: "blue", color: "blue"},
      {name: "cyan", color: "blue green"},
      {name: "magenta", color: "red blue"},
      {name: "green", color: "green"}
    ]
    assert_search "red blue", ["red", "blue", "cyan", "magenta"], operator: "or", fields: ["color"]
  end

  def test_fields
    store [
      {name: "red", color: "light blue"},
      {name: "blue", color: "red fish"}
    ]
    assert_search "blue", ["red"], fields: ["color"]
  end

  def test_non_existent_field
    store_names ["Milk"]
    assert_search "milk", [], fields: ["not_here"]
  end

  def test_fields_both_match
    store [
      {name: "Blue A", color: "red"},
      {name: "Blue B", color: "light blue"}
    ]
    assert_first "blue", "Blue B", fields: [:name, :color]
  end

  def test_big_decimal
    store [
      {name: "Product", latitude: 80.0}
    ]
    assert_search "product", ["Product"], where: {latitude: {gt: 79}}
  end

  # body_options

  def test_body_options_should_merge_into_body
    query = Product.search("*", body_options: {min_score: 1.0}, execute: false)
    assert_equal 1.0, query.body[:min_score]
  end

  # load

  def test_load_default
    store_names ["Product A"]
    assert_kind_of Product, Product.search("product").first
  end

  def test_load_false
    store_names ["Product A"]
    assert_kind_of Hash, Product.search("product", load: false).first
  end

  def test_load_false_methods
    store_names ["Product A"]
    assert_equal "Product A", Product.search("product", load: false).first.name
  end

  def test_load_false_with_includes
    store_names ["Product A"]
    assert_kind_of Hash, Product.search("product", load: false, includes: [:store]).first
  end

  def test_load_false_nested_object
    aisle = {"id" => 1, "name" => "Frozen"}
    store [{name: "Product A", aisle: aisle}]
    assert_equal aisle, Product.search("product", load: false).first.aisle.to_hash
  end

  # select

  def test_select
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: [:name, :store_id]).first
    assert_equal %w(id name store_id), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_select_array
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: [:user_ids]).first
    assert_equal [1, 2], result.user_ids
  end

  def test_select_single_field
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: :name).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_select_all
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: true).hits.first
    assert_equal hit["_source"]["name"], "Product A"
    assert_equal hit["_source"]["user_ids"], [1, 2]
  end

  def test_select_none
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: []).hits.first
    assert_nil hit["_source"]
    hit = Product.search("product", select: false).hits.first
    assert_nil hit["_source"]
  end

  def test_select_includes
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: {includes: [:name]}).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_select_excludes
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {excludes: [:name]}).first
    assert_nil result.name
    assert_equal [1, 2], result.user_ids
    assert_equal 1, result.store_id
  end

  def test_select_include_and_excludes
    # let's take this to the next level
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {includes: [:store_id], excludes: [:name]}).first
    assert_equal 1, result.store_id
    assert_nil result.name
    assert_nil result.user_ids
  end

  # nested

  def test_nested_search
    store [{name: "Product A", aisle: {"id" => 1, "name" => "Frozen"}}], Speaker
    assert_search "frozen", ["Product A"], {fields: ["aisle.name"]}, Speaker
  end

  def test_nested_one_level
    store [
      {name: 'Jim', reviews: [Review.create(name: 'Review A')]},
      {name: 'Bob', reviews: [Review.create(name: 'Review B')]},
      {name: 'Karen', reviews: [Review.create(name: 'Review C')]}
    ], Employee

    assert_search "Employee", ['Bob'], {where: {
                                                 nested: {
                                                   path: 'reviews',
                                                   where: {
                                                     name: 'Review B'
                                                   }
                                                 }
                                               }
                                           }, Employee
  end

  def test_where_nested
    store [
      {name: 'Amazon', employees: [
        Employee.create(name: 'Jim', age: 22, reviews: [
          Review.create(name: 'Review A', stars: 3, comments: [
            Comment.create(status: 'denied', message: 'bad')
          ])
        ]),
        Employee.create(name: 'Jamie', age: 32, reviews: [
          Review.create(name: 'Review C', stars: 5, comments: [
            Comment.create(status: 'denied', message: 'bad')
          ])
        ])
      ]},
      {name: 'Costco', employees: [
        Employee.create(name: 'Bob', age: 34, reviews: [
          Review.create(name: 'Review B', stars: 2, comments: [
            Comment.create(status: 'approved', message: 'good')
          ])
        ])
      ]},
      {name: 'Walmart', employees: [
        Employee.create(name: 'Karen', age: 19, reviews: [
          Review.create(name: 'Review C', stars: 4, comments: [
            Comment.create(status: 'approved', message: 'good'),
            Comment.create(status: 'denied', message: 'good')
          ])
        ])
      ]}
    ], Store

    assert_search "store", ["Amazon"], { where: {
                                           name: 'Amazon',
                                           nested: {
                                             path: 'employees',
                                             where: {
                                               'name' => 'Jim'
                                             }
                                           }
                                         }
                                       }, Store

    assert_search "store", [], { where: {
                                   name: 'Amazon',
                                   nested: {
                                     path: 'employees',
                                     where: {
                                       'name' => 'Karen',
                                       'age' => 1,
                                     }
                                   }
                                 }
                               }, Store

    assert_search "store", ['Costco'], { where: {
                                           nested: {
                                             path: 'employees',
                                             where: {
                                               'name' => 'Bob',
                                               'age' => 34,
                                             }
                                           }
                                         }
                                       }, Store


    assert_search "store", ['Costco'], { where: {
                                           nested: {
                                             path: 'employees',
                                             where: {
                                               nested: {
                                                 path: 'employees.reviews',
                                                 where: {
                                                   name: 'Review B'
                                                 }
                                               }
                                             }
                                           }
                                         }
                                       }, Store

    assert_search "store", ['Amazon', 'Walmart'], { where: {
                                                      nested: {
                                                        path: 'employees',
                                                        where: {
                                                          nested: {
                                                            path: 'employees.reviews',
                                                            where: {
                                                              name: 'Review C'
                                                            }
                                                          }
                                                        }
                                                      }
                                                    }
                                                  }, Store

    assert_search "store", [], { where: {
                                          nested: {
                                            path: 'employees',
                                            where: {
                                              nested: {
                                                path: 'employees.reviews',
                                                where: {
                                                  name: 'Review F'
                                                }
                                              }
                                            }
                                          }
                                        }
                                      }, Store

    # With all
    result = Store.search "*", { where: {
                                   nested: {
                                     path: 'employees',
                                     where: {
                                       name: 'Jamie'
                                     }
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Amazon'

    result = Store.search "*", { where: {
                                   nested: {
                                     path: 'employees',
                                     where: {
                                       name: 'Bob'
                                     }
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Costco'

    # With range
    result = Store.search "*", { where: {
                                   nested: {
                                     path: 'employees',
                                     where: {
                                       age: {
                                         lt: 20
                                       }
                                     }
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Walmart'

    # Deeply nested
    assert_search "store", ['Walmart'], { where: {
                                            nested: {
                                              path: 'employees',
                                              where: {
                                                age: {
                                                  lt: 20
                                                },
                                                nested: {
                                                  path: 'employees.reviews',
                                                  where: {
                                                    name: 'Review C',
                                                    stars: {
                                                      gt: 3
                                                    },
                                                    nested: {
                                                      path: 'employees.reviews.comments',
                                                      where: {
                                                        status: 'approved'
                                                      }
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }, Store

    assert_search "store", ['Costco', 'Walmart'], { where: {
                                                      nested: {
                                                       path: 'employees',
                                                       where: {
                                                         nested: {
                                                           path: 'employees.reviews',
                                                           where: {
                                                             nested: {
                                                               path: 'employees.reviews.comments',
                                                               where: {
                                                                 status: 'approved',
                                                                 message: 'good'
                                                               }
                                                             }
                                                           }
                                                         }
                                                       }
                                                     }
                                                   }
                                                 }, Store
  end

  def test_nested_json
    store [
      {name: 'Jim', reviews: [Review.create(name: 'Review A')]},
      {name: 'Bob', reviews: [Review.create(name: 'Review B')]},
      {name: 'Karen', reviews: [Review.create(name: 'Review C')]}
    ], Employee

    result = Employee.search({ body: {
                                 query: {
                                   nested: {
                                     path: 'reviews',
                                       query: {
                                         bool: {
                                           must: [
                                             { match: {'reviews.name' => 'Review B'} }
                                           ]
                                         }
                                       }
                                     }
                                   }
                                }
                             })

    assert_equal result.results.first.name, 'Bob'
  end

  # other tests

  def test_includes
    skip unless defined?(ActiveRecord)
    store_names ["Product A"]
    assert Product.search("product", includes: [:store]).first.association(:store).loaded?
  end

  def test_model_includes
    skip unless defined?(ActiveRecord)

    store_names ["Product A"]
    store_names ["Store A"], Store

    associations = {Product => [:store], Store => [:products]}
    result = Searchkick.search("*", index_name: [Product, Store], model_includes: associations)

    assert_equal 2, result.length

    result.group_by(&:class).each_pair do |klass, records|
      assert records.first.association(associations[klass].first).loaded?
    end
  end

  def test_scope_results
    skip unless defined?(ActiveRecord)

    store_names ["Product A", "Product B"]
    assert_search "product", ["Product A"], scope_results: ->(r) { r.where(name: "Product A") }
  end
end
