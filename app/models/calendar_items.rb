# Everything that can appear on one family's calendar, for one member, between two dates. The same list feeds the
# month view, the agenda and the subscription feed, so they can never disagree.
#
# Privacy: birthdays and anniversaries come from the tree, so they follow the tree's rules. A living person's
# birthday appears only if the viewer may see that person's details; a deceased person's never does; a couple's
# anniversary appears only if both partners' details are visible.
class CalendarItems
  Item = Struct.new(:kind, :title, :on, :until, :note, :place, :tentative, :record, :yearly, keyword_init: true) do
    def last_day = self.until || on
    def covers?(date) = on <= date && date <= last_day
  end

  def initialize(family:, membership:)
    @family = family
    @membership = membership
  end

  # Items whose days fall in from..to (inclusive).
  def between(from, to)
    items = []
    items.concat(events(from, to))
    items.concat(reunions(from, to))
    items.concat(date_options(from, to))
    items.concat(deadlines(from, to))
    if @family.terms.birthdays?
      items.concat(birthdays(from, to))
      items.concat(anniversaries(from, to))
    end
    items.sort_by { |i| [ i.on, KIND_ORDER[i.kind] || 9, i.title ] }
  end

  KIND_ORDER = { "reunion" => 0, "event" => 1, "proposed" => 2, "deadline" => 3, "birthday" => 4, "anniversary" => 5 }.freeze

  # Birthdays and anniversaries that repeat yearly, once each (for the subscription feed).
  def yearly_items
    return [] unless @family.terms.birthdays?
    birthday_people.map { |p| Item.new(kind: "birthday", title: "#{p.first_name}'s birthday", on: p.birth_date, yearly: true, record: p) } +
      anniversary_pairs.map { |r| Item.new(kind: "anniversary", title: "#{r.from_person.first_name} & #{r.to_person.first_name}'s anniversary", on: r.started_on, yearly: true, record: r) }
  end

  # Everything dated that is not a yearly repeat, with no range limit (for the feed).
  def dated_items
    between(Date.current - 1.year, Date.current + 3.years).reject { |i| i.kind == "birthday" || i.kind == "anniversary" }
  end

  private

  def events(from, to)
    @family.events.visible_to(@membership).overlapping(from, to).flat_map do |e|
      tags = [ ("organizers only" if e.meeting?), e.repeat_label, e.time_note, e.notes ].compact.join(" · ").presence
      e.occurrence_days(from, to).map do |day|
        Item.new(kind: "event", title: e.title, on: day, until: (day + e.duration_days if e.duration_days.positive?), note: tags, place: e.location, record: e)
      end
    end
  end

  def reunions(from, to)
    @family.reunions.where.not(starts_on: nil).where("starts_on <= ? and coalesce(ends_on, starts_on) >= ?", to, from).map do |r|
      Item.new(kind: "reunion", title: r.title, on: r.starts_on, until: r.ends_on, place: r.location_name, record: r)
    end
  end

  # Dates still being voted on show as tentative until the reunion has a date.
  def date_options(from, to)
    @family.reunions.where(starts_on: nil).includes(:date_options).flat_map do |r|
      r.date_options.select { |o| o.starts_on <= to && (o.ends_on || o.starts_on) >= from }.map do |o|
        Item.new(kind: "proposed", title: "#{r.title} (proposed)", on: o.starts_on, until: o.ends_on, note: o.note, tentative: true, record: r)
      end
    end
  end

  def deadlines(from, to)
    @family.reunions.where(rsvp_by: from..to).map do |r|
      Item.new(kind: "deadline", title: "RSVP by today: #{r.title}", on: r.rsvp_by, record: r)
    end
  end

  def birthday_people
    @family.people.where.not(birth_date: nil).where(death_date: nil).select { |p| p.details_visible_to?(@membership) }
  end

  def birthdays(from, to)
    birthday_people.flat_map do |p|
      occurrences(p.birth_date, from, to).map { |d| Item.new(kind: "birthday", title: "#{p.first_name}'s birthday", on: d, record: p) }
    end
  end

  def anniversary_pairs
    @family.relationships.partners.where.not(started_on: nil).includes(:from_person, :to_person).select do |r|
      [ r.from_person, r.to_person ].all? { |p| p.death_date.nil? && p.details_visible_to?(@membership) }
    end
  end

  def anniversaries(from, to)
    anniversary_pairs.flat_map do |r|
      occurrences(r.started_on, from, to).map { |d| Item.new(kind: "anniversary", title: "#{r.from_person.first_name} & #{r.to_person.first_name}'s anniversary", on: d, record: r) }
    end
  end

  # Each year's date for a month and day inside from..to. 29 February falls on 28 February in other years.
  def occurrences(date, from, to)
    (from.year..to.year).filter_map do |y|
      d = begin
        Date.new(y, date.month, date.day)
      rescue Date::Error
        Date.new(y, 2, 28)
      end
      d if d >= from && d <= to && d >= date
    end
  end
end
