class RepsController < ApplicationController
  def index
    @reps = Rep.order(:name)
  end

  def show
    @rep = Rep.find(params[:id])
    @year = params.fetch(:year, Date.current.year).to_i
    @statement = @rep.statement(@year)
  rescue ReasonMeThis::Error => e
    @problem = e.message
  end
end
