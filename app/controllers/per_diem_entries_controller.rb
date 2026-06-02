class PerDiemEntriesController < ApplicationController
  before_action :set_per_diem_entry, only: %i[edit update destroy]
  before_action :set_trucks, only: %i[index new edit create update]

  def index
    @per_diem_entries = current_user.per_diem_entries.includes(:truck).order(start_date: :desc)
  end

  def new
    @per_diem_entry = current_user.per_diem_entries.new
  end

  def edit
  end

  def create
    @per_diem_entry = current_user.per_diem_entries.new(per_diem_entry_params)

    if @per_diem_entry.save
      redirect_to per_diem_entries_path, notice: "Per diem entry saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @per_diem_entry.update(per_diem_entry_params)
      redirect_to per_diem_entries_path, notice: "Per diem entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @per_diem_entry.destroy!
    redirect_to per_diem_entries_path, notice: "Per diem entry deleted."
  end

  private

  def set_per_diem_entry
    @per_diem_entry = current_user.per_diem_entries.find(params.expect(:id))
  end

  def set_trucks
    @trucks = current_trucks
  end

  def per_diem_entry_params
    params.expect(per_diem_entry: [ :truck_id, :start_date, :end_date, :qualifying_days, :daily_rate, :notes ])
  end
end
