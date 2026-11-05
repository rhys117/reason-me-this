require 'rails/generators'
require 'generators/reason_me_this/receipts_generator'
require 'tmpdir'

module Receipts
  def self.migration
    @migration ||= Dir.mktmpdir do |app|
      ReasonMeThis::Generators::ReceiptsGenerator.start([], destination_root: app, quiet: true)
      File.read(Dir[File.join(app, 'db/migrate/*_create_reason_me_this_receipts.rb')].fetch(0))
    end
  end

  def self.create_table
    return if ActiveRecord::Base.connection.table_exists?(:reason_me_this_receipts)

    eval(migration, TOPLEVEL_BINDING) # rubocop:disable Security/Eval
    CreateReasonMeThisReceipts.new.migrate(:up)
  end
end
