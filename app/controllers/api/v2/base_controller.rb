class Api::V2::BaseController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :configure_permitted_parameters
  skip_before_action :check_for_notifications

  def authenticate_api!
    unless ieducar_api.authenticate!(params[:token])
      render json: { errors: "Token inválido" }, status: 401
    end
  end

  def ieducar_api
    @ieducar_api ||= IeducarApiConfiguration.current
  end

  def set_thread_origin_type
    Thread.current[:origin_type] = OriginTypes::API_V2
    begin
        yield
    ensure
        Thread.current[:origin_type] = nil
    end
  end
end
