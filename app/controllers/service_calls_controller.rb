class ServiceCallsController < ApplicationController

  def show
    @service_call = ServiceCall.find(params[:id])
  end

  def run
    @service_call = ServiceCall.find(params[:service_call_id])
    @service_call.invoke
  end

  def update
    @service_call = ServiceCall.find(params[:id])
    if @service_call.update_attributes(params[:service_call])
      redirect_to service_call_path(@service_call), notice: "Successfully saved the service call."
    else
      redirect_to service_call_path(@service_call), warning: "Could not save service call."
    end
  end

end