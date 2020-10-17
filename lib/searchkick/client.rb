# frozen_string_literal: true

module Searchkick
  class Client
    attr_reader :aws_credentials

    def initialize(url:, timeout: nil, aws_credentials: nil, **options)
      @aws_credentials = aws_credentials

      if defined?(Typhoeus) && Gem::Version.new(Faraday::VERSION) < Gem::Version.new('0.14.0')
        require 'typhoeus/adapters/faraday'
      end

      @client = Elasticsearch::Client.new({
        url: url,
        transport_options: { request: { timeout: timeout }, headers: { content_type: 'application/json' } },
        retry_on_failure: 2
      }.deep_merge(options)) do |f|
        f.use Searchkick::Middleware
        f.request signer_middleware_key, signer_middleware_aws_params if aws_credentials
      end
    end

    def host
      @host ||= @client.transport.hosts.first
    end

    private

    def signer_middleware_key
      defined?(FaradayMiddleware::AwsSignersV4) ? :aws_signers_v4 : :aws_sigv4
    end

    def signer_middleware_aws_params
      if signer_middleware_key == :aws_sigv4
        { service: 'es', region: 'us-east-1' }.merge(aws_credentials)
      else
        {
          credentials: aws_credentials[:credentials] || Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]),
          service_name: 'es',
          region: aws_credentials[:region] || 'us-east-1'
        }
      end
    end

    def method_missing(method_name, *args, &block)
      @client.send(method_name, *args, &block)
    end

    def respond_to_missing?(method_name, *_args)
      @client.respond_to?(method_name)
    end
  end
end
