class DevicesController < ApplicationController
  # rubocop:disable Metrics/MethodLength
  def create
    @device = Device.new(device_params)
    @device.user = current_user

    if params[:device][:image].present?
      uploaded_file = params[:device][:image]

      # Upload to Cloudinary
      result = Cloudinary::Uploader.upload(uploaded_file.tempfile.path, folder: "knowsomenow/devices")
      @device.image = result["secure_url"]

      # Use LLM to identify the object in the image
      chat = RubyLLM.chat(model: "gpt-4o")
      prompt = "You are expert in identiying device modely.
      Respond with the name exact model of the device (i.e. macbook pro M4).
      If you're unsure exactly what model this device is,
      repond with the model family (i.e. Macbook).
      If you're unsure of the model family,
      Respond with the type of device (i.e. Laptop).
      Answer concisely with only the name. Do not give me full sentences."

      # Pass the file path to the LLM
      response = chat.ask(prompt, with: { image: uploaded_file.tempfile.path })
      @device.name = response.content
    end

    begin
      chat = RubyLLM.chat
      system_prompt = "You are an expert in using devices.
    Give me step by step instructions to use a device.
    Answer concisely in Markdown"

      chat.with_instructions(system_prompt)
      response = chat.ask("How do I use a #{@device.name}?")

      @api_response = response.content
    rescue StandardError => e
      @api_response = "Unable to generate instructions at this time. Error: #{e.message}"
    end

    # Fetch a relevant device image from Wikipedia and store it via Cloudinary
    @device.image ||= generate_and_upload_image(@device.name)

    if @device.save
      instruction = @device.build_instruction(steps: @api_response)

      if instruction.save
        flash[:notice] = 'Device was successfully added with instructions!'
      else
        flash[:alert] = 'Device saved but there was a problem saving the instructions.'
      end

      redirect_to device_path(@device)
    else
      @user = @device.user
      flash.now[:alert] = 'There was a problem adding the device.'
      render 'users/show', status: :unprocessable_entity
    end
  end
  # rubocop:enable Metrics/MethodLength

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

  # Searches Wikipedia for the device, uploads the found image to Cloudinary,
  # and returns the permanent Cloudinary URL. Returns nil if no image is found.
  def generate_and_upload_image(device_name)
    photo_url = fetch_wikipedia_image_url(device_name)
    return nil if photo_url.nil?

    result = Cloudinary::Uploader.upload(photo_url, folder: "knowsomenow/devices")
    result["secure_url"]
  rescue StandardError => e
    Rails.logger.error("Image fetch/upload failed: #{e.message}")
    nil
  end

  # Uses Wikipedia's opensearch API to find the correct article title,
  # then returns the page thumbnail URL from the REST summary API.
  def fetch_wikipedia_image_url(device_name)
    title = search_wikipedia_title(device_name)
    return nil if title.nil?

    encoded_title = URI.encode_uri_component(title)
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded_title}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "KnowSomeNow/1.0 (device-instructions-app)"
    JSON.parse(http.request(request).body).dig("thumbnail", "source")
  end

  # Searches Wikipedia's opensearch API and returns the best-matching article title.
  def search_wikipedia_title(device_name)
    encoded_query = URI.encode_uri_component(device_name)
    uri = URI("https://en.wikipedia.org/w/api.php?action=opensearch&search=#{encoded_query}&limit=1&format=json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "KnowSomeNow/1.0 (device-instructions-app)"
    results = JSON.parse(http.request(request).body)
    results[1]&.first
  end

  def device_params
    params.require(:device).permit(:name, :image)
  end
end
