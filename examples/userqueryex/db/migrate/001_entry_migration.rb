# $Id$
class EntryMigration < ActiveRecord::Migration
  def self.up
    create_table "entries", :force => true do |t|
      t.column "name",     :string
      t.column "date",     :datetime
      t.column "memo",     :text
      t.column "amount",   :integer # Currency::Money
      t.column "approved",   :boolean
    end

    # Add some reasonable entries:
    Entry.new(:name => 'Kurt',
              :date => '2006-08-28 18:39:00',
              :memo => 'We like CHEESE!
Send more wine.',
              :amount => '2134.33',
              :approved => true).save

    Entry.new(:name => 'Bruce',
              :date => '2006-10-28 18:39:00',
              :memo => 'Rails for Tails.',
              :amount => '112.00',
              :approved => false).save

    Entry.new(:name => 'Robin',
              :date => '2005-01-26 19:46:00',
              :memo => 'Some memo with a "%" in it.',
              :amount => '13.98',
              :approved => false).save
  end

  def self.down
    drop_table "entries"
  end
end
