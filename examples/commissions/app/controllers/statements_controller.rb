class StatementsController < ApplicationController
  def create
    rep = Rep.find(params[:rep_id])
    year = params.fetch(:year, Date.current.year).to_i
    rep.statement!(year)
    redirect_to rep_path(rep, year:), notice: "Saved #{rep.quarter_statements.count} quarters for #{year}, with a receipt."
  rescue ReasonMeThis::Error => e
    redirect_to rep_path(rep, year:), alert: e.message
  end
end
