class LineItem < ApplicationRecord
  belongs_to :product
  belongs_to :cart
  def l_price
    product.price*quantity
  end
end
