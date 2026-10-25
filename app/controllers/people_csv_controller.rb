# Organizers only: download the contact list, or add people from a CSV. Import is two steps (preview, then
# confirm) and only adds; the confirmed rows travel in a signed, expiring token so they cannot be altered.
class PeopleCsvController < TenantController
  before_action :organizer_only!

  def export
    send_data PeopleCsv.export(current_family), filename: "#{current_family.slug}-people-#{Date.current}.csv", type: "text/csv"
  end

  def new; end

  def preview
    file = params[:file]
    return redirect_to(import_people_path, alert: "Choose a CSV file first.") unless file.respond_to?(:read)
    data = file.read(PeopleCsv::MAX_BYTES + 1)
    @result = PeopleCsv.parse(current_family, data)
    return redirect_to(import_people_path, alert: @result.error) if @result.error
    @new_rows = @result.of(:new)
    @token = verifier.generate({ family_id: current_family.id, rows: @new_rows.map(&:attrs) }, expires_in: 30.minutes) if @new_rows.any?
  end

  def create
    payload = begin
      verifier.verified(params[:token].to_s)
    rescue StandardError
      nil
    end
    return redirect_to(import_people_path, alert: "That preview expired. Upload the file again.") unless payload && payload["family_id"] == current_family.id
    made = 0
    Person.transaction do
      Array(payload["rows"]).each do |attrs|
        current_family.people.create!(attrs.slice(*PeopleCsv::ATTRS.map(&:to_s)).merge(created_by_id: current_user.id, updated_by_id: current_user.id))
        made += 1
      end
    end
    redirect_to people_path, notice: "Added #{made} #{'person'.pluralize(made)}. No accounts were created and no email was sent."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to import_people_path, alert: "Nothing was added: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def verifier = Rails.application.message_verifier(:people_import)
end
