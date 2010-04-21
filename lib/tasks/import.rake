require File.join(File.dirname(__FILE__), 'rake_helper')

namespace :import do

  desc "Import School Areas from Legacy Areas"
  task :school_areas => :rename_tables do
    ImportSchoolAreas.new.execute!
  end

  desc "Import School from Legacy Cursos"
  task :schools => :school_areas do
    ImportSchools.new.execute!
  end

  desc "Import Periods from Legacy Turnos"
  task :periods => :rename_tables do
    ImportPeriods.new.execute!
  end

  desc "Import Curriculums from Legacy Curriculum"
  task :curriculum => [:create_views, :schools, :periods] do
    ImportCurriculums.new.execute!
  end

  desc "Import all tables from Legacy"
  task :all => [:curriculum]

  desc "Rename tables before execute import tasks"
  task :rename_tables => :environment do
    rset = Academnew.connection.execute("show tables")
    old_tables_name = Array.new
    new_tables_name = Array.new
    rset.each{|e| old_tables_name << e.first}
    old_tables_name.each do |e|
      new_tables_name << e.dup
    end
    new_tables_name.each{|e| e.gsub!($&, "_#{$&.downcase}") while e =~ /[A-Z]/ ; e.sub!(/^_/,"")}
    while new_tables_name.first and old_tables_name.first
      new_table = new_tables_name.shift
      old_table = old_tables_name.shift
      if old_table != new_table
        query = "rename table #{old_table} to #{new_table}"
        Academnew.connection.execute(query)
      end
    end
  end

  desc "Create views to support import tasks"
  task :create_views => :rename_tables do
    Academnew.connection.execute("drop view if exists curriculum")
    Academnew.connection.execute(<<-SQL)
      create view curriculum as
      select * from compl_estruturas_curriculares 
        natural join estruturas_curriculares;
    SQL
  end

end
