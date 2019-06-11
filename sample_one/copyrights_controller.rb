class CopyrightsController < ApplicationController
  before_action :set_copyright, only: [:show, :edit, :update, :destroy]
  before_action :set_organization

  # GET /copyrights
  def index
    @copyrights = Copyright.all
  end

  # GET /copyrights/1
  def show
  end

  # GET /copyrights/new
  def new
    @copyright = Copyright.new
    @url = organization_copyrights_url(@organization.id)
  end

  # GET /copyrights/1/edit
  def edit
    @url = organization_copyright_url(@organization.id, @copyright.id)
    @ids = @organization.marketplace_items.map(&:id)
    @next = Transaction.where("marketplace_item_id IN (?) AND in_progress = ? AND is_approved = ? AND id > ?", @ids, false, false, @copyright.id).order('id asc').limit(1).first
    @prev = Transaction.where("marketplace_item_id IN (?) AND in_progress = ? AND is_approved = ? AND id < ?", @ids, false, false, @copyright.id).order('id desc').limit(1).first
    @next_url = edit_organization_copyright_path(@organization.id, @next.id) if @next
    @prev_url = edit_organization_copyright_path(@organization.id, @prev.id) if @prev
  end

  # POST /copyrights
  def create
    @copyright = Copyright.new(copyright_params)
    @copyright.owner = @organization

    if @copyright.save
      # Composition
      composition = Composition.new(composition_params)
      composition.copyright = @copyright
      composition.save!

      # Attachments
      # attachment_params[:keys].each do |key|
      #   Attachment.create!(copyright: @copyright, key: key)
      # end

      # Sound Recording
      sound_recording_match_params[:person_ids].each do |id|
        SoundRecordingMatch.create!(person_id: id, copyright: @copyright)
      end

      # Composition
      composition_match_params[:person_ids].each do |id|
        CompositionMatch.create!(person_id: id, copyright: @copyright)
      end

      # Transaction
      Transaction.create!(copyright: @copyright)

      redirect_to organization_path(@organization), notice: 'Copyright was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /copyrights/1
  def update
    # Find new copyright, or create new one.
    # Associate copyright and update match from previous copyright
    # Force new name

    if @copyright.update(copyright_params.except(:default))
      redirect_to organization_path(@organization), notice: 'Copyright was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /copyrights/1
  def destroy
    @copyright.destroy
    redirect_to copyrights_url, notice: 'Copyright was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_copyright
      @copyright = Copyright.find(params[:id])
    end

    def set_organization
      @organization = Organization.find(params[:organization_id])
    end

    # Only allow a trusted parameter "white list" through.
    def copyright_params
      params.require(:copyright).permit(:title, :owns_sound_recording, :year, :genre, :country_id, :language, :is_explicit, :is_cover, :existing, :main_artist_id)
    end

    def composition_params
      params.require(:composition).permit(:is_owner, :is_filed, :existing, :should_file, :representative_id)
    end

    def attachment_params
      params.require(:attachment).permit(:keys => [])
    end

    def sound_recording_match_params
      params.require(:sound_recording_match).permit(:person_ids => [])
    end

    def composition_match_params
      params.require(:composition_match).permit(:person_ids => [])
    end
end
