module SeededRep
  def self.included(group)
    group.let(:rep) do
      load Rails.root.join('db/seeds.rb')
      Rep.find_by!(name: 'Avery Quinn')
    end
  end
end
