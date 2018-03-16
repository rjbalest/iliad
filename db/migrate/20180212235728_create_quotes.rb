class CreateQuotes < ActiveRecord::Migration[5.1]
  def change
    create_table :quotes do |t|
      t.references :security
      t.string :ticker
      t.date :date
      t.decimal :open
      t.decimal :high
      t.decimal :low
      t.decimal :close
      t.decimal :adjusted_close
      t.integer :volume
      t.decimal :dividend
      t.decimal :split_coefficient

      t.timestamps
    end
  end
end
