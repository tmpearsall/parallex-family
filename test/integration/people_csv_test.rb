require "test_helper"

class PeopleCsvTest < ActionDispatch::IntegrationTest
  PW = "Str0ng!Pass#1".freeze

  setup do
    @family = Family.create!(name: "Csv Test", slug: "csv-test")
    @org = mk("org@example.test", "organizer")
    @mem = mk("mem@example.test", "member")
    @family.people.create!(first_name: "Existing", last_name: "Person", email: "exist@example.test", phone: "+1 555 555 0100")
    sign_in(@org)
  end

  def mk(email, role)
    u = User.create!(email: email, password: PW, name: email.split("@").first)
    @family.memberships.create!(user: u, role: role)
  end

  def sign_in(m) = post(user_session_path, params: { user: { email: m.user.email, password: PW } })

  def upload(csv, name = "people.csv")
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: name)
    post "/f/csv-test/people/import/preview", params: { file: file }
  end

  test "export gives the ten columns, and a formula cell is neutralised but a +1 phone is not" do
    @family.people.create!(first_name: "=cmd", last_name: "Evil", street1: "1 Main", city: "Hanover", state: "NH", zip: "03755")
    get "/f/csv-test/people/export.csv"
    assert_response :success
    rows = CSV.parse(response.body, headers: true)
    assert_equal PeopleCsv::COLUMNS.map(&:last), rows.headers
    assert_equal "+1 555 555 0100", rows.find { |r| r["First name"] == "Existing" }["Phone"]
    assert rows.any? { |r| r["First name"] == "'=cmd" }
    assert_equal "03755", rows.find { |r| r["Last name"] == "Evil" }["Zip"]
  end

  test "members cannot export or import" do
    delete destroy_user_session_path
    sign_in(@mem)
    get "/f/csv-test/people/export.csv"
    assert_response :forbidden
    get "/f/csv-test/people/import"
    assert_response :forbidden
  end

  test "preview sorts new, duplicate and problem rows, and adds nothing" do
    csv = "first name,last name,phone number,email\nNew,One,555-0101,new1@example.test\nSame,Email,555-0102,EXIST@example.test\nBad,Phone,call me,bad@example.test\n,NoFirst,,\nExisting,Person,,\n"
    assert_no_difference "Person.count" do
      upload(csv)
    end
    assert_response :success
    assert_includes response.body, "<strong>1</strong> new"
    assert_includes response.body, "Already here (same email)"
    assert_includes response.body, "Already here (same name)"
    assert_includes response.body, "can only have digits"
  end

  test "confirming adds only the new people, makes no accounts and sends no mail" do
    ActionMailer::Base.deliveries.clear
    upload("First,Last,Email,Street,City,State,ZIP\nNora,Newcomer,nora@example.test,9 Elm,Austin,TX,02134\n")
    token = response.body[/name="token" [^>]*value="([^"]+)"/, 1] || response.body[/value="([^"]+)"[^>]*name="token"/, 1]
    assert token.present?
    assert_difference [ "Person.count" ], 1 do
      assert_no_difference [ "User.count", "Membership.count" ] do
        post "/f/csv-test/people/import", params: { token: token }
      end
    end
    nora = @family.people.find_by!(first_name: "Nora")
    assert_equal "02134", nora.zip
    assert_equal "9 Elm", nora.street1
    assert_equal @org.user_id, nora.created_by_id
    assert_empty ActionMailer::Base.deliveries
  end

  test "a tampered or other-family token adds nothing" do
    upload("First,Last\nTom,Pered\n")
    token = response.body[/name="token" [^>]*value="([^"]+)"/, 1] || response.body[/value="([^"]+)"[^>]*name="token"/, 1]
    assert_no_difference "Person.count" do
      post "/f/csv-test/people/import", params: { token: token + "x" }
      assert_redirected_to "/f/csv-test/people/import"
    end
    other = Family.create!(name: "Other", slug: "other")
    other.memberships.create!(user: @org.user, role: "organizer")
    assert_no_difference "Person.count" do
      post "/f/other/people/import", params: { token: token }
    end
  end

  test "a file with no first-name column, an empty file and too many rows are refused with a reason" do
    upload("Surname,Phone\nX,1\n")
    assert_redirected_to "/f/csv-test/people/import"
    assert_match(/first-name column/, flash[:alert])
    upload("")
    assert_redirected_to "/f/csv-test/people/import"
    big = "First\n" + (1..(PeopleCsv::MAX_ROWS + 1)).map { |i| "P#{i}" }.join("\n")
    upload(big)
    assert_match(/more than #{PeopleCsv::MAX_ROWS} rows/, flash[:alert])
  end

  test "names with accents and a Windows-encoded file are read" do
    upload("First,Last\nJosé,Muñoz\n")
    assert_includes response.body, "Jos"
    upload("First,Last\nJos\xE9,Mu\xF1oz\n".b)
    assert_response :success
    assert_includes response.body, "<strong>1</strong> new"
  end

  test "a duplicate inside the file is caught" do
    upload("First,Last,Email\nDup,One,d@example.test\nDup,Two,d@example.test\n")
    assert_includes response.body, "<strong>1</strong> new"
    assert_includes response.body, "same email"
  end
end
