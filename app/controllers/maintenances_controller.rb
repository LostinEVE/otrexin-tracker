class MaintenancesController < ApplicationController
  before_action :set_maintenance, only: %i[ show edit update destroy ]

  # GET /maintenances or /maintenances.json
  def index
    @start_date = parse_date(params[:start_date])
    @end_date = parse_date(params[:end_date])

    @maintenances = current_user.maintenances.order(maintenance_date: :desc)
    @maintenances = @maintenances.where("maintenance_date >= ?", @start_date) if @start_date
    @maintenances = @maintenances.where("maintenance_date <= ?", @end_date) if @end_date

    respond_to do |format|
      format.html
      format.json
      format.csv do
        send_data Maintenance.to_csv(@maintenances),
                  filename: "maintenance-#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  # GET /maintenances/1 or /maintenances/1.json
  def show
  end

  # GET /maintenances/new
  def new
    @maintenance = Maintenance.new
  end

  # GET /maintenances/1/edit
  def edit
  end

  # POST /maintenances or /maintenances.json
  def create
    @maintenance = current_user.maintenances.new(maintenance_params)

    respond_to do |format|
      if @maintenance.save
        format.html { redirect_to @maintenance, notice: "Maintenance was successfully created." }
        format.json { render :show, status: :created, location: @maintenance }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @maintenance.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /maintenances/1 or /maintenances/1.json
  def update
    respond_to do |format|
      if @maintenance.update(maintenance_params)
        format.html { redirect_to @maintenance, notice: "Maintenance was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @maintenance }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @maintenance.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /maintenances/1 or /maintenances/1.json
  def destroy
    @maintenance.destroy!

    respond_to do |format|
      format.html { redirect_to maintenances_path, notice: "Maintenance was successfully destroyed.", status: :see_other }
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
    def set_maintenance
      @maintenance = current_user.maintenances.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def maintenance_params
      params.expect(maintenance: [ :maintenance_date, :maintenance_type, :cost, :odometer, :vendor, :notes ])
    end
end
