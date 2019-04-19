require 'rails_helper'

RSpec.describe PetitionCountJob, type: :job do
  let(:interval) { 30 }

  before do
    allow(Site).to receive(:signature_count_interval).and_return(interval)
  end

  context "when the invalid signature count check is disabled" do
    before do
      allow(Site).to receive(:disable_invalid_signature_count_check?).and_return(true)
    end

    it "cancels the job" do
      expect(Site).not_to receive(:update_signature_counts)
      described_class.perform_now
    end
  end

  context "when there are no petitions with invalid signature counts" do
    let!(:petition) { FactoryBot.create(:open_petition) }

    it "doesn't enqueue a ResetPetitionSignatureCountJob job" do
      expect {
        described_class.perform_now
      }.not_to have_enqueued_job(ResetPetitionSignatureCountJob)
    end
  end

  context "when there are petitions with invalid signature counts" do
    let(:current_time) { "2019-04-19T12:57:00Z" }

    let!(:petition) do
      FactoryBot.create(:open_petition,
        created_at: 2.days.ago,
        last_signed_at: 60.seconds.ago,
        signature_count: 100,
        creator_attributes: { validated_at: 60.seconds.ago }
      )
    end

    context "and signature count updating is enabled" do
      before do
        Site.enable_signature_counts!
      end

      it "enqueues a ResetPetitionSignatureCountJob job" do
        expect {
          described_class.perform_now(current_time)
        }.to have_enqueued_job(ResetPetitionSignatureCountJob).with(petition, current_time).on_queue("highest_priority")
      end
    end

    context "and signature count updating is disabled" do
      before do
        Site.disable_signature_counts!
      end

      it "enqueues a ResetPetitionSignatureCountJob job" do
        expect {
          described_class.perform_now(current_time)
        }.to have_enqueued_job(ResetPetitionSignatureCountJob).with(petition, current_time).on_queue("highest_priority")
      end
    end
  end
end
