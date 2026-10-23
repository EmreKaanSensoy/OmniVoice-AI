class ApplicationController < ActionController::Base
  helper_method :current_user, :current_organization, :logged_in?

  before_action :set_current_organization
  before_action :authenticate_user!

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def current_organization
    @current_organization ||= current_user&.organization || Organization.first
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    unless current_user
      redirect_to login_path, alert: "Lütfen yönetici paneline giriş yapın."
      return false
    end
    true
  end

  def set_current_organization
    @current_organization = current_organization
  end
end
