namespace :family do
  desc "Create or find an account and print a one-time set-password link: rake family:invite[email,Name,admin]"
  task :invite, [ :email, :name, :admin ] => :environment do |_t, args|
    email = args[:email].to_s.strip.downcase
    abort "usage: rake 'family:invite[email,Name,admin]'" if email.blank?
    user = User.find_or_initialize_by(email: email)
    user.name = args[:name] if args[:name].present?
    user.admin = true if args[:admin].to_s == "admin"
    user.password = "#{SecureRandom.base58(30)}aZ9!" if user.new_record?
    user.save!
    token = user.issue_set_password_token!
    host = ENV["FAMILY_HOST"].presence || "localhost:3000"
    scheme = host.start_with?("localhost") ? "http" : "https"
    puts "#{user.name || email} <#{email}>#{' (admin)' if user.admin?}"
    puts "One-time link (valid 7 days): #{scheme}://#{host}/set_password/#{token}"
  end

  desc "Issue a fresh set-password link for an existing account: rake family:reset[email]"
  task :reset, [ :email ] => :environment do |_t, args|
    user = User.find_by!(email: args[:email].to_s.strip.downcase)
    host = ENV["FAMILY_HOST"].presence || "localhost:3000"
    scheme = host.start_with?("localhost") ? "http" : "https"
    puts "#{scheme}://#{host}/set_password/#{user.issue_set_password_token!}"
  end
end
