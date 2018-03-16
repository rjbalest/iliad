class CreatePortfolios < ActiveRecord::Migration[5.1]
  def change
    create_table :portfolios do |t|
      t.string :name
      t.string :label
      t.string :description
      t.references :user

      t.datetime :transactions_start
      t.datetime :transactions_end
      t.datetime :transactions_asof
      t.datetime :positions_asof
      t.decimal :cash

      t.timestamps
    end
  end
end
