class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[ show edit update destroy email send_email ]
  before_action :ensure_trucks!
  before_action :set_trucks, only: %i[ index new edit create update ]

  # GET /invoices or /invoices.json
  def index
    @invoices = current_user.invoices.includes(:truck)
    @invoices = @invoices.where(truck: selected_truck) if selected_truck
  end

  # GET /invoices/1 or /invoices/1.json
  def show
  end

  # GET /invoices/new
  def new
    @invoice = current_user.invoices.new(truck: selected_truck || current_user.default_truck)
  end

  # GET /invoices/1/edit
  def edit
  end

  # GET /invoices/1/email
  def email
    @default_subject = "Invoice ##{@invoice.invoice_number} - #{current_company_profile.company_name.presence || 'Invoice'}"
    @default_recipient = ""
  end

  # POST /invoices/1/send_email
  def send_email
    email_params = params.expect(invoice_email: [ :to, :subject, :message ])

    if email_params[:to].blank?
      redirect_to email_invoice_path(@invoice), alert: "Recipient email is required."
      return
    end

    InvoiceMailer.with(
      invoice: @invoice,
      company: current_company_profile,
      to: email_params[:to],
      subject: email_params[:subject],
      message: email_params[:message]
    ).invoice_email.deliver_now!

    if ActionMailer::Base.delivery_method == :file
      redirect_to @invoice, alert: "SMTP is not configured, so the email was written to tmp/mails instead of being sent."
    else
      redirect_to @invoice, notice: "Invoice emailed successfully to #{email_params[:to]}."
    end
  rescue StandardError => e
    redirect_to email_invoice_path(@invoice), alert: "Could not send email: #{e.message}"
  end

  # POST /invoices or /invoices.json
  def create
    permitted = invoice_params
    truck_id = permitted.delete(:truck_id)
    @invoice = current_user.invoices.new(permitted)
    assign_owned_truck(@invoice, truck_id)

    respond_to do |format|
      if @invoice.save
        format.html { redirect_to @invoice, notice: "Invoice was successfully created." }
        format.json { render :show, status: :created, location: @invoice }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @invoice.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /invoices/1 or /invoices/1.json
  def update
    permitted = invoice_params
    truck_id = permitted.delete(:truck_id)
    assign_owned_truck(@invoice, truck_id)

    respond_to do |format|
      if @invoice.update(permitted)
        format.html { redirect_to @invoice, notice: "Invoice was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @invoice }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @invoice.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /invoices/1 or /invoices/1.json
  def destroy
    @invoice.destroy!

    respond_to do |format|
      format.html { redirect_to invoices_path, notice: "Invoice was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_invoice
      @invoice = current_user.invoices.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def invoice_params
      params.expect(invoice: [ :invoice_number, :invoice_date, :customer_name, :load_number, :delivery_date, :amount, :product_description, :piece_count, :rate_per_piece, :status, :notes, :truck_id ])
    end

    def set_trucks
      @trucks = current_trucks
    end
end
