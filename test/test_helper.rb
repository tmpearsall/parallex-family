ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  def make_family(name = "Rowe", slug: nil) = Family.create!(name: name, slug: slug || name.parameterize)
  def family = (@family ||= make_family)

  def make_user(email: "u#{SecureRandom.hex(3)}@example.test", name: "Member", platform_admin: false)
    User.create!(email: email, name: name, platform_admin: platform_admin, password: "Abcdef1!x")
  end

  # A user who belongs to a family (default: the test's family).
  def member(role: "member", fam: family, person: nil, **user_attrs)
    u = make_user(**user_attrs)
    Membership.create!(family: fam, user: u, role: role, person: person)
    u
  end

  def make_person(first, last = "Rowe", fam: family, **attrs) = Person.create!(family: fam, first_name: first, last_name: last, **attrs)
  def link(parent, child) = Relationship.create!(family: parent.family, from_person: parent, to_person: child, kind: "parent")
  def pair(a, b) = Relationship.create!(family: a.family, from_person: a, to_person: b, kind: "partner")
end

module Overrides
  # Temporarily replace a class method (minitest-mock is not part of Minitest 6).
  def override(klass, name, impl)
    original = klass.method(name)
    klass.define_singleton_method(name, &impl)
    yield
  ensure
    klass.define_singleton_method(name, original)
  end
end

class ActiveSupport::TestCase
  include Overrides
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
