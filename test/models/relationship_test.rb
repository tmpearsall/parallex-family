require "test_helper"

class RelationshipTest < ActiveSupport::TestCase
  test "a person cannot be related to themselves" do
    a = make_person("Ann")
    assert_not Relationship.new(from_person: a, to_person: a, kind: "parent").valid?
  end

  test "duplicate parent links are rejected" do
    a, c = make_person("Ann"), make_person("Cy")
    link(a, c)
    assert_not Relationship.new(from_person: a, to_person: c, kind: "parent").valid?
  end

  test "a partnership is the same fact in either direction" do
    a, b = make_person("Ann"), make_person("Bob")
    pair(a, b)
    assert_not Relationship.new(from_person: b, to_person: a, kind: "partner").valid?
  end

  test "nobody can become their own ancestor" do
    a, b, c = make_person("Ann"), make_person("Bob"), make_person("Cy")
    link(a, b); link(b, c)
    r = Relationship.new(from_person: c, to_person: a, kind: "parent")
    assert_not r.valid?
    assert_match(/own ancestor/, r.errors.full_messages.to_sentence)
  end

  test "siblings, partners and children are derived" do
    a, b, c, d, e = %w[Ann Bob Cy Di Em].map { |n| make_person(n) }
    link(a, c); link(a, d); pair(c, e)
    assert_equal [ d ], c.siblings.to_a
    assert_equal [ e ], c.partners.to_a
    assert_equal [ c, d ].sort_by(&:id), a.children.sort_by(&:id)
    assert_equal [ a ], c.parents.to_a
  end
end
