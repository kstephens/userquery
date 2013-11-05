require 'currency'
require 'currency/active_record'

class Entry < ActiveRecord::Base
   money :amount
end


