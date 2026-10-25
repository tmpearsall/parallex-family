# The words on the screen. A workspace is either a "family" (reunions, households, the family tree, birthdays) or a
# "group" (a board, a company, a church, an HOA, a committee planning meetings, picnics and other events). The
# data underneath is the same; only the wording, and whether the family-only features are offered, differ.
class Terms
  DATA = {
    "family" => {
      group: "family", Group: "Family", a_group: "a family",
      event: "reunion", events: "reunions", Event: "Reunion", Events: "Reunions", an_event: "a reunion",
      entry: "event", an_entry: "an event",
      party: "household", parties: "households", Party: "Household", Parties: "Households",
      party_hint: "A household is who is invited and answers together: a family at one address.",
      party_example: "The Rowes",
      invitees: "relatives", the_people: "the family",
      event_example: "Rowe family reunion 2027",
      group_example: "The Rowe Family",
      intro: "a private place for the family to plan a reunion together: the family tree, voting on dates, RSVPs, a list of what we need, a calendar and a message board",
      kids_note: "Keep date of birth, notes, email and phone private (for a child). Only an organizer and this person can see them.",
      person_link_label: "Who in the tree is this?", person_col: "In the tree as", no_tree_link: "not linked to the tree yet",
      listed_no_account: "In the tree, no account yet", everyone_listed: "Everyone in the tree has an account.",
      tree: true
    },
    "group" => {
      group: "group", Group: "Group", a_group: "a group",
      event: "event", events: "events", Event: "Event", Events: "Events", an_event: "an event",
      entry: "calendar entry", an_entry: "a calendar entry",
      party: "team", parties: "teams", Party: "Team", Parties: "Teams",
      party_hint: "A team is who answers together: a department, a committee, a table, a family.",
      party_example: "Facilities",
      invitees: "people", the_people: "the group",
      event_example: "Annual company picnic 2027",
      group_example: "Maple Street HOA",
      intro: "a private place for the group to plan events together: voting on dates, RSVPs, a list of who is bringing or doing what, a calendar and a message board",
      kids_note: "Keep date of birth, notes, email and phone private. Only an organizer and this person can see them.",
      person_link_label: "Who is this in the people list?", person_col: "Listed as", no_tree_link: "not linked to a person yet",
      listed_no_account: "On the people list, no account yet", everyone_listed: "Everyone on the people list has an account.",
      tree: false
    }
  }.freeze

  def self.for(kind) = new(kind)
  def self.default = new("family")

  def initialize(kind)
    @d = DATA.fetch(kind.to_s, DATA["family"])
  end

  DATA["family"].each_key do |key|
    define_method(key) { @d[key] }
  end

  def tree? = @d[:tree]
  def birthdays? = @d[:tree]   # birthdays and anniversaries come from the family tree's dates
  def kind = DATA.key(@d)
end
