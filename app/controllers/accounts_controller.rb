class AccountsController < ApplicationController
  def edit; end

  def update
    dn = params[:name].to_s.squish
    if dn.blank? || dn.length > 60
      flash.now[:alert] = "Choose a display name (up to 60 characters)."
      return render :edit, status: :unprocessable_entity
    end
    current_user.update!(name: dn)
    redirect_to root_path, notice: "Saved."
  end
end
