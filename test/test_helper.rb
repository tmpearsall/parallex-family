ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  def make_user(email: "u#{SecureRandom.hex(3)}@example.test", name: "Member", admin: false, person: nil)
    User.create!(email: email, name: name, admin: admin, person: person, password: "Abcdef1!x")
  end

  def make_person(first, last = "Rowe", **attrs) = Person.create!(first_name: first, last_name: last, **attrs)
  def link(parent, child) = Relationship.create!(from_person: parent, to_person: child, kind: "parent")
  def pair(a, b) = Relationship.create!(from_person: a, to_person: b, kind: "partner")
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
