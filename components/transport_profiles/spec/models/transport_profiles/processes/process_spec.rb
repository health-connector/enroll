require "rails_helper"

module TransportProfiles
  RSpec.describe Processes::Process, "encountering an error in a step during its execution" do
    let(:step_run_error) { StandardError.new("step error!") }
    let(:gateway) { double }
    let(:description) { "My Process Description" }
    let(:step) { instance_double(Steps::Step) }
    let(:process_context) { double }

    subject { Processes::Process.new(description, gateway) }

    before :each do
      subject.add_step(step)
      allow(step).to receive(:execute).with(process_context).and_raise(step_run_error)
      allow(process_context).to receive(:execute_cleanup)
    end

    it "runs the cleanup logic" do
      expect(process_context).to receive(:execute_cleanup)
      subject.execute(process_context) rescue nil
    end

    it "re-raises the original error" do
      expect { subject.execute(process_context) }.to raise_error(step_run_error)
    end
  end
end