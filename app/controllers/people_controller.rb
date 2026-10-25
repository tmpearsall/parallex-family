class PeopleController < ApplicationController
  before_action :load_person, only: %i[show edit update destroy]
  before_action :admin_only!, only: :destroy

  def index
    @people = Person.includes(:household).by_name
    @people = @people.where("lower(first_name || ' ' || coalesce(last_name,'')) like ?", "%#{params[:q].to_s.downcase.strip}%") if params[:q].present?
  end

  def show
    @visible = @person.details_visible_to?(current_user)
    @others = Person.where.not(id: @person.id).by_name
  end

  def new
    @person = Person.new(household_id: params[:household_id])
    @relate_to = Person.find_by(id: params[:relate_to])
    @as = params[:as] if %w[parent child partner].include?(params[:as])
    @person.last_name = @relate_to.last_name if @relate_to && @as == "child"
    @person.household_id ||= @relate_to&.household_id if @as == "partner" || @as == "child"
  end

  def create
    @person = Person.new(person_params.merge(created_by_id: current_user.id, updated_by_id: current_user.id))
    @relate_to = Person.find_by(id: params[:relate_to])
    @as = params[:as] if %w[parent child partner].include?(params[:as])
    Person.transaction do
      @person.save!
      if @relate_to && @as
        rel = case @as
        when "parent"  then Relationship.new(from_person: @person, to_person: @relate_to, kind: "parent")
        when "child"   then Relationship.new(from_person: @relate_to, to_person: @person, kind: "parent")
        else Relationship.new(from_person: @relate_to, to_person: @person, kind: "partner")
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
    attrs[:hide_details] = true if @person.hide_details? && !current_user.admin?   # only an administrator lifts a child's privacy
    if @person.update(attrs)
      redirect_to @person, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @person.destroy
    redirect_to people_path, notice: "#{@person.display_name} removed."
  end

  private

  def load_person = @person = Person.find(params[:id])

  def person_params
    p = params.require(:person).permit(:first_name, :last_name, :maiden_name, :nickname, :birth_date, :death_date, :birth_place, :occupation, :notes, :email, :household_id, :hide_details)
    p[:hide_details] = false unless current_user.admin? || params.dig(:person, :hide_details) == "1"
    p
  end
end
