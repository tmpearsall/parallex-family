# The numbers and answers behind a survey, ready to show. Names are left out when the survey hides them.
class SurveyResults
  Row = Struct.new(:question, :counts, :answers, keyword_init: true)

  def initialize(survey)
    @survey = survey
    @responses = survey.responses.includes(survey_recipient: [ :person ], answers: :survey_question).to_a
  end

  attr_reader :responses

  def total = @survey.recipients.count
  def answered = @responses.size
  def pending_recipients = @survey.recipients.includes(:response).reject(&:responded?)

  def rows
    @survey.questions.map do |q|
      answers = @responses.flat_map { |r| r.answers.select { |a| a.survey_question_id == q.id }.map { |a| [ r, a ] } }
      counts = nil
      if q.choice?
        counts = q.options.index_with { 0 }
        answers.each { |_, a| a.choices.each { |c| counts[c] += 1 if counts.key?(c) } }
      elsif q.kind == "dates"
        counts = Hash.new(0)
        answers.each { |_, a| a.choices.each { |c| counts[c] += 1 } }
        counts = counts.sort_by { |d, n| [ -n, d ] }.to_h
      end
      Row.new(question: q, counts: counts, answers: answers)
    end
  end

  def name_for(response) = @survey.hide_names ? nil : (response.survey_recipient.name.presence || response.survey_recipient.email)
end
