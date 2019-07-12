class SessionsController < ApplicationController
  skip_before_action :authorize

  def new
  end

  def create
    # if user.try(:authenticate, params[:password])
    #   session[:user_id] = user.id
    #   redirect_to admin_url
    # else
    #   redirect_to login_url, alert: "Invalid user/password combination"
    # end

    user = User.find_by(name: params[:name])
    if user && user.authenticate(params[:password])
      flash.now[:success] = "Logged-In successfully"
      log_in user
      redirect_back_or admin_url

      #  flash[:success]="Logged-In successfully"
      #  log_in user
      #  params[:session][:remember_me] == '1' ? remember(user) : forget(user)
      #  redirect_back_or user
    else
      redirect_to login_url, alert: "Invalid user/password combination"
    end
  end

  def destroy
    # log_out if logged_in?
    session[:user_id] = nil
    redirect_to store_index_url, notice: "Logged out"
  end
end
