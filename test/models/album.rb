class Album
  searchkick unscope: { where: [:active, :sold] }
end
