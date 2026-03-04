class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
    return unless user_signed_in?

    redirect_to user_path(current_user) # Redirects to /users/:id
  end
end
