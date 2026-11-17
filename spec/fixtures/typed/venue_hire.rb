# typed: strict

# Hiring a venue by the hour, with every kind of step. The rates are illustrative.
VENUE_HIRE = ReasonMeThis::Blueprint.define do
  table :periods, [{until: 7, period: 'late'}, {until: 18, period: 'daytime'}, {until: 21, period: 'evening'}, {period: 'late'}]
  table :rates, [{period: 'daytime', hourly: 60}, {period: 'evening', hourly: 80}, {period: 'late', hourly: 100}]
  table :discounts, [{members: '>= 10', day: %w[sat sun], discount: 5}, {members: '>= 10', discount: 10}]

  calculation :booking do
    inputs do
      list :sessions do
        time :from
        time :to
        string :room, optional: true
      end
      list :breaks, default: []
      number :overtime_after, default: 480
      number :overtime_loading, default: BigDecimal('1.5')
      number :members, default: 0
      string :day, default: 'mon', one_of: %w[mon sat sun]
      string :usual_period, default: 'daytime', one_of: {table: :rates, column: :period}
      boolean :deposit_paid, default: false
    end

    slice :pieces, over: :sessions, without: :breaks, at_hours: [0, 7, 18, 21],
                   after: {minutes: 'overtime_after', per: 'DATE(from)', tag: :overtime}
    run :priced, :piece, over: :pieces, position: :place
    sum :minutes, :minutes, of: :priced
    sum :cost, :amount, of: :priced
    group :by_period, of: :priced, by: [:period], sum: [:amount]
    decide :discount, table: :discounts, given: {members: :members, day: :day}, hit: :first, value: :discount, default: 0
    rules :loyalty, pick: :highest, otherwise: 0 do
      rule :club, 'members >= 50', value: 15
      rule :group, 'members >= 20', value: 12
    end
    compare :off, [:discount, :loyalty]
    formula :total, 'ROUND(cost * (100 - off) / 100, 2)'
    formula(:deposit, 'ROUND(total * 0.2, 2)').when('NOT(deposit_paid)', else: 0)
    repeat :instalments, :instalment, times: 3, position: :number, with: {total: 'total'}
    step :note, :formula, 'CONCAT("Booked for ", minutes, " minutes")'

    outputs :priced, :minutes, :by_period, :off, :total, :instalments
    output :deposit, type: :number
    event :long_booking, 'minutes > 600', data: [:minutes]
  end

  calculation :piece do
    inputs do
      time :from
      number :minutes
      boolean :overtime
      number :overtime_loading
      number :place
    end

    formula :hour, 'HOUR(from)'
    lookup :period, table: :periods, value: :period, band: {by: :hour, below: :until}
    lookup :hourly, table: :rates, where: {period: :period}, value: :hourly
    formula :loading, 'IF(overtime, overtime_loading, 1)'
    formula :amount, 'minutes / 60 * hourly * loading'

    outputs :from, :minutes, :period, :overtime, :amount
  end

  calculation :instalment do
    inputs do
      number :total
      number :number
    end

    formula :due, 'ROUND(total / 3, 2)'
    outputs :number, :due
  end
end #: ReasonMeThis::Blueprint
