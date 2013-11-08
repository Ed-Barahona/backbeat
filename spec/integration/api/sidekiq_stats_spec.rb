require 'spec_helper'

describe Api::SidekiqStats do
  include Rack::Test::Methods

  def app
    FullRackApp
  end

  context '/sidekiq_stats' do
    it 'catches the request, returns 200 and queue stats' do
      stats = double(Sidekiq::Stats, processed: 23, failed: 42, enqueued: 666, scheduled_size: 0, retry_size: 123, queues: {"queue1" => 0, "queue2" => 0} )
      q1 = double(Sidekiq::Queue, latency: 10)
      q2 = double(Sidekiq::Queue, latency: 20)
      Sidekiq::Queue.should_receive(:new).with("queue1").and_return(q1)
      Sidekiq::Queue.should_receive(:new).with("queue2").and_return(q2)
      Sidekiq::Stats.stub(new: stats)

      response = get '/sidekiq_stats'
      response.status.should == 200

      JSON.parse(response.body) == {
        "latency" => { "queue1" => 10, "queue2" => 20 },
        "processed" => 23,
        "failed"    => 42,
        "enqueued"  => 666,
        "scheduled_size" => 0,
        "retry_size" => 123
      }
    end
  end
end