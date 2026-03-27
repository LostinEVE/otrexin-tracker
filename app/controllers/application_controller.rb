class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?, :current_company_profile

  before_action :require_login

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?
    return if request.path == "/up"

    redirect_to login_path, alert: "Please sign in to access your cloud data."
  end

  def current_company_profile
    return CompanyProfile.new unless logged_in?

    @current_company_profile ||= current_user.company_profile || current_user.build_company_profile.tap(&:save!)
  end
end
