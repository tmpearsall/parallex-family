# A subscription calendar (iCalendar, RFC 5545) built from the same items as the calendar page.
class IcsFeed
  def initialize(family:, membership:)
    @family = family
    @items = CalendarItems.new(family: family, membership: membership)
  end

  def to_s
    lines = [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Parallex Family//Reunion calendar//EN", "CALSCALE:GREGORIAN",
              "X-WR-CALNAME:#{escape("#{@family.name} calendar")}", "REFRESH-INTERVAL;VALUE=DURATION:PT12H", "X-PUBLISHED-TTL:PT12H" ]
    (@items.dated_items + @items.yearly_items).each { |i| lines.concat(vevent(i)) }
    lines << "END:VCALENDAR"
    lines.flat_map { |l| fold(l) }.join("\r\n") + "\r\n"
  end

  private

  def vevent(i)
    uid = "#{i.kind}-#{i.record.class.name.downcase}-#{i.record.id}-#{i.on.iso8601}#{'-yearly' if i.yearly}@parallex-family"
    out = [ "BEGIN:VEVENT", "UID:#{uid}", "DTSTAMP:#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}",
            "DTSTART;VALUE=DATE:#{i.on.strftime('%Y%m%d')}", "DTEND;VALUE=DATE:#{(i.last_day + 1).strftime('%Y%m%d')}",
            "SUMMARY:#{escape(i.title)}" ]
    out << "DESCRIPTION:#{escape(i.note)}" if i.note.present?
    out << "LOCATION:#{escape(i.place)}" if i.place.present?
    out << "STATUS:TENTATIVE" if i.tentative
    out << "RRULE:FREQ=YEARLY" if i.yearly
    out << "TRANSP:TRANSPARENT" if i.kind == "birthday" || i.kind == "anniversary"
    out << "END:VEVENT"
  end

  def escape(text) = text.to_s.gsub("\\", "\\\\\\\\").gsub(";", "\;").gsub(",", "\\,").gsub(/\r?\n/, "\\n")

  # Lines are folded at 75 octets, continuation lines start with a space.
  def fold(line)
    return [ line ] if line.bytesize <= 75
    parts = []
    chunk = +""
    line.each_char do |c|
      limit = parts.empty? ? 75 : 74
      if (chunk + c).bytesize > limit
        parts << chunk
        chunk = +""
      end
      chunk << c
    end
    parts << chunk
    parts.each_with_index.map { |p, idx| idx.zero? ? p : " #{p}" }
  end
end
