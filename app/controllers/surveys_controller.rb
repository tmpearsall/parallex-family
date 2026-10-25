# Organizers create a survey (a few questions), look at the results, and close it. Sending is SurveySendsController.
class SurveysController < TenantController
  before_action :organizer_only!
  before_action :load_survey, only: %i[show edit update destroy close reopen]

  def index
    @surveys = current_family.surveys.includes(:created_by).order(created_at: :desc)
  end

  def new
    @survey = current_family.surveys.new
    @slots = blank_slots(0)
  end

  def create
    @survey = current_family.surveys.new(survey_params.merge(created_by: current_user))
    questions = parsed_questions
    if save_with(questions)
      redirect_to survey_path(@survey), notice: "Saved. Preview the audience and send it when you are ready."
    else
      @slots = slots_from(questions)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @summary = SurveyResults.new(@survey)
  end

  def edit
    @slots = slots_from(@survey.questions.map { |q| { kind: q.kind, prompt: q.prompt, options: q.options } })
  end

  def update
    @survey.assign_attributes(survey_params)
    if @survey.draft?
      questions = parsed_questions
      if save_with(questions)
        redirect_to survey_path(@survey), notice: "Saved."
      else
        @slots = slots_from(questions)
        render :edit, status: :unprocessable_entity
      end
    elsif @survey.save
      redirect_to survey_path(@survey), notice: "Saved. The questions cannot change once a survey has been sent."
    else
      @slots = slots_from(@survey.questions.map { |q| { kind: q.kind, prompt: q.prompt, options: q.options } })
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @survey.destroy
    redirect_to surveys_path, notice: "Survey deleted."
  end

  def close
    @survey.update!(status: "closed")
    redirect_to survey_path(@survey), notice: "Closed. Personal links no longer accept answers."
  end

  def reopen
    @survey.update!(status: "open", closes_on: (@survey.closes_on if @survey.closes_on && @survey.closes_on >= Date.current))
    redirect_to survey_path(@survey), notice: "Open again."
  end

  private

  def load_survey = @survey = current_family.surveys.find(params[:id])

  def survey_params
    p = params.require(:survey).permit(:title, :intro, :closes_on, :hide_names, :reunion_id)
    p[:reunion_id] = current_family.reunions.find_by(id: p[:reunion_id])&.id
    p
  end

  # Up to eight question slots from the form: blank prompts are ignored.
  def parsed_questions
    raw = params.dig(:survey, :questions)
    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h.values : []
    raw.first(Survey::MAX_QUESTIONS).filter_map do |q|
      prompt = q["prompt"].to_s.squish
      next if prompt.blank?
      { kind: q["kind"].to_s, prompt: prompt, options: q["options_text"].to_s.lines.map(&:squish).reject(&:blank?) }
    end
  end

  def save_with(questions)
    Survey.transaction do
      @survey.save!
      if @survey.draft?
        @survey.questions.destroy_all
        questions.each_with_index { |q, i| @survey.questions.create!(q.merge(position: i)) }
        raise ActiveRecord::RecordInvalid.new(@survey.tap { |s| s.errors.add(:base, "Add at least one question") }) if questions.empty?
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    @survey.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record.equal?(@survey)
    false
  end

  def slots_from(questions)
    list = questions.map { |q| { kind: q[:kind], prompt: q[:prompt], options_text: Array(q[:options]).join("\n") } }
    list + blank_slots(list.size)
  end

  def blank_slots(have) = Array.new([ Survey::MAX_QUESTIONS - have, 0 ].max) { { kind: "short", prompt: "", options_text: "" } }
end
