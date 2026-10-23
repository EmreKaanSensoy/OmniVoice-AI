class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :switch_user]
  skip_before_action :verify_authenticity_token, only: [:create, :switch_user]

  def new
    if logged_in?
      redirect_to dashboard_path and return
    end

    @staff_users = User.where(role: %w[admin supervisor agent])
  end

  def create
    user = User.find_by("LOWER(email) = ?", params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Hoş geldiniz, #{user.name}!"
    else
      flash.now[:alert] = "Geçersiz e-posta veya şifre."
      @staff_users = User.where(role: %w[admin supervisor agent])
      render :new, status: :unprocessable_entity
    end
  end

  def switch_user
    user = User.find(params[:id])
    session[:user_id] = user.id
    redirect_to dashboard_path, notice: "Aktif yönetici/temsilci: #{user.name} (#{user.role.titleize})"
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "Oturum başarıyla kapatıldı."
  end
end
