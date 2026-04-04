class CompanyProfilesController < ApplicationController
  before_action :set_company_profile

  def show
  end

  def edit
  end

  def update
    if @company_profile.update(company_profile_params)
      redirect_to company_profile_path, notice: "Company profile updated. Invoices now use this header info."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_company_profile
    @company_profile = current_user.company_profile || current_user.build_company_profile
  end

  def company_profile_params
    params.expect(company_profile: [
      :company_name,
      :address_line1,
      :address_line2,
      :city,
      :state,
      :zip,
      :phone,
      :email,
      :dot_number,
      :mc_number
    ])
  end
end
