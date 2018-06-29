require 'ddtrace/ext/net'
require 'ddtrace/ext/distributed'
require 'ddtrace/propagation/http_propagator'

module Datadog
  module Contrib
    module RestClient
      # RestClient RequestPatch
      module RequestPatch
        REQUEST_TRACE_NAME = 'rest_client.request'.freeze

        def self.included(base)
          if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.0.0')
            base.class_eval do
              alias_method :execute_without_datadog, :execute
              remove_method :execute
              include InstanceMethods
            end
          else
            base.send(:prepend, InstanceMethods)
          end
        end

        # Compatibility shim for Rubies not supporting `.prepend`
        module InstanceMethodsCompatibility
          def execute(&block)
            execute_without_datadog(&block)
          end
        end

        # InstanceMethods - implementing instrumentation
        module InstanceMethods
          include InstanceMethodsCompatibility unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.0.0')

          def execute(&block)
            return super(&block) unless datadog_tracer.enabled

            datadog_trace_request do |span|
              if datadog_configuration[:distributed_tracing]
                Datadog::HTTPPropagator.inject!(span.context, processed_headers)
              end

              super(&block)
            end
          end

          def datadog_tag_request(span)
            uri = URI.parse(url)
            span.resource = method.to_s.upcase
            span.set_tag(Ext::HTTP::URL, uri.path)
            span.set_tag(Ext::HTTP::METHOD, method.to_s.upcase)
            span.set_tag(Ext::NET::TARGET_HOST, uri.host)
            span.set_tag(Ext::NET::TARGET_PORT, uri.port)
          end

          def datadog_configure_span_from_pin(span)
            span.service = datadog_pin.service
            span.name = datadog_pin.name if datadog_pin.name
            span.span_type = datadog_pin.app_type

            datadog_pin.tags && datadog_pin.tags.each do |k, v|
              span.set_tag(k, v)
            end
          end

          def datadog_trace_request
            span = datadog_tracer.trace(REQUEST_TRACE_NAME)
            datadog_tag_request(span)

            response = yield span

            datadog_configure_span_from_pin(span)

            span.set_tag(Ext::HTTP::STATUS_CODE, response.code)
            response
          rescue ::RestClient::ExceptionWithResponse => e
            span.set_error(e) if Ext::HTTP::ERROR_RANGE.cover?(e.http_code)
            span.set_tag(Ext::HTTP::STATUS_CODE, e.http_code)

            raise e
            # rubocop:disable Lint/RescueException
          rescue Exception => e
            # rubocop:enable Lint/RescueException
            span.set_error(e)

            raise e
          ensure
            span.finish
          end

          def datadog_pin
            @datadog_pin ||= begin
              service = datadog_configuration[:service_name]
              tracer = datadog_configuration[:tracer]

              Datadog::Pin.new(
                service,
                app: Patcher::NAME,
                app_type: Datadog::Ext::AppTypes::WEB,
                tracer: tracer
              )
            end
          end

          def datadog_tracer
            datadog_configuration[:tracer]
          end

          def datadog_configuration
            Datadog.configuration[:rest_client]
          end
        end
      end
    end
  end
end