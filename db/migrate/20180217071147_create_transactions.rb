class CreateTransactions < ActiveRecord::Migration[5.1]
  def change
    create_table :transactions do |t|
      t.references :portfolio
      t.references :security
      t.datetime :date
      t.string :action
      t.string :description
      t.decimal :quantity
      t.decimal :price
      t.decimal :fee
      t.decimal :amount

      t.timestamps
    end
  end
end
