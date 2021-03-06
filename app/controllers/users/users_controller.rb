class Users::UsersController < UserAuthController
  def edit
    @user = current_user
    authorize(@user)
  end

  def update
    @user = current_user
    authorize(@user)
    flash[:notice] = "Vos informations ont été mises à jour." if @user.update(user_params)
    redirect_to users_informations_path
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :birth_date, :address, :caisse_affiliation, :affiliation_number, :family_situation, :number_of_children, :logement)
  end
end
