namespace :mail do
  desc "Send a test SMTP email. Usage: rails \"mail:test[to@example.com]\""
  task :test, [ :to ] => :environment do |_, args|
    recipient = args[:to].presence || ENV["TEST_EMAIL_TO"]

    if recipient.blank?
      abort "Provide recipient: rails \"mail:test[to@example.com]\" or set TEST_EMAIL_TO"
    end

    unless ENV["SMTP_ADDRESS"].present?
      abort "SMTP_ADDRESS is missing. Configure SMTP_* env vars first."
    end

    from_address = ENV["SMTP_USERNAME"].presence || "no-reply@localhost"

    ActionMailer::Base.mail(
      to: recipient,
      from: from_address,
      subject: "Otrexin Tracker SMTP test",
      body: "SMTP test sent at #{Time.current}. If you received this, real email delivery is working."
    ).deliver_now!

    puts "Test email sent to #{recipient} using #{ActionMailer::Base.delivery_method}."
  end
end
