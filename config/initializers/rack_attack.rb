# Public URL: slow down password guessing and general scraping.
class Rack::Attack
  throttle("logins/ip", limit: 10, period: 5.minutes) { |req| req.ip if req.path == "/users/sign_in" && req.post? }
  throttle("logins/email", limit: 6, period: 15.minutes) do |req|
    req.params.dig("user", "email").to_s.downcase.presence if req.path == "/users/sign_in" && req.post?
  end
  throttle("setpw/ip", limit: 10, period: 15.minutes) { |req| req.ip if req.path.start_with?("/set_password") }
  throttle("board/ip", limit: 30, period: 10.minutes) { |req| req.ip if req.path.start_with?("/board") && !req.get? }
  throttle("calendar/ip", limit: 60, period: 5.minutes) { |req| req.ip if req.path.start_with?("/calendar/") }
  throttle("req/ip", limit: 300, period: 5.minutes) { |req| req.ip unless req.path == "/up" }
end
