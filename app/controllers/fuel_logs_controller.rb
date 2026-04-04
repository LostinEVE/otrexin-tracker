class FuelLogsController < ApplicationController
  before_action :set_fuel_log, only: %i[ show edit update destroy ]

  # GET /fuel_logs or /fuel_logs.json
  def index
    @fuel_logs = current_user.fuel_logs
  end

  # GET /fuel_logs/1 or /fuel_logs/1.json
  def show
  end

  # GET /fuel_logs/new
  def new
    @fuel_log = FuelLog.new
  end

  # GET /fuel_logs/1/edit
  def edit
  end

  # POST /fuel_logs or /fuel_logs.json
  def create
    @fuel_log = current_user.fuel_logs.new(fuel_log_params)

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
    respond_to do |format|
      if @fuel_log.update(fuel_log_params)
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
      params.expect(fuel_log: [ :fuel_date, :odometer, :gallons, :price_per_gallon, :total_cost, :location, :station, :notes ])
    end
end
