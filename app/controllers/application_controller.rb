class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?, :current_company_profile, :current_trucks, :selected_truck

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

  def current_trucks
    return Truck.none unless logged_in?

    @current_trucks ||= current_user.trucks.order(active: :desc, name: :asc, created_at: :asc)
  end

  # Settlements worth a second look, keyed by settlement id: the pay deviation
  # caught at import plus any lease-audit findings. The audit contributes only
  # once lease terms are on file — with none, every line would read as
  # unauthorized, which is noise rather than review material. A settlement the
  # driver has marked reviewed stays quiet unless explicitly asked for.
  def settlement_review_notes(settlements, include_reviewed: false)
    settlements = settlements.reject { |s| s.reviewed_at.present? } unless include_reviewed

    notes = {}
    settlements.each do |settlement|
      (notes[settlement.id] ||= []) << settlement.pay_deviation if settlement.pay_deviation.present?
    end

    if current_user.lease_terms.exists?
      ids = settlements.map(&:id)
      LeaseAudit.new(user: current_user).findings.each do |finding|
        next unless finding.settlement && ids.include?(finding.settlement.id)

        (notes[finding.settlement.id] ||= []) << finding.reason
      end
    end

    notes
  end

  def selected_truck
    return @selected_truck if defined?(@selected_truck)

    @selected_truck = if params[:truck_id].present?
      current_user.trucks.find_by(id: params[:truck_id])
    end
  end

  def ensure_trucks!
    return if current_user.trucks.exists?

    redirect_to trucks_path, alert: "Add a truck before logging trips, fuel, invoices, or expenses."
  end

  def assign_owned_truck(record, truck_id)
    if truck_id.present?
      record.truck = current_user.trucks.find(truck_id)
    else
      record.errors.add(:truck, "must be selected")
    end
  end
end
