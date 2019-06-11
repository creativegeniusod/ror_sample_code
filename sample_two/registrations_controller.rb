class RegistrationsController < Devise::RegistrationsController
  before_action :authenticate_user!, :redirect_unless_admin, only: [:new, :create]
  skip_before_action :require_no_authentication

  def update_resource(resource, params)
    resource.update_without_password(params)
  end

  def edit
    @user = User.find(params[:id])
    render :edit
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    if @user.destroy
      flash[:danger] = 'User deleted'
      redirect_to users_path
    end
  end

  private

  # Only allow admins to view registration
  def redirect_unless_admin
    unless current_user.try(:admin?)
      flash[:error] = 'Only admins can do that'
      redirect_to root_path
    end
  end

  # Prevent automatic sign in after sign up
  def sign_up(resource_name, resource)
    true
  end

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def account_update_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
