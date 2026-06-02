class TrucksController < ApplicationController
  before_action :set_truck, only: %i[edit update destroy]

  def index
    @trucks = current_user.trucks.active_first
  end

  def new
    @truck = current_user.trucks.new(active: true)
  end

  def edit
  end

  def create
    @truck = current_user.trucks.new(truck_params)

    if @truck.save
      redirect_to trucks_path, notice: "Truck added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @truck.update(truck_params)
      redirect_to trucks_path, notice: "Truck updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if current_user.trucks.count == 1
      redirect_to trucks_path, alert: "At least one truck must stay on the account."
      return
    end

    if @truck.in_use?
      redirect_to trucks_path, alert: "This truck already has records. Mark it inactive instead of deleting it."
      return
    end

    @truck.destroy!
    redirect_to trucks_path, notice: "Truck deleted."
  end

  private

  def set_truck
    @truck = current_user.trucks.find(params.expect(:id))
  end

  def truck_params
    params.expect(truck: [ :name, :unit_number, :vin, :year, :make, :model, :active ])
  end
end
