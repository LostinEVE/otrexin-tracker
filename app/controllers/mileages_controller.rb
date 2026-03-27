class MileagesController < ApplicationController
  before_action :set_mileage, only: %i[ show edit update destroy ]

  # GET /mileages or /mileages.json
  def index
    @mileages = Mileage.all
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
    @mileage = Mileage.new(mileage_params)

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
      @mileage = Mileage.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def mileage_params
      params.expect(mileage: [ :trip_date, :load_number, :origin, :destination, :miles, :revenue, :notes ])
    end
end
