class TestMailer < ApplicationMailer
  def hello
    @user = params[:user]
    @family = params[:family]
    mail(to: @user.email, subject: "Test email from #{@family.name}")
  end
end
