require 'spec_helper'

describe Student do

  context "find_by_registration" do
    before(:all) do
      @student = Student.first(:conditions => { :registration => "F0626805" }) || Student.make(:registration => "F0626805")
    end

    it 'should return with the number and initial letter' do
      Student.find_by_registration('F0626805').should == @student
    end

    it 'should return with only number' do
      Student.find_by_registration('0626805').should == @student
    end

  end

  context "registration_with_initial_letter" do
    it 'should return with A for registrations that begin with 701 until 992' do
      (70..99).each do |year|
        (1..2).each do |sem|
          number = "#{year}#{sem}".rjust(3,'0')
          Student.registration_with_initial_letter(number).should == "A#{number}"
        end
      end
    end

    it 'should return with F for registrations that begin with 001 until 072' do
      (0..7).each do |year|
        (1..2).each do |sem|
          number = "#{year}#{sem}".rjust(3,'0')
          Student.registration_with_initial_letter(number).should == "F#{number}"
        end
      end
    end

    it 'should return with H for registrations that begin with 081 until 692' do
      (8..69).each do |year|
        (1..2).each do |sem|
          number = "#{year}#{sem}".rjust(3,'0')
          Student.registration_with_initial_letter(number).should == "H#{number}"
        end
      end
    end
  end

  context 'registration_verification_digit' do
    it 'should 5 for 062680' do
      Student.registration_verification_digit('062680').should == 5
    end

    it 'should 8 for 071658' do
      Student.registration_verification_digit('071658').should == 8
    end

    it 'should 2 for 1010989' do
      Student.registration_verification_digit('1010989').should == 2
    end
  end

  context "valid mothers name initials" do
    before(:all) do
      @student = Student.make(:mothers_name => "Maria Da Silva Sauro Sant'Anna")
    end

    it 'should return true for MDSSSA' do
      @student.valid_mothers_name_initials?('MDSSSA').should be_true
    end

    it 'should return true for MSSSA' do
      @student.valid_mothers_name_initials?('MSSSA').should be_true
    end

    it 'should return true for MDSSS' do
      @student.valid_mothers_name_initials?('MDSSS').should be_true
    end

    it 'should return true for MSSS' do
      @student.valid_mothers_name_initials?('MSSS').should be_true
    end

  end

  context "mother_name_initials" do
    before(:all) do
      @student = Student.make(:mothers_name => "Maria Da Silva Sauro Sant'Anna")
    end

    it 'should return [MDSSSA, MDSSS, MSSS, MSSSA]' do
      @student.mothers_name_initials.should include('MDSSS', 'MDSSSA', 'MSSS', 'MSSSA')
    end
  end

  it "#reg should return registration without first letter" do
    Student.new(:registration => 'F0626805').reg.should == '0626805'
  end

  context "#discipline_concluded? chain" do
    before( :all ) do
      @student = Student.make
      @discipline_id = Discipline.make.id
      @enrolls = (1..2).to_a.map do
        @student.enrollments.make(
          :course_semester => CourseSemester.make(:course => Course.make(:discipline_id => @discipline_id)),
          :grade => 'C'
        )
      end
      3.times do
        @student.enrollments.make
      end
    end

    it "#enrollments_from_discipline should == only enrollments from param discipline" do
      @student.enrollments_from_discipline(@discipline_id).should == @enrolls
    end

    it "#discipline_grades should return an Array of grades(String) from discipline" do
      @student.discipline_grades(@discipline_id).should == ['C', 'C']
    end

    it "#discipline_concluded? should return true if enrollment grade include [A,B,D,E] and false otherwise" do
      @student.discipline_concluded?(@discipline_id).should be_false
    end
  end

  context "#semesters_into_fatec" do
    def student_in_semester(semester)
      reg = semester.to_s[2,3]+"999"
      reg = Student.registration_with_initial_letter("#{reg}#{Student.registration_verification_digit(reg)}")
      stu = Student.new(:registration => reg)
    end

    it "should be 1 for someone who entered now" do
      student_in_semester(Time.now.year_semester).semesters_into_fatec.should == 1
    end

    it "should be 3 for someone who entered a year ago" do
      student_in_semester(1.year.ago.year_semester).semesters_into_fatec.should == 3
    end

    it "should be 4 for someone who entered a year and half ago" do
      entered_in = 1.year.ago - 6.months
      student_in_semester(entered_in.year_semester).semesters_into_fatec.should == 4
    end
  end

  context "#n_minus_3 should filter disciplines with school_semester out of n_minus_3" do
    before(:all) do
      @stud = Student.make
      1.upto(6) { |t| @stud.curriculum.implementations.make :school_semester => t }
      @disc_inclusions = @stud.curriculum.disciplines.all(:conditions => ['implementations.school_semester in (?)', [1,2,3]])
    end

    subject { @stud.n_minus_3(@stud.curriculum.disciplines) }

    it "should not include disciplines with school_semester > 3" do
      disc_exclusions = @stud.curriculum.disciplines.all(:conditions => ['implementations.school_semester in (?)', [4,5,6]])
      disc_exclusions.each do |disc|
        should_not include(disc)
      end
    end

    it "should be exactly 3 disciplines from 1, 2 e 3 school_semester" do
      should == @disc_inclusions
    end
  end

  it "#disciplines_with_pre_requirements_concluded should filter disciplines with pre_requirements not concluded" do
    @student = Student.make
    @imp3 = @student.curriculum.implementations.make(:school_semester => 3)
    @imp2 = @student.curriculum.implementations.make(:school_semester => 2)
    @imp1 = @student.curriculum.implementations.make(:school_semester => 1)
    @imps_clear = (1..3).to_a.map { @student.curriculum.implementations.make(:school_semester => [1,2].shuffle.first) }

    @imp3.pre_requirements.make(:pre_requirement => @imp2)
    @imp3.pre_requirements.make(:pre_requirement => @imp1)
    @imp2.pre_requirements.make(:pre_requirement => @imp1)

    @student.disciplines_with_pre_requirements_concluded(@student.curriculum.disciplines).should_not include [@imp3, @imp2]
  end

end
