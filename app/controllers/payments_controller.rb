# coding: utf-8
class PaymentsController < ApplicationController
  before_filter :authenticate_terminal

  def limits
    provider = Provider.find_by_keyword params[:provider]

    render :json => provider.limits.actual.
                      by_terminal(@terminal).
                      by_payment_type(params[:payment_type]).
                      as_json(:only => [:min, :max], :methods => [:weight])
  end

  def create
    provider = Provider.find_by_keyword params[:provider]

    # TODO: Update terminal part and remove the compatibility hack
    params[:payment][:session_id] = params[:payment].delete(:foreign_id) if params[:payment][:session_id].blank?

    if provider.blank?
      Payment.plog :info, :web, "Provider #{params[:provider]} not found", 
        :session_id  => params[:payment][:session_id],
        :terminal_id => @terminal.id

      render :text => nil, :status => 404
      return
    end

    payment  = Payment.where(
      :terminal_id => @terminal.id,
      :session_id  => params[:payment][:session_id]
    ).first

    if payment.blank?
      payment = Payment.build! @terminal, provider, params[:payment]
      payment.plog :info, :transport, "Created"

      payment.plog :info, :transport, "Checked" do
        payment.check!
      end
    else
      payment.plog :warn, :transport, "Existing payment found, checking skipped"
    end

    render :json => {
      :id               => payment.id,
      :state            => payment.state,
      :requires_print   => provider.requires_print,
      :limits           => Limit.for(payment, false).as_json(
                              :only => [:min, :max], :methods => [:weight]
                           ),
      :commissions      => Commission.for(payment, false).as_json(
                              :only => [:min, :max, :percent_fee, :static_fee],
                              :methods => [:weight]
                           ),
      :receipt_template => ProviderReceiptTemplate.for(payment).compile(payment)
    }
  end
  
  def pay
    payment = @terminal.payments.find(params[:id])

    unless payment.queue?
      payment.plog :info, :transport, "Sent to queue" do
        payment.enqueue!(params[:payment])
      end
    end

    render :text => nil, :status => 200
  end
end
