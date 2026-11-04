class QuarterTarget < ApplicationRecord
  belongs_to :rep

  scope :in, -> (year) { where(starts_on: Date.new(year).all_year).order(:starts_on) }

  def to_fact = {start: starts_on, finish: ends_on, quota:, target_incentive:, draw:}.compact
end
