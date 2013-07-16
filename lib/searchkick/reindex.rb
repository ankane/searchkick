module Searchkick
  module Reindex

    # https://gist.github.com/jarosan/3124884
    def reindex
      alias_name = tire.index.name
      new_index = alias_name + "_" + Time.now.strftime("%Y%m%d%H%M%S")

      # Rake::Task["tire:import"].invoke
      index = Tire::Index.new(new_index)
      Tire::Tasks::Import.create_index(index, self)
      scope = respond_to?(:searchkick_import) ? searchkick_import : self
      scope.find_in_batches do |batch|
        index.import batch
      end

      if a = Tire::Alias.find(alias_name)
        puts "[IMPORT] Alias found: #{Tire::Alias.find(alias_name).indices.to_ary.join(",")}"
        old_indices = Tire::Alias.find(alias_name).indices
        old_indices.each do |index|
          a.indices.delete index
        end

        a.indices.add new_index
        a.save

        old_indices.each do |index|
          puts "[IMPORT] Deleting index: #{index}"
          i = Tire::Index.new(index)
          i.delete if i.exists?
        end
      else
        puts "[IMPORT] No alias found. Deleting index, creating new one, and setting up alias"
        i = Tire::Index.new(alias_name)
        i.delete if i.exists?
        Tire::Alias.create(name: alias_name, indices: [new_index])
      end

      puts "[IMPORT] Saved alias #{alias_name} pointing to #{new_index}"
      true
    end

  end
end
