# typed: strict

# The room hire fixture blueprint, written in Ruby. It is type checked as an app's own strict file would be.
ROOM_HIRE = ReasonMeThis::Blueprint.define do
  calculation :hire do
    inputs do
      number :hours
      number :hourly, default: 60
      date :booked_on, optional: true
    end

    formula :cost, 'hours * hourly'
    formula :total, 'ROUND(cost, 2)'

    outputs :total
    output :booked_on, optional: true
    event :long_hire, 'hours > 8', data: [:total]
  end

  calculation :deposit do
    inputs { number :total }

    formula :due, 'ROUND(total / total * total * 0.2, 2)'
    outputs :due
  end
end #: ReasonMeThis::Blueprint
