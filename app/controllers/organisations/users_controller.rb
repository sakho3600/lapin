class Organisations::UsersController < DashboardAuthController
  respond_to :html, :json

  before_action :set_organisation, only: [:new, :create]
  before_action :set_user, except: [:index, :new, :create, :link_to_organisation]

  def index
    page = 1
    @users = policy_scope(User).where(id: current_organisation.users.pluck(:id)).order(Arel.sql('LOWER(last_name)'))
    if params[:page]
      page = params[:page]
    elsif params[:to_user]
      index = @users.pluck(:id).index(params[:to_user].to_i)
      page = index / Kaminari.config.default_per_page + 1
    end
    @users = @users.page(page)
    filter_users if params[:user] && params[:user][:search]
  end

  def new
    @user = User.new
    @user.organisation_ids = [current_organisation.id]
    authorize(@user)
  end

  def create
    @user = User.new(user_params)
    @user.organisation_ids = [current_organisation.id]
    @user.invited_by = current_agent
    @user.created_or_updated_by_agent = true
    authorize(@user)
    if (@user_to_compare = User.find_by(email: @user.email))
      @user_not_in_organisation = @user_to_compare.organisation_ids.exclude?(current_organisation.id)
      render :compare
    else
      @organisation = current_organisation
      @user.skip_confirmation!
      flash[:notice] = "L'usager a été créé." if @user.save
      redirect_to organisation_users_path(@organisation, to_user: @user.id)
    end
  end

  def link_to_organisation
    @user = User.find(params.require(:id))
    @user.organisations << current_organisation if @user.organisation_ids.exclude?(current_organisation.id)
    authorize(@user)
    flash[:notice] = "L'usager a été associé à l'organisation #{current_organisation.name}"
    redirect_to edit_organisation_user_path(current_organisation.id, @user.id)
  end

  def edit
    authorize(@user)
  end

  def update
    authorize(@user)
    @user.created_or_updated_by_agent = true
    @user.skip_reconfirmation! if @user.encrypted_password.blank?
    flash[:notice] = "L'usager a été modifié." if @user.update(user_params)
    respond_right_bar_with @user, location: organisation_users_path(current_organisation, to_user: @user.id)
  end

  def invite
    authorize(@user)
    @user.deliver_invitation
    flash[:notice] = "L'usager a été invité."
    respond_right_bar_with @user, location: organisation_users_path(current_organisation, to_user: @user.id)
  end

  def destroy
    authorize(@user)
    flash[:notice] = "L'usager a été supprimé." if @user.organisations.delete(current_organisation)
    redirect_to organisation_users_path(current_organisation)
  end

  private

  def filter_users
    @users = @users.search_by_name(params[:user][:search])
    respond_to do |format|
      format.js { render partial: 'search-results' }
    end
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :birth_date, :address, :caisse_affiliation, :affiliation_number, :family_situation, :number_of_children, :logement)
  end

  def set_user
    @user = policy_scope(User).find(params[:id])
  end
end
