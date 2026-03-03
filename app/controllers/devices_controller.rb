class DevicesController < ApplicationController
  def create
    @device = Device.new(device_params)
    @device.user = current_user

    # Make API call and print to console
    puts "\n" + ("=" * 50)
    puts "🤖 MAKING API CALL TO RUBYLLM"
    puts "=" * 50

    begin
      chat = RubyLLM.chat
      system_prompt = "You are an expert in using devices.
    Give me step by step instructions to use a device.
    Answer concisely in Markdown"

      chat.with_instructions(system_prompt)
      response = chat.ask("How do I use a #{@device.name}?")

      # Store the API response
      @api_response = response.content

      # Print the response to console
      puts "\n📱 DEVICE: #{@device.name}"
      puts "📝 RESPONSE:"
      puts "-" * 30
      puts @api_response
      puts "-" * 30
      puts "✅ API call completed!"
    rescue StandardError => e
      @api_response = "Unable to generate instructions at this time. Error: #{e.message}"
      puts "❌ ERROR: #{e.message}"
      puts e.backtrace[0..5] # Show first few lines of backtrace
    end

    puts ("=" * 50) + "\n\n"

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
      render 'users/show'
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

  private

  def device_params
    params.require(:device).permit(:name)
  end
end
