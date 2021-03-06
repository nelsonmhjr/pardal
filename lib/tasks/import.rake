def verbose(task)
  puts "== import:#{task} -- importing ".ljust(60, "=")
  i = Time.now.to_f
  yield
  e = Time.now.to_f
  seconds = (e-i)
  puts "== import:#{task} -- imported (#{'%.4f' % seconds}) ".ljust(60, "=")
  puts ""
end

namespace :import do

  desc "Import Departments from Legacy Departments"
  task :departments => :environment do
    verbose(:departments) { ImportDepartments.new.execute! }
  end

  desc "Import Periods from Legacy Turnos"
  task :periods => :environment do
    verbose(:periods) { ImportPeriods.new.execute! }
  end

  desc "Import School Areas from Legacy Areas"
  task :school_areas => :environment do
    verbose(:school_areas) { ImportSchoolAreas.new.execute! }
  end

  desc "Import Disciplines from Legacy Disciplinas"
  task :disciplines => :environment do
    verbose(:disciplines) { ImportDisciplines.new.execute! }
  end

  desc "Import School from Legacy Cursos"
  task :schools => :environment do
    verbose(:schools) { ImportSchools.new.execute! }
  end

  desc "Import Implementation from Legacy ComposicoesEstrutCurriculares"
  task :implementations => :environment do
    verbose(:implementations) { ImportImplementations.new.execute! }
  end

  desc "Import EnrollmentSituations from Legacy SituacoesDeMatricula"
  task :enrollment_situations => :environment do
    verbose(:enrollment_situations) { ImportEnrollmentSituations.new.execute! }
  end

  desc "Import CourseSchool from Legacy Turmas"
  task :course_schools => :environment do
    verbose(:course_schools) { ImportCourseSchools.new.execute! }
  end

  desc "Import CourseSchedule from Legacy DiasDeAulas"
  task :course_schedules => :environment do
    verbose(:course_schedules) { ImportCourseSchedules.new.execute! }
  end

  desc "Import Curriculums from Legacy EstruturasCurriculares"
  task :curriculums => :environment do
    verbose(:curriculums) { ImportCurriculums.new.execute! }
  end

  desc "Import Student from Legacy Student"
  task :students => :environment do
    verbose(:students) { ImportStudents.new.execute! }
  end

  desc "Import Courses from Legacy Courses"
  task :courses => :environment do
    verbose(:courses) { ImportCourses.new.execute! }
  end

  desc "Import History to Enrollment"
  task :enrollments => :environment do
    verbose(:enrollments) { ImportEnrollments.new.execute! }
  end

  desc "Import PreRequirement from Legacy PreRequirement"
  task :pre_requirements => :environment do
    verbose(:pre_requirements) { ImportPreRequirement.new.execute! }
  end

  desc "Import all tables from Legacy"
  task :all => :environment do
    Rake::Task['import:clean_database'].invoke

    Rake::Task['import:rename_tables'].invoke
    Rake::Task['import:create_views'].invoke
    Rake::Task['import:create_history'].invoke

    Rake::Task['import:departments'].invoke
    Rake::Task['import:periods'].invoke
    Rake::Task['import:school_areas'].invoke
    Rake::Task['import:enrollment_situations'].invoke

    Rake::Task['import:disciplines'].invoke
    Rake::Task['import:schools'].invoke

    Rake::Task['import:curriculums'].invoke
    Rake::Task['import:course_schools'].invoke

    Rake::Task['import:students'].invoke
    Rake::Task['import:courses'].invoke

    Rake::Task['import:implementations'].invoke
    Rake::Task['import:enrollments'].invoke
    Rake::Task['import:course_schedules'].invoke

    Rake::Task['import:pre_requirements'].invoke
  end

  desc "Rename tables before execute import tasks"
  task :rename_tables => :environment do
    verbose(:rename_tables) do
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
  end

  desc "Create views to support import tasks"
  task :create_views => :environment do
    verbose(:create_views) do
      Academnew.connection.execute("drop view if exists curriculum")
      Academnew.connection.execute(<<-SQL)
        create view curriculum as
        select * from compl_estruturas_curriculares
          right join estruturas_curriculares using(CodigoDaEstrutura);
      SQL
      Academnew.connection.execute("drop table if exists todos_alunos")
      Academnew.connection.execute(<<-SQL)
        create table todos_alunos as
        select *, 1 as Ativo
          from alunos
      SQL
      Academnew.connection.execute(<<-SQL)
        insert into todos_alunos
        select *, 0 as Ativo
          from ex_alunos
      SQL
    end
  end

  desc "Cleanup Development database"
  task :clean_database => :environment do
    verbose(:clean_database) do
      rset = ActiveRecord::Base.connection.execute("show tables")
      tables = Array.new
      rset.each {|reg| tables << reg}
      tables.flatten!
      tables.reject!{|table| table =~ /user/ ||
                             table == 'helps' ||
                             table == 'schema_migrations'}
      tables.each do |table|
        ActiveRecord::Base.connection.execute "TRUNCATE #{table}"
      end
    end
  end

  desc "Create table to merge history tables"
  task :create_history => :environment do
    verbose(:create_history) do
      Academnew.connection.execute(<<-SQL)
        drop table if exists historico_importacao;
      SQL

      Academnew.connection.execute(<<-SQL)
        create table historico_importacao(
          NumeroDeMatricula varchar(9),
          CodigoDaDisciplina varchar(5),
          Conceito varchar(1),
          SemestreEAno varchar(5),
          CodigoDaTurma varchar(3),
          SituacaoDaMatricula varchar(2)
        );
      SQL

      Academnew.connection.execute(<<-SQL)
        insert into historico_importacao(
          NumeroDeMatricula
          , CodigoDaDisciplina
          , CodigoDaTurma
          , SituacaoDaMatricula
          , Conceito
          , SemestreEAno
        )
        select a.* , #{Time.now.year * 10 + ((Time.now.month - 1) / 6) + 1} from matriculas_no_semestre a ;
      SQL

      Academnew.connection.execute(<<-SQL)
        insert into historico_importacao(
          NumeroDeMatricula
          , CodigoDaDisciplina
          , SemestreEAno
          , Conceito
          , SituacaoDaMatricula
        )
        select a.*, 99 from historicos_escolares a ;
      SQL

      Academnew.connection.execute(<<-SQL)
        insert into historico_importacao(
          NumeroDeMatricula
          , CodigoDaDisciplina
          , SemestreEAno
          , Conceito
          , SituacaoDaMatricula
        )
        select a.*, 99 from historicos_escolares_de_ex_alunos a;
      SQL

      Academnew.connection.execute(<<-SQL)
        alter table historico_importacao
          add index idx_matricula(NumeroDeMatricula)
          , add index idx_disciplina(CodigoDaDisciplina)
          , add index idx_semestre(SemestreEAno);
      SQL
    end
  end

end
