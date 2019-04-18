class BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def render_serialized(status = 200)
    render json: yield, status: status
  rescue ArgumentError => exception
    render_error(exception.message, 400)
  end

  def render_error(error_message, status = 422)
    render json: { error: error_message }, status: status
  end

  def record_not_found
    render_error I18n.t(:resource_not_found), 404
  end

  def invalid_token
    render_error I18n.t(:invalid_token), 401
  end

  def token
    request.headers['X-Token'] || params[:token]
  end

  def authenticate_thermostat
    unless token.present? && @thermostat.household_token == token
      invalid_token and return
    end
  end
end
