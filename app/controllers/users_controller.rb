class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @device = Device.new # Needed for the "Add Device" form
    @devices = @user.devices.includes(:instruction)
  end
end
