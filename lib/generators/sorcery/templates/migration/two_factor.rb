class SorceryTwoFactor < ActiveRecord::Migration
  def self.up
    add_column :<%= model_class_name.tableize %>, :two_factor_secret, :string, :default => nil

    add_index :<%= model_class_name.tableize %>, :two_factor_secret
  end

  def self.down
    remove_index :<%= model_class_name.tableize %>, :two_factor_secret

    remove_column :<%= model_class_name.tableize %>, :two_factor_secret
  end
end
