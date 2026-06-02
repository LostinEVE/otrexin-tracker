class DepreciationAssetsController < ApplicationController
  before_action :set_depreciation_asset, only: %i[edit update destroy]
  before_action :set_trucks, only: %i[index new edit create update]

  def index
    @depreciation_assets = current_user.depreciation_assets.includes(:truck).order(placed_in_service_date: :desc)
  end

  def new
    @depreciation_asset = current_user.depreciation_assets.new(depreciation_method: "straight_line", salvage_value: 0)
  end

  def edit
  end

  def create
    @depreciation_asset = current_user.depreciation_assets.new(depreciation_asset_params)

    if @depreciation_asset.save
      redirect_to depreciation_assets_path, notice: "Depreciation asset saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @depreciation_asset.update(depreciation_asset_params)
      redirect_to depreciation_assets_path, notice: "Depreciation asset updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @depreciation_asset.destroy!
    redirect_to depreciation_assets_path, notice: "Depreciation asset deleted."
  end

  private

  def set_depreciation_asset
    @depreciation_asset = current_user.depreciation_assets.find(params.expect(:id))
  end

  def set_trucks
    @trucks = current_trucks
  end

  def depreciation_asset_params
    params.expect(depreciation_asset: [ :truck_id, :name, :asset_type, :placed_in_service_date, :cost_basis, :salvage_value, :recovery_period_years, :depreciation_method, :notes ])
  end
end
