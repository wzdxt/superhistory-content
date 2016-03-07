class AddHostRulePathRuleRuleExcludedToContents < ActiveRecord::Migration
  def change
    add_column :contents, :host_rule_id, :integer
    add_column :contents, :path_rule_id, :integer
    add_column :contents, :rule_excluded, :boolean, :default => false
  end
end
