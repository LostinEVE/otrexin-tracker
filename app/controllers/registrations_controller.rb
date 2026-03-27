class RegistrationsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.email = @user.email.to_s.strip.downcase

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Account created. Your cloud workspace is ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email, :password, :password_confirmation ])
  end
end
