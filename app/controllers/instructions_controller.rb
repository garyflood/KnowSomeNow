class InstructionsController < ApplicationController
  before_action :set_device, only: %i[create update]
  before_action :set_instruction, only: [:update]

  def create
    @instruction = @device.build_instruction(instruction_params)
    if @instruction.save
      redirect_to user_path(@device.user), notice: 'Instruction was successfully created.'
    else
      redirect_to user_path(@device.user), alert: 'There was a problem creating the instruction.'
    end
  end

  def update
    begin
      chat = RubyLLM.chat
      system_prompt = <<~PROMPT
        You are an expert in using devices.
        Given the old instructions, clarify or improve only the part related to the user's message.
        Return the full instructions, with the clarified part updated and all other steps unchanged.
        Answer concisely in Markdown.
      PROMPT

      chat.with_instructions(system_prompt)

      # Add the old steps as a message to the chat history
      chat.add_message(role: "system", content: "Old instructions: #{@instruction.steps}")

      # Ask the LLM to clarify/update based on the user's message
      response = chat.ask(instruction_params[:steps])

      # Update the steps with the new response
      @instruction.steps = response.content
    rescue StandardError => e
      flash[:alert] = "Unable to update instructions at this time. Error: #{e.message}"
      redirect_to device_path(@device) and return
    end

    if @instruction.save
      redirect_to device_path(@device), notice: 'Instruction was successfully updated.'
    else
      redirect_to device_path(@device), alert: 'There was a problem updating the instruction.'
    end
  end

  private

  def set_device
    @device = Device.find(params[:device_id])
  end

  def set_instruction
    @instruction = @device.instruction
  end

  def instruction_params
    params.require(:instruction).permit(:steps)
  end
end
