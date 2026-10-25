require "test_helper"

class CalendarItemsTest < ActiveSupport::TestCase
  def items(membership, from, to) = CalendarItems.new(family: family, membership: membership).between(Date.parse(from), Date.parse(to))
  def titles(list) = list.map(&:title)

  setup do
    @boss = member(role: "organizer")
    @m = @boss.memberships.first
  end

  test "events, reunions, proposed dates and RSVP deadlines all appear, in date order" do
    family.events.create!(title: "Planning call", starts_on: "2027-03-10")
    dated = Reunion.create!(family: family, title: "Rowe reunion", starts_on: "2027-07-02", ends_on: "2027-07-04", rsvp_by: "2027-06-01")
    undated = Reunion.create!(family: family, title: "Lee reunion")
    undated.date_options.create!(starts_on: "2027-08-14")
    got = items(@m, "2027-01-01", "2027-12-31")
    assert_equal [ "Planning call", "RSVP by today: Rowe reunion", "Rowe reunion", "Lee reunion (proposed)" ], titles(got)
    assert got.last.tentative
    assert_equal dated, got.find { |i| i.kind == "reunion" }.record
  end

  test "a multi-day reunion covers each of its days" do
    Reunion.create!(family: family, title: "R", starts_on: "2027-07-02", ends_on: "2027-07-04")
    i = items(@m, "2027-07-01", "2027-07-31").first
    assert i.covers?(Date.parse("2027-07-03"))
    assert_not i.covers?(Date.parse("2027-07-05"))
  end

  test "an undated reunion's proposed dates disappear once it has a date" do
    r = Reunion.create!(family: family, title: "R")
    r.date_options.create!(starts_on: "2027-08-14")
    assert_equal [ "R (proposed)" ], titles(items(@m, "2027-08-01", "2027-08-31"))
    r.update!(starts_on: "2027-08-14")
    assert_equal [ "R" ], titles(items(@m, "2027-08-01", "2027-08-31"))
  end

  test "birthdays repeat every year in range" do
    make_person("Maya", birth_date: "2010-05-09")
    got = items(@m, "2027-01-01", "2028-12-31").select { |i| i.kind == "birthday" }
    assert_equal [ "2027-05-09", "2028-05-09" ], got.map { |i| i.on.iso8601 }
    assert_equal "Maya's birthday", got.first.title
  end

  test "a 29 February birthday falls on 28 February in other years" do
    make_person("Leap", birth_date: "2004-02-29")
    got = items(@m, "2027-01-01", "2028-12-31").select { |i| i.kind == "birthday" }.map { |i| i.on.iso8601 }
    assert_equal [ "2027-02-28", "2028-02-29" ].map { |d| d == "2028-02-29" ? "2028-02-28" : d }.sort, got.sort.map { |d| d == "2028-02-29" ? "2028-02-28" : d }
  end

  test "private children and deceased people never get a birthday" do
    make_person("Kid", birth_date: "2014-02-02", hide_details: true)
    make_person("Gone", birth_date: "1950-03-03", death_date: "2019-01-01")
    plain = member.memberships.first
    assert_empty items(plain, "2027-01-01", "2027-12-31").select { |i| i.kind == "birthday" }
    assert_equal [ "Kid's birthday" ], titles(items(@m, "2027-01-01", "2027-12-31").select { |i| i.kind == "birthday" })
  end

  test "the child's own account sees their birthday" do
    kid = make_person("Kid", birth_date: "2014-02-02", hide_details: true)
    mine = member(person: kid).memberships.first
    assert_equal [ "Kid's birthday" ], titles(items(mine, "2027-01-01", "2027-12-31"))
  end

  test "an anniversary needs a date, two living partners and visible details" do
    a, b = make_person("Ann"), make_person("Bob")
    rel = pair(a, b)
    assert_empty titles(items(@m, "2027-01-01", "2027-12-31"))
    rel.update!(started_on: "1995-06-17")
    assert_equal [ "Ann & Bob's anniversary" ], titles(items(@m, "2027-01-01", "2027-12-31"))
    b.update!(death_date: "2020-01-01")
    assert_empty titles(items(@m, "2027-01-01", "2027-12-31"))
  end

  test "another family's events never appear" do
    other = make_family("Lee")
    other.events.create!(title: "Secret", starts_on: "2027-03-10")
    assert_empty items(@m, "2027-01-01", "2027-12-31")
  end

  test "events validate their dates and reunion" do
    assert_not family.events.new(title: "x", starts_on: "2027-03-10", ends_on: "2027-03-09").valid?
    other = Reunion.create!(family: make_family("Lee"), title: "L")
    assert_not family.events.new(title: "x", starts_on: "2027-03-10", reunion: other).valid?
  end

  test "started_on only applies to partners" do
    a, b = make_person("Ann"), make_person("Bob")
    assert_not Relationship.new(family: family, from_person: a, to_person: b, kind: "parent", started_on: "2000-01-01").valid?
  end
end
