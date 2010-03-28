require 'machinist/active_record'
require 'sham'
require 'faker'

Sham.name  { Faker::Name.name }
Sham.email { Faker::Internet.email }
Sham.registration {
}

User.blueprint do
  email
  password "123456"
  password_confirmation "123456"
end

Student.blueprint do
  registration {
    Student.registration_with_initial_letter(
      Student.registration_check_number(
      "#{rand(99)}#{(rand(10) % 2) + 1}".rjust(3, '0') + rand(999).to_s.rjust(4, '0')
      )
    )
  }
  name
  mothers_name name
end
