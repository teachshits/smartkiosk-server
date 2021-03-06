class CardsMkbAcquirer
  class << self
    attr_reader :gateway

    def ensure_running(config)
      if @gateway.nil?
        if !ISO8583::MKB::Logging.started?
          ISO8583::MKB::Logging.start Rails.root.join('log/iso8583_mkb.log')
        end

        @gateway = ISO8583::MKB::SynchronousGateway.new(config)
      end
    end

    def stop
      @gateway.stop unless @gateway.nil?
      @gateway = nil
      ISO8583::MKB::Logging.stop
    end
  end

  class Transaction
    attr_reader :error

    def initialize(payment, config)
      @payment = payment
      @auth = nil
      @config = config
      @transaction = nil
      @error = nil
      @auth = nil
    end

    def id
      @transaction.id
    end

    def transact(&block)
      CardsMkbAcquirer.gateway.transaction do |transaction|
        @transaction = transaction
        begin
          yield self
        ensure
          @transaction = nil
        end
      end
    end

    def authorize
      auth = ISO8583::MKB::Authorization.new(@transaction)
      auth.processing_code = @config[:processing_code]
      auth.merchant_type = @config[:merchant_type]
      auth.acquirer_country = @config[:acquirer_country]
      auth.entry_mode = @config[:entry_mode]
      auth.condition_code = @config[:condition_code]
      auth.acquirer = @config[:acquirer]
      auth.terminal_id = @config[:terminal_id]
      auth.acceptor_id = @config[:acceptor_id]

      auth.track2 = @payment.card_track2

      delimiter = auth.track2.index '='
      auth.pan = auth.track2.slice(0, delimiter)
      auth.expiry = auth.track2.slice(delimiter + 1, 4)

      terminal = "OOOMKB TERM#{@payment.terminal.keyword}"
      city = "Moscow"
      country = "RU"

      auth.acceptor_name = sprintf("%-25s%-13s%-2s", terminal, city, country)

      # TODO: implement currency handling
      auth.amount = (@payment.paid_amount * 100).to_i
      auth.currency = 643

      # TODO: build additional data
      auth.additional = "USRDT, <cm>#{@payment.commission_amount}</cm>, <ses>#{@payment.session_id}</ses>backend data"

      CardsMkbAcquirer.gateway.execute auth

      @auth = auth
      @error = auth.status_description

      auth.success?
    end

    def reverse
      reversal = @auth.reverse
      CardsMkbAcquirer.gateway.execute reversal

      @error = reversal.status_description
      reversal.success?
    end

    def confirm
      true
    end
  end

  def initialize(config)
    @config = config.with_indifferent_access
    CardsMkbAcquirer.ensure_running @config
  end

  def transaction(payment, &block)
    transaction = Transaction.new(payment, @config)
    transaction.transact(&block)
  end
end

