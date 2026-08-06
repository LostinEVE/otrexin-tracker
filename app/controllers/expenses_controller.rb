class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[ show edit update destroy ]
  before_action :ensure_trucks!
  before_action :set_trucks, only: %i[ index new edit create update ]

  # GET /expenses or /expenses.json
  def index
    @start_date = parse_date(params[:start_date])
    @end_date = parse_date(params[:end_date])

    @expenses = current_user.expenses.includes(:truck)
    @expenses = @expenses.where(truck: selected_truck) if selected_truck
    @expenses = @expenses.where("expense_date >= ?", @start_date) if @start_date
    @expenses = @expenses.where("expense_date <= ?", @end_date) if @end_date

    @expense_by_category = @expenses.group(:category).sum(:amount).sort_by { |_k, v| -v.to_d }
    @expense_total = @expenses.sum(:amount).to_d
    @expenses = @expenses.order(expense_date: :desc)

    respond_to do |format|
      format.html
      format.json
      format.csv do
        send_data Expense.to_csv(@expenses),
                  filename: "expenses-#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  # GET /expenses/1 or /expenses/1.json
  def show
  end

  # GET /expenses/new
  def new
    @expense = current_user.expenses.new(prefill_params)
    @expense.truck ||= selected_truck || current_user.default_truck
  end

  # GET /expenses/1/edit
  def edit
  end

  # POST /expenses or /expenses.json
  def create
    permitted = expense_params
    truck_id = permitted.delete(:truck_id)
    @expense = current_user.expenses.new(permitted)
    assign_owned_truck(@expense, truck_id)

    respond_to do |format|
      if @expense.save
        format.html { redirect_to @expense, notice: "Expense was successfully created." }
        format.json { render :show, status: :created, location: @expense }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @expense.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /expenses/1 or /expenses/1.json
  def update
    permitted = expense_params
    truck_id = permitted.delete(:truck_id)
    assign_owned_truck(@expense, truck_id)

    respond_to do |format|
      if @expense.update(permitted)
        format.html { redirect_to @expense, notice: "Expense was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @expense }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @expense.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /expenses/1 or /expenses/1.json
  def destroy
    @expense.destroy!

    respond_to do |format|
      format.html { redirect_to expenses_path, notice: "Expense was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def parse_date(value)
      return nil if value.blank?
      Date.parse(value)
    rescue ArgumentError
      nil
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_expense
      @expense = current_user.expenses.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def expense_params
      params.expect(expense: [ :expense_date, :category, :vendor, :amount, :gallons, :notes, :truck_id ])
    end

    # Lets the P&L reconciliation table hand off an unrecorded fuel or
    # maintenance cost straight into a prefilled expense form. The truck is
    # resolved through the user's own trucks so a foreign id cannot be injected.
    def prefill_params
      permitted = params.permit(:expense_date, :category, :vendor, :amount, :gallons)
      attributes = permitted.to_h.compact_blank

      if params[:truck_id].present?
        attributes[:truck] = current_user.trucks.find_by(id: params[:truck_id])
      end

      attributes.compact
    end

    def set_trucks
      @trucks = current_trucks
    end
end
