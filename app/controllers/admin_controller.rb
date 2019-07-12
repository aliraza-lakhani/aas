class AdminController < ApplicationController
  def index
    if logged_in?
      @total_orders = Order.count
      render "index"
    else
      redirect_to login_url, alert: "Please login as an administrator"
    end
  end
end
