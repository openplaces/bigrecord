require 'rails_generator/generators/components/migration/migration_generator'

class BigrecordMigrationGenerator < MigrationGenerator

  def manifest

    record do |m|
      m.migration_template 'migration.rb', 'db/bigrecord_migrate', :assigns => get_local_assigns
    end

  end

end
