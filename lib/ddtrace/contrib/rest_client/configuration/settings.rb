require 'ddtrace/contrib/configuration/settings'
require 'ddtrace/contrib/active_record/utils'

module Datadog
  module Contrib
    module RestClient
      module Configuration
        # Unique settings for RestClient
        class Settings < Contrib::Configuration::Settings
          NAME = 'rest_client'.freeze
          option :service_name, default: NAME, depends_on: [:tracer] do |value|
            tracer.set_service_info(value, NAME, Ext::AppTypes::DB)
          end

          option :distributed_tracing, default: false
        end
      end
    end
  end
end
