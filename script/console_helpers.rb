def establish_readonly_connection
  ActiveRecord::Base.class_eval do
    def readonly? true end
  end
  IRB.CurrentContext.irb_name = "[PROD-RO]"
  readonly_db_config = YAML::load_file("#{File.dirname(__FILE__)}/config/database.yml")["production_readonly"]
  if readonly_db_config
    ActiveRecord::Base.establish_connection(readonly_db_config)
    ActiveRecord::Base.connection.reset!
  else
    raise "No production readonly database defined in database.yml"
  end
end

def establish_write_connection
  ActiveRecord::Base.class_eval do
    def readonly? false end
  end
  IRB.CurrentContext.irb_name = "irb"
  default_db_config = YAML::load_file("#{File.dirname(__FILE__)}/config/database.yml")[Backbeat.env]
  ActiveRecord::Base.establish_connection(default_db_config)
  ActiveRecord::Base.connection.reset!
end

# prints running workers counted by queue and host
def sidekiq_job_count
  Sidekiq::Workers.new.group_by do |conn|
    conn.first.split(":")[0] + " " + conn.third["queue"]
  end.each_pair { |name, conns| puts "#{name} - #{conns.count}" }
  nil
end

module Backbeat
  module ConsoleHelpers
    EVENT_MAP = {
      start: Events::StartNode,
      retry: Events::RetryNode,
      deactivate: Events::DeactivatePreviousNodes,
      reset: Events::ResetNode
    }

    EVENT_MAP.each do |method_name, event|
      define_method(method_name) do
        event.call(self)
      end
    end
  end

  class Node
    include ConsoleHelpers
  end
end
