class FabricsRacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_fabrics_rack, only: [:show, :destroy, :submit]

  respond_to :html, :js

  # Get /fabrics_racks/1/submit
  def submit
    # This action handles submission of missing fabrics list
    require 'rest-client'

    # Find missing fabrics
    customer = @fabrics_rack.customer
    url = customer.fabrics_url
    customer_fabrics = Fabric.where(fabrics_url: url).where(status: 'Active').pluck(:fabric_number)
    rack_fabrics = Fabric.where(fabrics_rack: @fabrics_rack).where(status: 'Active').pluck(:fabric_number)

    missing_fabric_numbers = customer_fabrics - rack_fabrics
    text = render_to_string 'email/missing_fabrics_text',
                            layout: false,
                            locals: {
                              missing_fabric_numbers: missing_fabric_numbers,
                              customer: customer
                            }
    html = render_to_string 'email/missing_fabrics_html',
                            layout: false,
                            locals: {
                              missing_fabric_numbers: missing_fabric_numbers,
                              customer: customer
                            }

    # Use RestClient to post to mailgun (use maingun_rails gem instead?)
    post_to = "https://api:#{ENV['MAILGUN_API_KEY']}@api.mailgun.net/v3/#{ENV['MAILGUN_DOMAIN']}/messages"
    post_options = {
      from: "#{ENV['EMAIL_FROM']} <#{ENV['MAILGUN_DOMAIN_EMAIL_ADDRESS']}>",
      to: "#{ENV['EMAIL_TO']}",
      cc: "#{current_user.email}",
      subject: ENV['EMAIL_SUBJECT'],
      html: html.to_str,
      text: text.to_str
    }

    begin
      RestClient.post post_to, post_options
    flash[:notice] = 'Missing fabrics email has been sent'
    rescue => e
      puts "post_to: #{post_to}"
      puts "post_options: #{post_options}"
      puts "REST CLient Error Response: \n#{e.response.body}"
      flash[:error] = 'An error  preventing the missing fabrics email from being sent.'

    end

    redirect_to root_path
  end

  # ---------------------- Scaffolding ----------------------
  # GET /fabrics_racks
  # GET /fabrics_racks.json
  def index
    # Request for different id:
    if params[:id]
      set_fabrics_rack
      show
      render 'show'
    else
      update_customers

      @fabrics_racks = FabricsRack.all
      params.permit(:id)
    end
  end

  # GET /fabrics_racks/1
  # GET /fabrics_racks/1.json
  def show
    update_fabrics
    @fabrics = @fabrics_rack.fabrics.paginate(page: params[:page])
    @fabric = Fabric.new
  end

  # GET /fabrics_racks/new
  def new
    @fabrics_rack = FabricsRack.new
  end

  # GET /fabrics_racks/1/edit
  def edit
  end

  def search
    @customers = Customer.where zip: params[:zip]
  end

  # POST /fabrics_racks
  # POST /fabrics_racks.json
  def create
    @fabrics_rack = FabricsRack.new(fabrics_rack_params)

    respond_to do |format|
      if @fabrics_rack.save
        format.html do
          redirect_to @fabrics_rack,
                      notice: 'On rack was successfully created.'
        end
        format.json { render :show, status: :created, location: @fabrics_rack }
      else
        format.html { render :new }
        format.json do
          render json: @fabrics_rack.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /fabrics_racks/1
  # PATCH/PUT /fabrics_racks/1.json
  def update
    respond_to do |format|
      if @fabrics_rack.update(fabrics_rack_params)
        format.html do
          redirect_to @fabrics_rack,
                      notice: 'On rack was successfully updated.'
        end
        format.json do
          render :show, status: :ok, location: @fabrics_rack
        end
      else
        format.html { render :edit }
        format.json do
          render json: @fabrics_rack.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /fabrics_racks/1
  # DELETE /fabrics_racks/1.json
  def destroy
    @fabrics_rack.destroy
    respond_to do |format|
      format.html do
        redirect_to fabrics_racks_url,
                    notice: 'On rack was successfully destroyed.'
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_fabrics_rack
    @fabrics_rack = FabricsRack.find(params[:id])
  end

  # Never trust parameters from the scary internet,
  #  only allow the white list through.
  def fabrics_rack_params
    params.require(:fabrics_rack).permit(:user_id, :customer_id, :fabric_id)
  end

  def update_customers
    # Update Customers list from Google Sheets
    url = ENV['CUSTOMERS_URL']
    import_customers(url)
  end
  
  #GET /fabrics_racks/data_import  
  def update_fabrics
    # Update Fabrics list from Google Sheets
    if @fabrics_rack.customer
      Fabric.import @fabrics_rack.customer
    else
      flash[:warning] = 'Warning: Customer not found'
    end
  end

end
