class PeopleController < TenantController
  before_action :load_person, only: %i[show edit update destroy claim]

  def index
    @people = current_family.people.includes(:household).by_name
    @people = @people.where("lower(first_name || ' ' || coalesce(last_name,'')) like ?", "%#{params[:q].to_s.downcase.strip}%") if params[:q].present?
  end

  def show
    @visible = @person.details_visible_to?(current_membership)
    @others = current_family.people.where.not(id: @person.id).by_name
  end

  def new
    @person = current_family.people.new(household_id: params[:household_id])
    @relate_to = current_family.people.find_by(id: params[:relate_to])
    @as = params[:as] if terms.tree? && %w[parent child partner].include?(params[:as])
    @person.last_name = @relate_to.last_name if @relate_to && @as == "child"
    @person.household_id ||= @relate_to&.household_id if @as == "partner" || @as == "child"
  end

  def create
    @person = current_family.people.new(person_params.merge(created_by_id: current_user.id, updated_by_id: current_user.id))
    @relate_to = current_family.people.find_by(id: params[:relate_to])
    @as = params[:as] if terms.tree? && %w[parent child partner].include?(params[:as])
    Person.transaction do
      @person.save!
      if @relate_to && @as
        rel = case @as
        when "parent"  then current_family.relationships.new(from_person: @person, to_person: @relate_to, kind: "parent")
        when "child"   then current_family.relationships.new(from_person: @relate_to, to_person: @person, kind: "parent")
        else current_family.relationships.new(from_person: @relate_to, to_person: @person, kind: "partner")
        end
        rel.save!
      end
    end
    redirect_to(@relate_to || @person, notice: "#{@person.display_name} added.")
  rescue ActiveRecord::RecordInvalid => e
    @person.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @person
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    attrs = person_params.merge(updated_by_id: current_user.id)
    attrs[:hide_details] = true if @person.hide_details? && !organizer?   # only an organizer lifts a child's privacy
    if @person.update(attrs)
      redirect_to @person, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @person.removable_by?(current_membership)
      return redirect_to(@person, alert: "Only an organizer can remove this person now. You can remove someone you added yourself for 48 hours, if no one has linked an account to them.")
    end
    @person.destroy
    redirect_to people_path, notice: "#{@person.display_name} removed."
  end

  # "This is me": a member links their own account to their place in the tree. Only if they have none yet and
  # nobody else has claimed this person.
  def claim
    if current_membership.person_id.nil? && !@person.memberships.exists?
      current_membership.update!(person: @person)
      redirect_to @person, notice: "Linked: you are #{@person.display_name} in the tree."
    else
      redirect_to @person, alert: "This can't be linked to you. Ask an organizer."
    end
  end

  private

  def load_person = @person = current_family.people.find(params[:id])

  def person_params
    p = params.require(:person).permit(:first_name, :last_name, :maiden_name, :nickname, :birth_date, :death_date, :birth_place, :occupation, :notes, :email, :phone, :phone2, :street1, :street2, :city, :state, :zip, :household_id, :hide_details)
    p[:hide_details] = false unless organizer? || params.dig(:person, :hide_details) == "1"
    p
  end
end
