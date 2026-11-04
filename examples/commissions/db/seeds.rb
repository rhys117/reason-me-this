facts = YAML.load_file(Rails.root.join('db/seeds/full_year.yml'), permitted_classes: [Date])
cancelled = facts['cancellations'].to_h { |cancellation| [cancellation['deal'], cancellation['on']] }

rep = Rep.find_or_create_by!(name: 'Avery Quinn')
rep.deals.destroy_all
rep.quarter_targets.destroy_all

facts['deals'].each do |deal|
  rep.deals.create!(code: deal['id'], closed_on: deal['closed'], total_value: deal['total_value'], years: deal['years'],
                    discount: deal['discount'], kind: deal['kind'], share: deal.fetch('share', 1), cancelled_on: cancelled[deal['id']])
end

facts['quarters'].each do |quarter|
  rep.quarter_targets.create!(starts_on: quarter['start'], ends_on: quarter['finish'], quota: quarter['quota'],
                              target_incentive: quarter['target_incentive'], draw: quarter['draw'])
end
