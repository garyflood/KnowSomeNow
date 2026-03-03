class InstructionsController < ApplicationController
  before_action :set_device, only: [:create]

  def create
    @instruction = @device.build_instruction(instruction_params)

    if @instruction.save
      redirect_to user_path(@device.user), notice: 'Instruction was successfully created.'
    else
      redirect_to user_path(@device.user), alert: 'There was a problem creating the instruction.'
    end
  end

  private

  def set_device
    @device = Device.find(params[:device_id])
  end

  def instruction_params
    params.require(:instruction).permit(:steps)
  end
end
