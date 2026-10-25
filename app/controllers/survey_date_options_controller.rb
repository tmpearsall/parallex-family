# Turn the dates people suggested into proposed dates on a reunion, so the existing vote takes over.
class SurveyDateOptionsController < TenantController
  before_action :organizer_only!

  def create
    survey = current_family.surveys.find(params[:survey_id])
    question = survey.questions.find(params[:question_id])
    reunion = current_family.reunions.find(params[:reunion_id])
    return redirect_to(survey_path(survey), alert: "That is not a date question.") unless question.kind == "dates"
    tally = Hash.new(0)
    SurveyAnswer.where(survey_question_id: question.id).find_each { |a| a.choices.each { |d| tally[d] += 1 } }
    existing = reunion.date_options.pluck(:starts_on).map(&:to_s).to_set
    made = 0
    tally.sort_by { |d, n| [ -n, d ] }.first(10).each do |d, n|
      next if existing.include?(d)
      reunion.date_options.create!(starts_on: Date.iso8601(d), note: "Suggested in the survey (#{n} #{'person'.pluralize(n)})")
      made += 1
    rescue Date::Error, ActiveRecord::RecordInvalid
      next
    end
    redirect_to survey_path(survey), notice: "Added #{made} proposed #{'date'.pluralize(made)} to #{reunion.title}. Members can vote on them now."
  end
end
