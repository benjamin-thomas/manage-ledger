module Memoize
  def self.accounts
    @accounts ||= begin Account.classify end
  end
end

class Account < Sequel::Model
  many_to_one :parent, class: self, key: :parent_guid

  def root?
    account_type == 'ROOT'
  end

  def self.with_parent
    exclude(parent_guid: nil)
  end

  def parents
    parents = []
    p = parent
    until p.nil? || p.root?
      parents << p
      p = p.parent
    end
    parents
  end

  def category
    cs = parents.map(&:name).reverse
    cs << name
    cs.join(':')
  end

  def self.classify
    with_parent.each_with_object({}) do |a, accounts|
      accounts[a.guid] = a.category
    end
  end
end

class Transaction < Sequel::Model
  one_to_many :operations, key: :tx_guid

  def to_ledger
    d = Date.parse(post_date)
    lines = ["#{d} #{description}"]

    operations.each do |o|
      lines << o.for_ledger
    end
    lines
  end
end

class Operation < Sequel::Model(DB.from(:splits))
  def ofx_id
    Slot.find(obj_guid: guid, name: 'online_id')&.string_val
  end

  def for_ledger
    amount = BigDecimal.new(value_num) / BigDecimal.new(value_denom)
    str_amount = format('%.2f', amount)
    cat = Memoize.accounts.fetch(account_guid)
    line = "    #{cat}  #{str_amount}"
    memo_line = "; memo: #{memo}" unless memo.empty?
    ofx_line = "; ofx_id: #{ofx_id}" if ofx_id
    line + '  ' + [memo_line, ofx_line].join
  end
end

class Slot < Sequel::Model
end
