# Lays out a descendants chart as plain geometry (no JavaScript): a "unit" is a person and their partners shown
# side by side, with the children of any of them hanging below. Siblings, cousins and the rest fall out of the
# shape. Everyone is loaded into memory; a family is small.
class FamilyTree
  CARD_W = 156
  CARD_H = 56
  PARTNER_GAP = 8
  SIBLING_GAP = 18
  LEVEL_GAP = 64

  Node = Struct.new(:person, :x, :y)
  Layout = Struct.new(:nodes, :lines, :width, :height, :root_ids, keyword_init: true)

  def initialize(family)
    @people = family.people.index_by(&:id)
    rels = family.relationships.to_a
    @parents_of  = Hash.new { |h, k| h[k] = [] }
    @children_of = Hash.new { |h, k| h[k] = [] }
    @partners_of = Hash.new { |h, k| h[k] = [] }
    rels.each do |r|
      if r.kind == "parent"
        @children_of[r.from_person_id] << r.to_person_id
        @parents_of[r.to_person_id]    << r.from_person_id
      else
        @partners_of[r.from_person_id] << r.to_person_id
        @partners_of[r.to_person_id]   << r.from_person_id
      end
    end
    # Two people who share a child are shown together even if no partnership is recorded.
    @children_of.each_value do |kids|
      next if kids.empty?
    end
    @parents_of.each_value do |ps|
      ps.combination(2) { |a, b| (@partners_of[a] << b; @partners_of[b] << a) unless @partners_of[a].include?(b) }
    end
  end

  def people_count = @people.size

  # People who start a branch: no recorded parents, and a child or a partner somewhere. Oldest first.
  def root_candidates
    @people.values.select { |p| @parents_of[p.id].empty? && (@children_of[p.id].any? || @partners_of[p.id].any?) }
           .reject { |p| @partners_of[p.id].any? { |q| @parents_of[q].any? } }   # a partner who married in is not a branch head
           .sort_by { |p| [ p.birth_date || Date.new(9999), p.first_name.to_s ] }
  end

  def layout(root_id = nil)
    root_id = root_id.presence&.to_i
    root_id = root_candidates.first&.id if root_id.nil? || !@people.key?(root_id)
    return Layout.new(nodes: [], lines: [], width: 0, height: 0, root_ids: root_candidates.map(&:id)) if root_id.nil?

    @seen = Set.new
    tree = build(root_id)
    nodes = []; lines = []
    place(tree, 0, 0, nodes, lines)
    width  = [ nodes.map { |n| n.x + CARD_W }.max.to_i, 1 ].max
    height = nodes.map { |n| n.y + CARD_H }.max.to_i
    Layout.new(nodes: nodes, lines: lines, width: width, height: height, root_ids: root_candidates.map(&:id))
  end

  private

  Unit = Struct.new(:members, :kids, :width, keyword_init: true)

  def build(person_id)
    return nil if @seen.include?(person_id)
    members = [ person_id ]
    @seen << person_id
    @partners_of[person_id].uniq.sort_by { |q| [ @people[q].birth_date || Date.new(9999), q ] }.each do |q|
      next if @seen.include?(q)
      members << q; @seen << q
    end
    kid_ids = members.flat_map { |m| @children_of[m] }.uniq
                     .sort_by { |c| [ @people[c].birth_date || Date.new(9999), @people[c].first_name.to_s ] }
    kids = kid_ids.filter_map { |c| build(c) }
    own = members.size * CARD_W + (members.size - 1) * PARTNER_GAP
    span = kids.sum(&:width) + [ kids.size - 1, 0 ].max * SIBLING_GAP
    Unit.new(members: members, kids: kids, width: [ own, span ].max)
  end

  # Returns the x center of the unit's row.
  def place(unit, left, depth, nodes, lines)
    y = depth * (CARD_H + LEVEL_GAP)
    own = unit.members.size * CARD_W + (unit.members.size - 1) * PARTNER_GAP
    kid_centers = []
    span = unit.kids.sum(&:width) + [ unit.kids.size - 1, 0 ].max * SIBLING_GAP
    cursor = left + (unit.width - span) / 2.0
    unit.kids.each do |k|
      kid_centers << place(k, cursor, depth + 1, nodes, lines)
      cursor += k.width + SIBLING_GAP
    end
    center = kid_centers.any? ? (kid_centers.first + kid_centers.last) / 2.0 : left + unit.width / 2.0
    x = center - own / 2.0
    unit.members.each_with_index do |pid, i|
      nodes << Node.new(@people[pid], (x + i * (CARD_W + PARTNER_GAP)).round, y)
    end
    (unit.members.size - 1).times do |i|   # partner joiner
      lx = (x + i * (CARD_W + PARTNER_GAP) + CARD_W).round
      lines << [ lx, y + CARD_H / 2, lx + PARTNER_GAP, y + CARD_H / 2 ]
    end
    if kid_centers.any?
      bus = y + CARD_H + LEVEL_GAP / 2
      lines << [ center.round, y + CARD_H, center.round, bus ]
      lines << [ kid_centers.first.round, bus, kid_centers.last.round, bus ] if kid_centers.size > 1
      kid_centers.each { |kc| lines << [ kc.round, bus, kc.round, y + CARD_H + LEVEL_GAP ] }
    end
    center
  end
end
