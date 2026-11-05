require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:golfers) { |table| table.decimal :handicap_index }
  create_table :rounds do |table|
    table.references :golfer
    table.decimal :differential
    table.integer :stableford_points
    table.integer :daily_handicap
  end
  create_table :hole_scores do |table|
    table.references :round
    table.integer :hole
    table.integer :points
    table.integer :adjusted
  end
end

class Golfer < ActiveRecord::Base
  has_many :rounds
end

class HoleScore < ActiveRecord::Base
  belongs_to :round
  validates :points, numericality: {greater_than_or_equal_to: 0}
end

module Records
  def self.included(group) = group.before { %w[hole_scores rounds golfers].each { |table| ActiveRecord::Base.connection.execute("DELETE FROM #{table}") } }

  def golf_trace(points: %w[2 3])
    {'outputs' => {'gross_differential' => '11.2', 'stableford' => '44', 'new_ga_handicap' => '16.4'},
     'steps' => [{'step' => 'card', 'value' => {},
                  'steps' => [{'step' => 'daily_handicap', 'value' => '23'},
                              {'step' => 'scored', 'value' => points.each_with_index.map do |each, index|
                                {'hole' => (index + 1).to_s, 'points' => each, 'adjusted' => '5'}
                              end}]}]}
  end
end
