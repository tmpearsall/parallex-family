Rails.application.config.after_initialize do
  ActionMailer::Base.register_interceptor(EmailLogInterceptor)
  ActionMailer::Base.register_observer(EmailLogObserver)
end
