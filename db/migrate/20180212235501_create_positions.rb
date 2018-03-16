class CreatePositions < ActiveRecord::Migration[5.1]
  def change
    create_table :positions do |t|
      t.references :portfolio
      t.references :security
      t.decimal :shares
      t.decimal :basis
      t.datetime :asof

      t.timestamps
    end
  end
end
