class Cart < ApplicationRecord
    has_many :line_items, dependent: :destroy

    def total_price
        line_items.inject(0){|sum,x| sum+=x.l_price}
    end
    def add_product(product)
        current_item = line_items.find_by(product_id: product.id)
        if current_item
            current_item.quantity += 1
        else
            current_item = line_items.build(product_id: product.id)
        end
        current_item
    end
    def delete_product(product)
        del_item = line_items.find_by(product_id: product.id)
        del_item.quantity -=1
    end
end
