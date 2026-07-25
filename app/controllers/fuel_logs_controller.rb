class FuelLogsController < ApplicationController
  before_action :set_fuel_log, only: %i[ show edit update destroy ]
  before_action :ensure_trucks!
  before_action :set_trucks, only: %i[ index new edit create update ]

  # GET /fuel_logs or /fuel_logs.json
  def index
    @fuel_logs = current_user.fuel_logs.includes(:truck)
    @fuel_logs = @fuel_logs.where(truck: selected_truck) if selected_truck
    @total_miles = FuelLog.total_miles(@fuel_logs)
    @overall_mpg = FuelLog.overall_mpg(@fuel_logs)
    @avg10 = FuelLog.avg_mpg_last(@fuel_logs)
    @excluded_mpg_interval_count = FuelLog.excluded_mpg_interval_count(@fuel_logs)
    @excluded_mileage_interval_count = FuelLog.excluded_mileage_interval_count(@fuel_logs)
    @total_gallons_mtd = @fuel_logs.where("fuel_date >= ?", Date.current.beginning_of_month).sum(:gallons)
    @total_fuel_cost = FuelLog.total_cost(@fuel_logs)
  end

  # GET /fuel_logs/1 or /fuel_logs/1.json
  def show
  end

  # GET /fuel_logs/new
  def new
    @fuel_log = current_user.fuel_logs.new(truck: selected_truck || current_user.default_truck)
  end

  # GET /fuel_logs/1/edit
  def edit
  end

  # POST /fuel_logs or /fuel_logs.json
  def create
    permitted = fuel_log_params
    truck_id = permitted.delete(:truck_id)
    @fuel_log = current_user.fuel_logs.new(permitted)
    assign_owned_truck(@fuel_log, truck_id)

    respond_to do |format|
      if @fuel_log.save
        format.html { redirect_to @fuel_log, notice: "Fuel log was successfully created." }
        format.json { render :show, status: :created, location: @fuel_log }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @fuel_log.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /fuel_logs/1 or /fuel_logs/1.json
  def update
    permitted = fuel_log_params
    truck_id = permitted.delete(:truck_id)
    assign_owned_truck(@fuel_log, truck_id)

    respond_to do |format|
      if @fuel_log.update(permitted)
        format.html { redirect_to @fuel_log, notice: "Fuel log was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @fuel_log }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @fuel_log.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /fuel_logs/1 or /fuel_logs/1.json
  def destroy
    @fuel_log.destroy!

    respond_to do |format|
      format.html { redirect_to fuel_logs_path, notice: "Fuel log was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_fuel_log
      @fuel_log = current_user.fuel_logs.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def fuel_log_params
      params.expect(fuel_log: [ :fuel_date, :odometer, :gallons, :price_per_gallon, :total_cost, :location, :station, :notes, :truck_id ])
    end

    def set_trucks
      @trucks = current_trucks
    end
end
