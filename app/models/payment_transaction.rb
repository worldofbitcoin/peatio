class PaymentTransaction < ActiveRecord::Base
  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  STATE = [:unconfirm, :confirming, :confirmed]
  enumerize :aasm_state, in: STATE, scope: true

  validates_uniqueness_of :txid
  belongs_to :deposit, foreign_key: 'txid', primary_key: 'txid'
  belongs_to :payment_address, foreign_key: 'address', primary_key: 'address'
  has_one :account, through: :payment_address
  has_one :member, through: :account

  aasm :whiny_transitions => false do
    state :unconfirm, initial: true
    state :confirming, after_commit: :deposit_accept
    state :confirmed, after_commit: :deposit_accept

    event :check do |e|
      before :refresh_confirmations

      transitions :from => [:unconfirm], :to => :confirming, :guard => :green_address?
      transitions :from => [:unconfirm, :confirming], :to => :confirming, :guard => :min_confirm?
      transitions :from => [:unconfirm, :confirming, :confirmed], :to => :confirmed, :guard => :max_confirm?
    end
  end

  def min_confirm?
    count = deposit.account.deposits.with_aasm_state(:unconfirm, :confirming).count
    if count > 1
      deposit.safe_confirm?(confirmations)
    else
      deposit.min_confirm?(confirmations)
    end
  end

  def max_confirm?
    deposit.max_confirm?(confirmations)
  end

  def green_address?
    if currency == 'btc'
      known_tx?(txid) rescue false
    end
  end

  def refresh_confirmations
    raw = CoinRPC[deposit.currency].gettransaction(txid)
    self.confirmations = raw[:confirmations]
    save!
  end

  def deposit_accept
    if deposit.may_accept?
      deposit.accept! 
    end
  end

  def known_tx?(txid)
    resp = RestClient.post "https://api.bifubao.com/v00002/tx/innercheck", _time_: Time.now.to_i, tx_hash: txid
    resp = JSON.parse(resp)
    !!resp['result']
  end
end
