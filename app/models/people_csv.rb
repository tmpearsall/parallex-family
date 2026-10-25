require "csv"

# Reading and writing the family's contact list as a CSV. Export is the full list; import only ever ADDS people
# (a row that matches someone already here is skipped, never overwriting what is on file) and never makes accounts.
module PeopleCsv
  COLUMNS = [
    [ :first_name, "First name" ], [ :last_name, "Last name" ], [ :phone, "Phone" ], [ :email, "Email" ],
    [ :phone2, "Phone 2" ], [ :street1, "Street 1" ], [ :street2, "Street 2" ], [ :city, "City" ], [ :state, "State" ], [ :zip, "Zip" ]
  ].freeze
  ATTRS = COLUMNS.map(&:first).freeze
  MAX_BYTES = 1_000_000
  MAX_ROWS = 500

  ALIASES = {
    "firstname" => :first_name, "first" => :first_name, "givenname" => :first_name,
    "lastname" => :last_name, "last" => :last_name, "surname" => :last_name, "familyname" => :last_name,
    "phone" => :phone, "phonenumber" => :phone, "phone1" => :phone, "mobile" => :phone, "cell" => :phone,
    "email" => :email, "emailaddress" => :email,
    "phone2" => :phone2, "secondphone" => :phone2, "phonenumber2" => :phone2, "alternatephone" => :phone2,
    "street1" => :street1, "street" => :street1, "address" => :street1, "address1" => :street1, "streetaddress" => :street1,
    "street2" => :street2, "address2" => :street2,
    "city" => :city, "town" => :city,
    "state" => :state, "province" => :state, "region" => :state,
    "zip" => :zip, "zipcode" => :zip, "postalcode" => :zip, "postcode" => :zip
  }.freeze

  Row = Struct.new(:line, :attrs, :status, :note, keyword_init: true)
  Result = Struct.new(:rows, :error, keyword_init: true) do
    def of(status) = rows.select { |r| r.status == status }
  end

  # A cell that a spreadsheet could run as a formula gets a leading apostrophe on export. Plain phone numbers
  # (which may start with +) are left alone.
  def self.safe_cell(value)
    v = value.to_s
    return v unless v.start_with?("=", "+", "-", "@", "\t", "\r")
    v.match?(/\A\+?[0-9().\-\sx]+\z/) ? v : "'#{v}"
  end

  def self.export(family)
    CSV.generate do |csv|
      csv << COLUMNS.map(&:last)
      family.people.by_name.each { |p| csv << ATTRS.map { |a| safe_cell(p.public_send(a)) } }
    end
  end

  def self.parse(family, data)
    return Result.new(rows: [], error: "That file is empty.") if data.to_s.strip.empty?
    return Result.new(rows: [], error: "That file is too large (over #{MAX_BYTES / 1000} KB).") if data.bytesize > MAX_BYTES
    text = data.dup.force_encoding("UTF-8")
    text = data.dup.force_encoding("Windows-1252").encode("UTF-8", invalid: :replace, undef: :replace) unless text.valid_encoding?
    text = text.delete_prefix("﻿")
    table = CSV.parse(text, headers: true)
    map = table.headers.each_with_object({}) { |h, m| a = ALIASES[h.to_s.downcase.gsub(/[^a-z0-9]/, "")]; m[h] = a if a }
    return Result.new(rows: [], error: "I could not find a first-name column. The first row must be column names such as: #{COLUMNS.map(&:last).join(', ')}.") unless map.value?(:first_name)
    return Result.new(rows: [], error: "That has more than #{MAX_ROWS} rows. Split it and import in parts.") if table.size > MAX_ROWS

    existing_emails = family.people.where.not(email: nil).pluck(:email).map(&:downcase).to_set
    existing_names = family.people.pluck(:first_name, :last_name).map { |f, l| name_key(f, l) }.to_set
    seen_emails = Set.new
    seen_names = Set.new
    rows = table.each_with_index.filter_map do |r, i|
      attrs = map.each_with_object({}) { |(h, a), m| m[a] = clean(r[h]) }
      next if attrs.values.all?(&:blank?)
      line = i + 2
      person = family.people.new(attrs)
      email = attrs[:email].to_s.downcase
      key = name_key(attrs[:first_name], attrs[:last_name])
      if !person.valid?
        Row.new(line: line, attrs: attrs, status: :problem, note: person.errors.full_messages.to_sentence)
      elsif email.present? && (existing_emails.include?(email) || seen_emails.include?(email))
        Row.new(line: line, attrs: attrs, status: :duplicate, note: "Already here (same email).")
      elsif existing_names.include?(key) || seen_names.include?(key)
        Row.new(line: line, attrs: attrs, status: :duplicate, note: "Already here (same name). If this is a different person, add them by hand.")
      else
        seen_emails << email if email.present?
        seen_names << key
        Row.new(line: line, attrs: attrs, status: :new)
      end
    end
    Result.new(rows: rows)
  rescue CSV::MalformedCSVError => e
    Result.new(rows: [], error: "I could not read that file as a CSV (#{e.message.to_s.truncate(100)}).")
  end

  def self.name_key(first, last) = [ first.to_s.downcase.squish, last.to_s.downcase.squish ]

  # Undo the export's formula guard, strip stray spaces.
  def self.clean(value)
    v = value.to_s.strip
    v = v.delete_prefix("'") if v.match?(/\A'[=+\-@]/)
    v.presence
  end
end
