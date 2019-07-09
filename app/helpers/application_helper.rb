module ApplicationHelper
    def render_if(conditions,record)
        if conditions
            render record
        end
    end
end
