module ApplicationHelper
  def dollars(amount) = number_to_currency(amount, precision: 0)
end
