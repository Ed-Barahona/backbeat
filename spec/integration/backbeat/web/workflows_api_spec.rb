require 'spec_helper'
require 'helper/request_helper'

describe Backbeat::Web::WorkflowsApi, :api_test do
  include RequestHelper

  let(:user) { FactoryGirl.create(:user) }
  let(:workflow) { FactoryGirl.create(:workflow_with_node, user: user) }
  let(:node) { workflow.children.first }

  before do
    allow(Backbeat::Client).to receive(:make_decision)
    WebMock.stub_request(:post, "http://backbeat-client:9000/notifications")
  end

  context "POST /workflows" do
    it "returns 201 and creates a new workflow when all parameters present" do
      workflow_data = {
        workflow_type: "WFType",
        subject: { subject_klass: "PaymentTerm", subject_id: 100 },
        decider: "PaymentDecider"
      }
      response = post 'v2/workflows', workflow_data

      expect(response.status).to eq(201)

      first_response = JSON.parse(response.body)
      wf_in_db = Backbeat::Workflow.find(first_response['id'])

      expect(wf_in_db).to_not be_nil
      expect(wf_in_db.subject).to eq({ "subject_klass" => "PaymentTerm", "subject_id" => "100" })

      response = post 'v2/workflows', workflow_data
      expect(first_response['id']).to eq(JSON.parse(response.body)['id'])
    end
  end

  context "POST /workflows/:id/signal/:name" do
    let(:signal_params) {{
      options: {
        client_data: { data: '123' },
        metadata: { metadata: '456'}
      }
    }}

    it "calls schedule next node after creating the signal" do
      expect(Backbeat::Server).to receive(:fire_event).with(Backbeat::Events::ScheduleNextNode, workflow)
      response = post "v2/workflows/#{workflow.id}/signal/new_signal", signal_params
    end

    it "creates a signal on the workflow" do
      response = post "v2/workflows/#{workflow.id}/signal/new_signal", signal_params

      expect(response.status).to eq(201)
      expect(workflow.children.count).to eq(2)
    end

    it "adds node nad calls schedule next node on the workflow" do
      response = post "v2/workflows/#{workflow.id}/signal/test", signal_params

      expect(workflow.nodes.last.client_data).to eq({ 'data' => '123' })
      expect(workflow.nodes.last.client_metadata).to eq({ 'metadata' => '456' })
    end

    it "returns a 400 response if the workflow is complete" do
      workflow.complete!
      expect(workflow.children.count).to eq(1)

      response = post "v2/workflows/#{workflow.id}/signal/new_signal", signal_params

      expect(response.status).to eq(400)
      expect(workflow.children.count).to eq(1)
    end
  end

  context "GET /workflows/search" do
    let!(:wf_1) { FactoryGirl.create(
      :workflow,
      user: user,
      subject: { class: "FooModel", id: 1 },
      name: "import"
    )}

    let!(:wf_2) { FactoryGirl.create(
      :workflow,
      user: user,
      subject: { class: "BarModel", id: 2 },
      name: "import"
    )}

    let!(:wf_3) { FactoryGirl.create(
      :workflow,
      user: user,
      subject: { class: "FooModel", id: 3 },
      name: "export"
    )}

    it "returns all workflows with matching name" do
      response = get "v2/workflows/search?name=import"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(2)
      expect(json_response.map{ |wf| wf["name"] }).to_not include("bar")
    end

    it "returns all workflows partially matching on subject" do
      response = get "v2/workflows/search?subject=FooModel"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(2)
      expect(json_response.first["id"]).to eq(wf_1.id)
      expect(json_response.last["id"]).to eq(wf_3.id)
    end

    it "returns all workflows matching name and partial subject" do
      response = get "v2/workflows/search?subject=FooModel&name=import"
      json_response = JSON.parse(response.body)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns all workflows with nodes in server_status matching queried status" do
      errored_node = FactoryGirl.create(
        :node,
        workflow: wf_1,
        user: user,
        current_server_status: :errored
      )
      response = get "v2/workflows/search?current_status=errored"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(1)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns all workflows with nodes in client_status matching queried status" do
      errored_node = FactoryGirl.create(
        :node,
        workflow: wf_1,
        user: user,
        current_client_status: :errored
      )
      response = get "v2/workflows/search?current_status=errored"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(1)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns workflows filtered by all params" do
      errored_node = FactoryGirl.create(
        :node,
        workflow: wf_1,
        user: user,
        current_client_status: :pending
      )
      response = get "v2/workflows/search?current_status=pending&name=import&subject=FooModel"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(1)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns workflows with nodes that errored in a certain timeframe" do
      errored_node = FactoryGirl.create(
        :node,
        workflow: wf_1,
        user: user,
        current_client_status: :pending
      )
      errored_node.status_changes.create({
        from_status: :pending,
        to_status: :errored,
        status_type: :current_server_status,
        created_at: 2.hours.ago.utc
      })

      status_start = 3.hours.ago.utc.iso8601
      status_end = 1.hours.ago.utc.iso8601
      query_params = "status_start=#{status_start}&status_end=#{status_end}&past_status=errored"
      response = get "v2/workflows/search?#{query_params}"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(1)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns workflows with errors that are now complete" do
      errored_node = FactoryGirl.create(
        :node,
        workflow: wf_1,
        user: user,
        current_client_status: :complete
      )
      errored_node.status_changes.create({
        from_status: :sent_to_client,
        to_status: :errored,
        status_type: :current_client_status,
        created_at: 1.hours.ago.utc
      })

      response = get "v2/workflows/search?current_status=complete&past_status=errored"
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq(1)
      expect(json_response.first["id"]).to eq(wf_1.id)
    end

    it "returns nothing if no params are provided" do
      response = get "v2/workflows/search"
      expect(response.body).to eq("[]")
    end
  end

  context "GET /workflows/:id" do
    it "returns a workflow given an id" do
      response = get "v2/workflows/#{workflow.id}"
      expect(response.status).to eq(200)
      json_response = JSON.parse(response.body)

      expect(json_response["id"]).to eq(workflow.id)
    end
  end

  context "GET /workflows/:id/children" do
    it "returns the workflows immediate" do
      second_node = FactoryGirl.create(
        :node,
        workflow: workflow,
        parent: workflow,
        user: user
      )

      response = get "v2/workflows/#{workflow.id}/children"
      expect(response.status).to eq(200)

      json_response = JSON.parse(response.body)
      children = workflow.children

      expect(json_response.first["id"]).to eq(children.first.id)
      expect(json_response.second["currentServerStatus"]).to eq(children.second.current_server_status)
      expect(json_response.count).to eq(2)
    end
  end

  context "GET /workflows/:id/nodes" do
    before do
      second_node = FactoryGirl.create(
        :node,
        workflow: workflow,
        parent: workflow,
        user: user
      )
      @third_node = FactoryGirl.create(
        :node,
        workflow: workflow,
        parent: second_node,
        user: user,
        current_server_status: :complete
      )
      @third_node.client_node_detail.update_attributes!(metadata: {"version"=>"v2", "workflow_type_on_v2"=>true})
    end

    it "returns the workflows nodes in ClientNodeSerializer" do
      response = get "v2/workflows/#{workflow.id}/nodes"
      expect(response.status).to eq(200)

      json_response = JSON.parse(response.body)
      nodes = workflow.nodes

      expect(json_response.first["id"]).to eq(nodes.first.id)
      expect(json_response.second["id"]).to eq(nodes.second.id)
      expect(json_response.third["id"]).to eq(nodes.third.id)
      expect(json_response.third["currentServerStatus"]).to eq(nodes.third.current_server_status)
      expect(json_response.third["metadata"]).to eq({"version"=>"v2", "workflowTypeOnV2"=>true})
      expect(json_response.count).to eq(3)
    end

    it "returns nodes limited by query" do
      response = get "v2/workflows/#{workflow.id}/nodes?currentServerStatus=complete"
      expect(response.status).to eq(200)

      json_response = JSON.parse(response.body)
      expect(json_response.first["id"]).to eq(@third_node.id)
      expect(json_response.count).to eq(1)
    end
  end

  context "GET /workflows/:id/tree" do
    it "returns the workflow tree as a hash" do
      response = get "v2/workflows/#{workflow.id}/tree"
      body = JSON.parse(response.body)

      expect(body["id"]).to eq(workflow.id.to_s)
    end
  end

  context "GET /workflows/:id/tree/print" do
    it "returns the workflow tree as a string" do
      response = get "v2/workflows/#{workflow.id}/tree/print"
      body = JSON.parse(response.body)

      expect(body["print"]).to include(workflow.name)
    end
  end

  context "PUT /workflows/:id/complete" do
    it "marks the workflow as complete" do
      response = put "v2/workflows/#{workflow.id}/complete"

      expect(response.status).to eq(200)
      expect(workflow.reload.complete?).to eq(true)
    end
  end

  context "PUT /workflows/:id/pause" do
    it "marks the workflow as paused" do
      response = put "v2/workflows/#{workflow.id}/pause"

      expect(response.status).to eq(200)
      expect(workflow.reload.paused?).to eq(true)
    end
  end

  context "PUT /workflows/:id/resume" do
    it "resumes the workflow" do
      workflow.pause!

      response = put "v2/workflows/#{workflow.id}/resume"

      expect(response.status).to eq(200)
      expect(workflow.reload.paused?).to eq(false)
    end
  end

  context "GET /workflows" do
    let(:query) {{
      decider: workflow.decider,
      subject: workflow.subject.to_json,
      workflow_type: workflow.name
    }}

    it "returns the first workflow matching the decider and subject" do
      workflow.update_attributes(migrated: true)

      response = get "v2/workflows", query
      body = JSON.parse(response.body)

      expect(response.status).to eq(200)
      expect(body["id"]).to eq(workflow.id)
    end

    [:decider, :subject, :workflow_type].each do |param|
      it "returns 404 if a workflow is not found by #{param}" do
        workflow.update_attributes(migrated: true)

        response = get "v2/workflows", query.merge(param => "Foo")

        expect(response.status).to eq(404)
      end
    end

    it "returns 404 if the workflow is not fully migrated" do
      workflow.update_attributes(migrated: false)

      response = get "v2/workflows", query

      expect(response.status).to eq(404)
    end
  end
end
