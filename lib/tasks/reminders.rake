namespace :reminders do
  desc "Send today's reminder digests (safe to run more than once a day)"
  task send: :environment do
    puts ReminderRunner.new.run.inspect
  end
end
