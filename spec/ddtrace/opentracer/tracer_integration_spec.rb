require 'spec_helper'

require 'ddtrace/opentracer'
require 'ddtrace/opentracer/helper'

if Datadog::OpenTracer.supported?
  RSpec.describe Datadog::OpenTracer::Tracer do
    include_context 'OpenTracing helpers'

    subject(:tracer) { described_class.new(writer: FauxWriter.new) }
    let(:datadog_tracer) { tracer.datadog_tracer }
    let(:datadog_spans) { datadog_tracer.writer.spans(:keep) }

    describe 'unscoped trace' do
      context 'for a single span' do
        let(:span) { tracer.start_span(span_name) }
        let(:span_name) { 'operation.foo' }
        before(:each) { span.finish }

        let(:datadog_span) { datadog_spans.first }

        it { expect(datadog_spans).to have(1).items }
        it { expect(datadog_span.name).to eq(span_name) }
        it { expect(datadog_span.finished?).to be(true) }
      end

      context 'for a nested span' do
        let(:child_span) { tracer.start_span('operation.child') }

        context 'when there is an active scope' do
          context 'which is used' do
            before(:each) do
              tracer.start_active_span('operation.parent') do
                tracer.start_span('operation.child').finish
              end
            end

            let(:parent_datadog_span) { datadog_spans.last }
            let(:child_datadog_span) { datadog_spans.first }

            it { expect(datadog_spans).to have(2).items }
            it { expect(parent_datadog_span.name).to eq('operation.parent') }
            it { expect(parent_datadog_span.parent_id).to eq(0) }
            it { expect(parent_datadog_span.finished?).to be true }
            it { expect(child_datadog_span.name).to eq('operation.child') }
            it { expect(child_datadog_span.parent_id).to eq(parent_datadog_span.span_id) }
            it { expect(child_datadog_span.finished?).to be true }
          end

          context 'which is ignored' do
          end
        end

        context 'manually associated with child_of' do
        end
      end
    end

    describe 'scoped trace' do
    end
  end
end
