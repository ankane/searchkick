require_relative "test_helper"

describe "Model#should_index?" do
  it 'Model.reindex checks for #should_index?' do
    indexed = Animal.new(name: 'should')
    indexed.stubs(:should_index?).returns(true)

    not_indexed = Animal.new(name: 'should not')
    not_indexed.stubs(:should_index?).returns(false)

    [indexed, not_indexed].each(&:save!)
    Animal.searchkick_index.refresh

    assert_search 'should', ['should'], {}, Animal
  end

  it 'Model#reindex checks for #should_index?' do
    Animal.any_instance.stubs(:should_index?).returns(false)
    store_names ['should not', 'shouldnt'], Animal

    Animal.reindex
    Animal.searchkick_index.refresh

    assert_search 'should', [], {}, Animal
  end

  it 'indexes existing model after the #should_index? switched to true' do
    subject = Animal.new(name: 'should')
    subject.stubs(:should_index?).returns(false)
    subject.save!

    subject.stubs(:should_index?).returns(true)
    subject.save!

    Animal.searchkick_index.refresh
    assert_search 'should', ['should'], {}, Animal
  end

  it 'removes the existing model from index after the #should_index? switched to false' do
    subject = Animal.new(name: 'should')
    subject.stubs(:should_index?).returns(true)
    subject.save!

    subject.stubs(:should_index?).returns(false)
    subject.save!

    Animal.searchkick_index.refresh
    assert_search 'should', [], {}, Animal
  end
end
