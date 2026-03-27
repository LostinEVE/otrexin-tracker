class MileagesController < ApplicationController
  before_action :set_mileage, only: %i[ show edit update destroy ]

  # GET /mileages or /mileages.json
  def index
    @mileages = current_user.mileages

    @total_miles = @mileages.sum(:miles).to_f
    @total_revenue = @mileages.sum(:revenue).to_f
    @revenue_per_mile = @total_miles.positive? ? (@total_revenue / @total_miles).round(4) : nil
    @cost_per_mile = @total_miles.positive? ? (current_user.expenses.sum(:amount).to_f / @total_miles).round(4) : nil
  end

  # GET /mileages/1 or /mileages/1.json
  def show
  end

  # GET /mileages/new
  def new
    @mileage = Mileage.new
  end

  # GET /mileages/1/edit
  def edit
  end

  # POST /mileages or /mileages.json
  def create
    @mileage = current_user.mileages.new(mileage_params)

    respond_to do |format|
      if @mileage.save
        format.html { redirect_to @mileage, notice: "Mileage was successfully created." }
        format.json { render :show, status: :created, location: @mileage }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @mileage.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /mileages/1 or /mileages/1.json
  def update
    respond_to do |format|
      if @mileage.update(mileage_params)
        format.html { redirect_to @mileage, notice: "Mileage was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @mileage }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @mileage.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /mileages/1 or /mileages/1.json
  def destroy
    @mileage.destroy!

    respond_to do |format|
      format.html { redirect_to mileages_path, notice: "Mileage was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mileage
      @mileage = current_user.mileages.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def mileage_params
      params.expect(mileage: [ :trip_date, :load_number, :origin, :destination, :miles, :revenue, :notes ])
    end
end
