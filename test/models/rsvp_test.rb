require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  setup do
    @reunion = Reunion.create!(title: "Reunion")
    @h = Household.create!(name: "The Rowes")
  end

  test "attending needs at least one person" do
    r = @reunion.rsvps.new(household: @h, status: "attending", adults: 0, children: 0)
    assert_not r.valid?
    r.adults = 2
    assert r.valid?
  end

  test "one answer per household" do
    @reunion.rsvps.create!(household: @h, status: "maybe")
    assert_not @reunion.rsvps.new(household: @h, status: "maybe").valid?
  end

  test "headcount only counts those coming" do
    h2 = Household.create!(name: "The Lees")
    @reunion.rsvps.create!(household: @h, status: "attending", adults: 2, children: 3)
    @reunion.rsvps.create!(household: h2, status: "maybe", adults: 4)
    hc = @reunion.headcount
    assert_equal({ households: 1, adults: 2, children: 3, maybe_households: 1, declined: 0 }, hc)
  end

  test "departure cannot be before arrival" do
    r = @reunion.rsvps.new(household: @h, status: "maybe", arrival_on: "2027-07-05", departure_on: "2027-07-01")
    assert_not r.valid?
  end
end
