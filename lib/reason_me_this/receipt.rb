require 'active_record'

module ReasonMeThis
  class Receipt < ActiveRecord::Base
    self.table_name = 'reason_me_this_receipts'

    belongs_to :record, polymorphic: true
  end
end
