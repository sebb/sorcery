class AddTwoFactorToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :two_factor_secret, :string, :default => nil

    add_index :users, :two_factor_secret
  end

  def self.down
    remove_index :users, :two_factor_secret

    remove_column :users, :two_factor_secret
  end
end
