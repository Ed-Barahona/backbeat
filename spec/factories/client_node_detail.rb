FactoryGirl.define do
  factory :client_node_detail, class: Backbeat::ClientNodeDetail do
   metadata {}
   data({"could"=>"be", "any"=>"thing"})
  end
end