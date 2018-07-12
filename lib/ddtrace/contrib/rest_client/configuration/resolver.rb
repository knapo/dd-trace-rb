require 'ddtrace/contrib/configuration/resolver'
require 'ddtrace/vendor/active_record/connection_specification'

module Datadog
  module Contrib
    module RestClient
      module Configuration
        # Converts Symbols, Strings, and Hashes to a normalized connection settings Hash.
        class Resolver < Contrib::Configuration::Resolver
          def initialize(configurations = nil)
            @configurations = configurations
          end

          def resolve(uri)
            if uri.respond_to?(:hostname)
              uri.hostname
            else
              :default
            end
          end
        end
      end
    end
  end
end
