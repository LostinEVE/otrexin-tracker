class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("SMTP_FROM", ENV.fetch("SMTP_USERNAME", "no-reply@otrinvextracker.local")) }
  layout "mailer"
end
