class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :store_user_location!, if: :storable_location?
  before_action :set_raven_context

  def after_sign_in_path_for(resource)
    path = if resource.class == Agent
             current_agent.complete? ? authenticated_agent_root_path : new_agents_full_subscription_path
           elsif resource.class == User
             stored_location_for(resource) || authenticated_user_root_path
           end
    path
  end

  def respond_modal_with(*args, &blk)
    options = args.extract_options!
    options[:responder] = ModalResponder
    respond_with *args, options, &blk
  end

  def respond_right_bar_with(*args, &blk)
    options = args.extract_options!
    options[:responder] = RightBarResponder
    respond_with *args, options, &blk
  end

  protected

  def set_raven_context
    Raven.user_context(sentry_user)
    Raven.extra_context(params: params.to_unsafe_h, url: request.url)
  end

  def sentry_user
    user = current_agent || current_user
    {
      id: user&.id,
      role: user&.class&.name || 'Guest',
      email: user&.email,
    }.compact
  end

  def authenticate_inviter!
    authenticate_agent!(force: true)
  end

  def configure_permitted_parameters
    if resource_class == Agent
      devise_parameter_sanitizer.permit(:invite, keys: [:email, :role, :service_id, :organisation_id])
      devise_parameter_sanitizer.permit(:accept_invitation, keys: [:first_name, :last_name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :service_id])
    elsif resource_class == User
      devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :email, :password])
      devise_parameter_sanitizer.permit(:invite, keys: [:email, :first_name, :last_name, :address, :phone_number, :birth_date])
    end
  end

  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr? && request.fullpath != root_path
  end

  def store_user_location!
    # :user is the scope we are authenticating
    store_location_for(:user, request.fullpath)
  end
end
