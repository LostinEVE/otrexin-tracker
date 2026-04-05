class InvoiceMailer < ApplicationMailer
  def invoice_email
    @invoice = params[:invoice]
    @company = params[:company]
    @message = params[:message]

    recipient = params[:to]
    subject_line = params[:subject].presence || "Invoice ##{@invoice.invoice_number}"

    # Must send FROM the authenticated SMTP account or Outlook will reject the message.
    # Use the company display name so the recipient sees a friendly sender name.
    smtp_from = ENV["SMTP_USERNAME"].presence || "no-reply@otrinvextracker.local"
    company_name = @company&.company_name.presence || "Invoice"
    from_address = "#{company_name} <#{smtp_from}>"

    # reply_to routes replies back to the user's own company email (if set).
    company_email = @company&.email.presence

    mail_options = { to: recipient, from: from_address, subject: subject_line }
    mail_options[:reply_to] = company_email if company_email

    mail(mail_options)
  end
end
