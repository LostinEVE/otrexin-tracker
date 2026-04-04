class SupportController < ApplicationController
  def show
    configured_url = ENV["PAYPAL_BUY_ME_COFFEE_URL"].to_s.strip
    @coffee_url = configured_url.presence || "https://paypal.me/JosephRogers655443"
  end

  def thank_you
  end
end
