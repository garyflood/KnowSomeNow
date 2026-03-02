class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def after_sign_up_path_for(resource)
    user_path(resource)  # Redirect to user show page
  end

  def after_sign_in_path_for(resource)
    user_path(resource)  # Optional: also redirect after sign in
  end
end
