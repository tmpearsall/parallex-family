# The personal link: no login, one person, one survey. Answers can be changed until the survey closes.
class SurveyResponsesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load

  def show
    return render(:closed) unless @survey.accepting?
    @existing = existing_answers
  end

  def update
    return render(:closed) unless @survey.accepting?
    answers = params[:answers].respond_to?(:to_unsafe_h) ? params[:answers].to_unsafe_h : {}
    SurveyResponse.transaction do
      resp = SurveyResponse.find_or_create_by!(survey: @survey, survey_recipient: @recipient)
      @survey.questions.each do |q|
        a = resp.answers.find_or_initialize_by(survey_question: q)
        a.assign_attributes(clean(q, answers[q.id.to_s]))
        a.body.blank? && a.choices.empty? ? a.destroy : a.save!
      end
      resp.touch
    end
    render :thanks
  rescue ActiveRecord::RecordInvalid
    @existing = existing_answers
    flash.now[:alert] = "One of the answers was too long."
    render :show, status: :unprocessable_entity
  end

  private

  def load
    @recipient = SurveyRecipient.find_by_token(params[:token])
    return render(plain: "This link is not valid.", status: :not_found) unless @recipient
    @survey = @recipient.survey
    @family = @survey.family
  end

  def existing_answers
    resp = @recipient.response
    resp ? resp.answers.index_by(&:survey_question_id) : {}
  end

  # Only what the question allows: a listed choice, a real date, bounded text.
  def clean(question, raw)
    case question.kind
    when "single"
      v = raw.to_s
      { body: nil, choices: question.options.include?(v) ? [ v ] : [] }
    when "multi"
      v = Array(raw).map(&:to_s) & question.options
      { body: nil, choices: v }
    when "dates"
      h = raw.is_a?(Hash) ? raw : {}
      dates = Array(h["dates"]).map(&:to_s).filter_map { |d| valid_date(d) }.uniq.first(5)
      { body: h["note"].to_s.strip.first(2000).presence, choices: dates }
    else
      { body: raw.to_s.strip.first(question.kind == "short" ? 300 : 2000).presence, choices: [] }
    end
  end

  def valid_date(text)
    Date.iso8601(text).to_s if text.present?
  rescue Date::Error
    nil
  end
end
