class Deal < ApplicationRecord
  belongs_to :rep

  scope :closed_in, -> (year) { where(closed_on: Date.new(year).all_year).order(:closed_on) }
  scope :cancelled_in, -> (year) { where(cancelled_on: Date.new(year).all_year).order(:cancelled_on) }

  def to_fact = {id: code, closed: closed_on, total_value:, years:, discount:, kind:, share:}

  def to_cancellation = {deal: code, on: cancelled_on}
end
