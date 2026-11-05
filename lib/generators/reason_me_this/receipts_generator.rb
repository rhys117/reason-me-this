require 'rails/generators'
require 'rails/generators/active_record'

module ReasonMeThis
  module Generators
    class ReceiptsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      desc 'Adds the reason_me_this_receipts table, where reasonings that keep receipts record what ran and how.'

      def create_migration_file
        migration_template 'create_reason_me_this_receipts.rb.tt', File.join(db_migrate_path, 'create_reason_me_this_receipts.rb')
      end
    end
  end
end
