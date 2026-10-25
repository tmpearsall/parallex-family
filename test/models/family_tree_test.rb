require "test_helper"

class FamilyTreeTest < ActiveSupport::TestCase
  test "an empty family lays out nothing" do
    l = FamilyTree.new.layout
    assert_empty l.nodes
  end

  test "children sit below their parents, partners side by side, and nothing overlaps" do
    ann, bob, cy, di, em, gus = [ [ "Ann", "1950-01-01" ], [ "Bob", "1948-02-02" ], [ "Cy", "1975-03-03" ], [ "Di", "1978-04-04" ], [ "Em", "1976-05-05" ], [ "Gus", "2005-06-06" ] ].map { |n, d| make_person(n, birth_date: d) }
    pair(ann, bob); [ cy, di ].each { |k| link(ann, k); link(bob, k) }; pair(cy, em); link(cy, gus); link(em, gus)
    l = FamilyTree.new.layout
    by = l.nodes.index_by { |n| n.person.first_name }
    assert_equal 6, l.nodes.size
    assert_operator by["Cy"].y, :>, by["Ann"].y
    assert_operator by["Gus"].y, :>, by["Cy"].y
    assert_equal by["Ann"].y, by["Bob"].y
    assert_equal by["Cy"].y, by["Em"].y
    assert_operator l.nodes.map(&:x).min, :>=, 0
    l.nodes.group_by(&:y).each_value do |row|
      row.sort_by(&:x).each_cons(2) { |a, b| assert_operator b.x - a.x, :>=, FamilyTree::CARD_W, "cards overlap" }
    end
  end

  test "root candidates are people with no parents who have a child or partner" do
    a, b = make_person("Ann"), make_person("Bob"); make_person("Loner"); pair(a, b)
    assert_equal %w[Ann Bob].sort, FamilyTree.new.root_candidates.map(&:first_name).sort
  end
end
