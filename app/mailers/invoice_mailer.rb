class InvoiceMailer < ApplicationMailer
  def invoice_email
    @invoice = params[:invoice]
    @company = params[:company]
    @message = params[:message]

    recipient = params[:to]
    subject_line = params[:subject].presence || "Invoice ##{@invoice.invoice_number}"
    from_address = @company&.email.presence || "no-reply@otrinvextracker.local"

    mail(to: recipient, from: from_address, subject: subject_line)
  end
end
