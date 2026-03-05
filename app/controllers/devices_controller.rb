class DevicesController < ApplicationController
  def create
    @device = Device.new(device_params)
    @device.user = current_user

    begin
      chat = RubyLLM.chat
      system_prompt = "You are an expert in using devices.
    Give me step by step instructions to use a device.
    Answer concisely in Markdown"

      chat.with_instructions(system_prompt)
      response = chat.ask("How do I use a #{@device.name}?")

      # Store the API response
      @api_response = response.content
    rescue StandardError => e
      @api_response = "Unable to generate instructions at this time. Error: #{e.message}"
    end

    if @device.save
      # Create the instruction associated with this device
      instruction = @device.build_instruction(steps: @api_response)

      if instruction.save
        flash[:notice] = 'Device was successfully added with instructions!'
      else
        flash[:alert] = 'Device saved but there was a problem saving the instructions.'
      end

      redirect_to user_path(@device.user)
    else
      @user = @device.user
      flash.now[:alert] = 'There was a problem adding the device.'
      render 'users/show', status: :unprocessable_entity
    end
  end

  def destroy
    @device = Device.find(params[:id])

    if @device.destroy
      flash[:notice] = "Device was successfully deleted."
    else
      flash[:alert] = "There was a problem deleting the device."
    end

    redirect_to user_path(current_user)
  end

  def show
    @device = Device.find(params[:id])
  end

  private

  def device_params
    params.require(:device).permit(:name)
  end
end
