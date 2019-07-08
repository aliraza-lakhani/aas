class StoreController < ApplicationController
  include CurrentCart
  before_action :set_cart
  def index
    @products=Product.order(:price)
    p @products
    @line_items=LineItem.find_by(cart_id: session[:cart_id])
    p @line_items
  end
end
