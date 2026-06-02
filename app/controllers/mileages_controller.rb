class MileagesController < ApplicationController
  before_action :set_mileage, only: %i[ show edit update destroy ]
  before_action :ensure_trucks!
  before_action :set_trucks, only: %i[ index new edit create update ]

  def index
    @start_date = parse_date(params[:start_date])
    @end_date = parse_date(params[:end_date])

    @mileages = current_user.mileages.includes(:truck)
    @mileages = @mileages.where(truck: selected_truck) if selected_truck
    @mileages = @mileages.where("trip_date >= ?", @start_date) if @start_date
    @mileages = @mileages.where("trip_date <= ?", @end_date) if @end_date

    @total_miles = Mileage.total_miles(@mileages)
    @total_revenue = Mileage.total_revenue(@mileages)
    @revenue_per_mile = Mileage.overall_revenue_per_mile(@mileages)
    @cost_per_mile = Mileage.cost_per_mile(@mileages, expense_scope: matching_expenses)
    @mileages = @mileages.order(trip_date: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @mileage = current_user.mileages.new(truck: selected_truck || current_user.default_truck)
  end

  def edit
  end

  def create
    permitted = mileage_params
    truck_id = permitted.delete(:truck_id)
    @mileage = current_user.mileages.new(permitted)
    assign_owned_truck(@mileage, truck_id)

    respond_to do |format|
      if @mileage.save
        format.html { redirect_to @mileage, notice: "Mileage entry was successfully created." }
        format.json { render :show, status: :created, location: @mileage }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @mileage.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    permitted = mileage_params
    truck_id = permitted.delete(:truck_id)
    assign_owned_truck(@mileage, truck_id)

    respond_to do |format|
      if @mileage.update(permitted)
        format.html { redirect_to @mileage, notice: "Mileage entry was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @mileage }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @mileage.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @mileage.destroy!

    respond_to do |format|
      format.html { redirect_to mileages_path, notice: "Mileage entry was successfully destroyed.", status: :see_other }
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

  def matching_expenses
    scope = current_user.expenses
    scope = scope.where(truck: selected_truck) if selected_truck
    scope = scope.where("expense_date >= ?", @start_date) if @start_date
    scope = scope.where("expense_date <= ?", @end_date) if @end_date
    scope
  end

  def set_mileage
    @mileage = current_user.mileages.find(params.expect(:id))
  end

  def mileage_params
    params.expect(mileage: [ :truck_id, :trip_date, :load_number, :origin, :destination, :miles, :revenue, :notes ])
  end

  def set_trucks
    @trucks = current_trucks
  end
end
