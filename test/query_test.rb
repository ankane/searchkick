require_relative "test_helper"

class QueryTest < Minitest::Test
  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", body: {query: {match_all: {}}})
    assert_equal ["Apple", "Milk"], query.map(&:name).sort
  end

  def test_with_uneffective_min_score
    store_names ["Milk", "Milk2"]
    assert_search "milk", ["Milk", "Milk2"], body_options: {min_score: 0.0001}
  end

  def test_default_timeout
    assert_equal "6s", Product.search("*").body[:timeout]
  end

  def test_timeout_override
    assert_equal "1s", Product.search("*", body_options: {timeout: "1s"}).body[:timeout]
  end

  def test_request_params
    assert_equal "dfs_query_then_fetch", Product.search("*", request_params: {search_type: "dfs_query_then_fetch"}).params[:search_type]
  end

  def test_debug
    store_names ["Milk"]
    out, _ = capture_io do
      assert_search "milk", ["Milk"], debug: true
    end
    refute_includes out, "Error"
  end

  def test_big_decimal
    store [
      {name: "Product", latitude: 80.0}
    ]
    assert_search "product", ["Product"], where: {latitude: {gt: 79}}
  end

  # body_options

  def test_body_options_should_merge_into_body
    query = Product.search("*", body_options: {min_score: 1.0})
    assert_equal 1.0, query.body[:min_score]
  end

  # nested

  def test_nested_search
    setup_speaker
    store [{name: "Product A", aisle: {"id" => 1, "name" => "Frozen"}}], Speaker
    assert_search "frozen", ["Product A"], {fields: ["aisle.name"]}, Speaker
  end

  def test_where_multiple_nested
    setup_nested_models

    store [
      {
        name: 'Walmart', employees: [
          Employee.create(name: 'Daniel', age: 32),
          Employee.create(name: 'Kaitlyn', age: 32)
        ]
      }
    ], Store

    result = Store.search('*',
      where: {
        _and: [
          {
            nested: {
              path: 'employees',
              where:  {
                name: 'Daniel'
              }
            }
          },
          {
            nested: {
              path: 'employees',
              where: {
                name: 'Kaitlyn'
              }
            }
          }
        ]
      }
    )

    assert_equal result.results.count, 1

    result = Store.search('*',
      where: {
        _and: [
          {
            nested: {
              path: 'employees',
              where:  {
                name: 'Daniel'
              }
            }
          },
          {
            nested: {
              path: 'employees',
              where: {
                name: 'Charles'
              }
            }
          }
        ]
      }
    )

    assert_equal result.results.count, 0

    result = Store.search('*',
      where: {
        _or: [
          {
            nested: {
              path: 'employees',
              where:  {
                name: 'Daniel'
              }
            }
          },
          {
            nested: {
              path: 'employees',
              where: {
                name: 'Charles'
              }
            }
          }
        ]
      }
    )

    assert_equal result.results.count, 1
  end

  def test_where_nested
    setup_nested_models

    store [
      {name: 'Amazon', employees: [
        Employee.create(name: 'Jim', age: 22, reviews: [
          Review.create(name: 'Review A', stars: 3, comments: [
            Comment.create(status: 'denied', message: 'bad')
          ])
        ], time_cards: [
          TimeCard.create(hours: 5)
        ]),
        Employee.create(name: 'Jamie', age: 32, reviews: [
          Review.create(name: 'Review C', stars: 5, comments: [
            Comment.create(status: 'denied', message: 'bad')
          ])
        ], time_cards: [
          TimeCard.create(hours: 8)
        ])
      ]},
      {name: 'Costco', employees: [
        Employee.create(name: 'Bob', age: 34, reviews: [
          Review.create(name: 'Review B', stars: 2, comments: [
            Comment.create(status: 'approved', message: 'good')
          ])
        ], time_cards: [
          TimeCard.create(hours: 7)
        ])
      ]},
      {name: 'Walmart', employees: [
        Employee.create(name: 'Karen', age: 19, reviews: [
          Review.create(name: 'Review C', stars: 4, comments: [
            Comment.create(status: 'approved', message: 'good'),
            Comment.create(status: 'denied', message: 'good')
          ])
        ], time_cards: [
          TimeCard.create(hours: 12)
        ])
      ]}
    ], Store

    # Single nested
    result = Store.search('*',
      where: {
        name_as_keyword: 'Amazon',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Jim'
          }
        }
      }
    )

    assert_equal result.results.count, 1

    result = Store.search('Amazon',
      where: {
        name_as_keyword: 'Amazon',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Jim'
          }
        }
      }
    )

    assert_equal result.results.count, 1

    result = Store.search('foo',
      where: {
        name_as_keyword: 'Amazon',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Jim'
          }
        }
      }
    )

    assert_equal result.results.count, 0

    result = Store.search('*',
      where: {
        name_as_keyword: 'Amazon',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Karen',
            'age' => 1,
          }
        }
      }
    )

    assert_equal result.results.count, 0

    result = Store.search('*',
      where: {
        name_as_keyword: 'Amazon',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Bob',
            'age' => 34,
          }
        }
      }
    )

    assert_equal result.results.count, 0

    result = Store.search('*',
      where: {
        name_as_keyword: 'Costco',
        nested: {
          path: 'employees',
          where: {
            'name' => 'Bob',
            'age' => 34,
          }
        }
      }
    )

    assert_equal result.results.count, 1

    # multiple nested
    result = Store.search('*',
      where: {
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
    )

    assert_equal result.results.count, 1

    result = Store.search('Costco',
      where: {
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
    )

    assert_equal result.results.count, 1

    result = Store.search('Amazon',
      where: {
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
    )

    assert_equal result.results.count, 0

    # Nested sibling documents
    result = Store.search('*',
      where: {
        nested: {
          path: 'employees',
          where: {
            nested: [
              {
                path: 'employees.reviews',
                where: {
                  name: 'Review C'
                }
              },
              {
                path: 'employees.time_cards',
                where: {
                  hours: {gt: 5}
                }
              }
            ]
          }
        }
      }
    )

    assert_equal result.results.count, 2

    result = Store.search('*',
      where: {
        nested: {
          path: 'employees',
          where: {
            nested: [
              {
                path: 'employees.reviews',
                where: {
                  name: 'Review C'
                }
              },
              {
                path: 'employees.time_cards',
                where: {
                  hours: {gt: 9}
                }
              }
            ]
          }
        }
      }
    )

    assert_equal result.results.count, 1

    result = Store.search('foo',
      where: {
        nested: {
          path: 'employees',
          where: {
            nested: [
              {
                path: 'employees.reviews',
                where: {
                  name: 'Review C'
                }
              },
              {
                path: 'employees.time_cards',
                where: {
                  hours: {gt: 9}
                }
              }
            ]
          }
        }
      }
    )

    assert_equal result.results.count, 0

    # With all
    result = Store.search "*", where: {
                                 nested: {
                                   path: 'employees',
                                   where: {
                                     name: 'Jamie'
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Amazon'

    result = Store.search "*", where: {
                                 nested: {
                                   path: 'employees',
                                   where: {
                                     name: 'Bob'
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Costco'

    # With range
    result = Store.search "*", where: {
                                 nested: {
                                   path: 'employees',
                                   where: {
                                     age: {
                                       lt: 20
                                     }
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Walmart'

    # Deeply nested
    result = Store.search('*',
      where: {
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
    )

    assert_equal result.results.count, 1

    result = Store.search('Walmart',
      where: {
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
    )

    assert_equal result.results.count, 1

    result = Store.search('Amazon',
      where: {
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
    )

    assert_equal result.results.count, 0

    result = Store.search('Walmart Amazon',
      operator: 'or',
      where: {
        nested: {
          path: 'employees',
          where: {
            age: {
              lt: 40
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
                    status: /.*(approved|denied).*/
                  }
                }
              }
            }
          }
        }
      }
    )

    assert_equal result.results.count, 2
  end

  def test_json_field
    setup_nested_models

    store [
      {name: 'Amazon', nested_json: {foo: 'bar', nested_field: {name: 'test1'}}},
      {name: 'Costco', nested_json: {foo: 'boo', nested_field: {name: 'test2'}}},
      {name: 'Walmart', nested_json: {foo: 'boo', nested_field: {name: 'test3'}}}
    ], Store

    # Flattened dot notation
    result = Store.search "*", where: {
                                 'nested_json.nested_field.name': 'test1'
                               }

    assert_equal result.results.first.name, 'Amazon'

    # Directly access nested JSON field
    result = Store.search "*", where: {
                                 name_as_keyword: 'Amazon',
                                 nested: {
                                   path: 'nested_field',
                                   where: {
                                     name: 'test1'
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Amazon'

    # Access JSON from field then nested mapping
    result = Store.search "*", where: {
                                 name_as_keyword: 'Amazon',
                                 nested_json: {
                                   foo: 'bar',
                                   nested: {
                                     path: 'nested_field',
                                     where: {
                                       name: 'test1'
                                     }
                                   }
                                 }
                               }

    assert_equal result.results.first.name, 'Amazon'
  end

  def test_nested_json
    setup_nested_models

    store [
      {name: 'Jim', reviews: [Review.create(name: 'Review A')]},
      {name: 'Bob', reviews: [Review.create(name: 'Review B')]},
      {name: 'Karen', reviews: [Review.create(name: 'Review C')]}
    ], Employee

    result = Employee.search(body: {
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
                           )

    assert_equal result.results.first.name, 'Bob'
  end

  # other tests

  def test_includes
    skip unless activerecord?

    store_names ["Product A"]
    assert Product.search("product", includes: [:store]).first.association(:store).loaded?
    assert Product.search("product").includes(:store).first.association(:store).loaded?
  end

  def test_model_includes
    skip unless activerecord?

    store_names ["Product A"]
    store_names ["Store A"], Store

    associations = {Product => [:store], Store => [:products]}
    result = Searchkick.search("*", models: [Product, Store], model_includes: associations)

    assert_equal 2, result.length

    result.group_by(&:class).each_pair do |model, records|
      assert records.first.association(associations[model].first).loaded?
    end
  end

  def test_scope_results
    skip unless activerecord?

    store_names ["Product A", "Product B"]
    assert_warns "Records in search index do not exist in database" do
      assert_search "product", ["Product A"], scope_results: ->(r) { r.where(name: "Product A") }
    end
  end
end
