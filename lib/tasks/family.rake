namespace :family do
  desc "Create a family with its first organizer's invitation link: rake family:create[Name,organizer@email,slug]"
  task :create, [ :name, :email, :slug ] => :environment do |_t, args|
    abort "usage: rake 'family:create[Name,organizer@email,slug]'" if args[:name].blank? || args[:email].blank?
    family = Family.create!(name: args[:name], slug: args[:slug].to_s)
    _, raw = Invitation.issue!(family: family, email: args[:email], role: "organizer")
    host = ENV["FAMILY_HOST"].presence || "localhost:3000"
    scheme = host.start_with?("localhost") ? "http" : "https"
    puts "#{family.name} (/f/#{family.slug})\nOne-time link (valid 7 days): #{scheme}://#{host}/invite/#{raw}"
  end

  desc "Make an account a platform administrator (support only): rake family:platform_admin[email]"
  task :platform_admin, [ :email ] => :environment do |_t, args|
    User.find_by!(email: args[:email].to_s.strip.downcase).update!(platform_admin: true)
    puts "ok"
  end

  desc "Fresh set-password link for an existing account: rake family:reset[email]"
  task :reset, [ :email ] => :environment do |_t, args|
    user = User.find_by!(email: args[:email].to_s.strip.downcase)
    host = ENV["FAMILY_HOST"].presence || "localhost:3000"
    scheme = host.start_with?("localhost") ? "http" : "https"
    puts "#{scheme}://#{host}/set_password/#{user.issue_set_password_token!}"
  end
end
