class SettlementImportsController < ApplicationController
  before_action :ensure_trucks!

  MAX_FILES = 60
  MAX_BYTES = 10.megabytes

  def new
    @trucks = current_trucks
  end

  def create
    files = Array(params[:statements]).compact_blank
    return redirect_to new_settlement_import_path, alert: "Choose at least one settlement PDF." if files.empty?

    if files.size > MAX_FILES
      return redirect_to new_settlement_import_path, alert: "Import at most #{MAX_FILES} statements at a time."
    end

    oversized = files.find { |file| file.size.to_i > MAX_BYTES }
    if oversized
      return redirect_to new_settlement_import_path,
                         alert: "#{oversized.original_filename} is larger than #{MAX_BYTES / 1.megabyte} MB."
    end

    truck = current_user.trucks.find_by(id: params[:truck_id]) || current_user.default_truck
    @outcomes = SettlementImporter.new(user: current_user, truck: truck).import_all(files)
    @trucks = current_trucks

    render :create
  end
end
