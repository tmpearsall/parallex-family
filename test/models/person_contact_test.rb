require "test_helper"

class PersonContactTest < ActiveSupport::TestCase
  setup { @family = Family.create!(name: "Contact Test") }

  test "a mailing address and two phones are saved and tidied" do
    p = @family.people.create!(first_name: "Hawthorne", street1: "  Box 123 ", street2: "Smith Hall", city: "Hanover", state: "NH", zip: "03755", phone: "(555) 555-0101", phone2: "555 555 0102")
    assert_equal "Box 123, Smith Hall, Hanover, NH 03755", p.mailing_address
    assert p.mailing_address?
    assert_equal "555 555 0102", p.phone2
  end

  test "a zip keeps its leading zero" do
    assert_equal "02134", @family.people.create!(first_name: "Zee", zip: "02134").reload.zip
  end

  test "blank address parts are skipped" do
    p = @family.people.create!(first_name: "Pat", city: "Austin", state: "TX")
    assert_equal "Austin, TX", p.mailing_address
    assert_not @family.people.create!(first_name: "Quinn").mailing_address?
  end

  test "bad characters in zip or second phone are rejected" do
    assert_not @family.people.new(first_name: "A", zip: "<script>").valid?
    assert_not @family.people.new(first_name: "A", phone2: "call me").valid?
  end
end
