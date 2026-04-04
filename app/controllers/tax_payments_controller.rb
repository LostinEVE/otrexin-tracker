class TaxPaymentsController < ApplicationController
  before_action :set_tax_payment, only: %i[ show edit update destroy ]

  # GET /tax_payments or /tax_payments.json
  def index
    @tax_payments = current_user.tax_payments

    @ytd_revenue = current_user.invoices.where(status: 'paid').where('invoice_date >= ?', Date.current.beginning_of_year).sum(:amount).to_f
    @ytd_expenses = current_user.expenses.where('expense_date >= ?', Date.current.beginning_of_year).sum(:amount).to_f
  end

  # GET /tax_payments/1 or /tax_payments/1.json
  def show
  end

  # GET /tax_payments/new
  def new
    @tax_payment = TaxPayment.new
  end

  # GET /tax_payments/1/edit
  def edit
  end

  # POST /tax_payments or /tax_payments.json
  def create
    @tax_payment = current_user.tax_payments.new(tax_payment_params)

    respond_to do |format|
      if @tax_payment.save
        format.html { redirect_to tax_payments_path, notice: "Payment recorded!" }
        format.json { render :show, status: :created, location: @tax_payment }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tax_payment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tax_payments/1 or /tax_payments/1.json
  def update
    respond_to do |format|
      if @tax_payment.update(tax_payment_params)
        format.html { redirect_to @tax_payment, notice: "Tax payment was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @tax_payment }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tax_payment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tax_payments/1 or /tax_payments/1.json
  def destroy
    @tax_payment.destroy!

    respond_to do |format|
      format.html { redirect_to tax_payments_path, notice: "Tax payment was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tax_payment
      @tax_payment = current_user.tax_payments.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def tax_payment_params
      params.expect(tax_payment: [ :payment_date, :quarter, :amount, :notes ])
    end
end
