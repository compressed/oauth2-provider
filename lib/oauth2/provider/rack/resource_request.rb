require 'rack/auth/abstract/request'

module OAuth2::Provider::Rack
  class ResourceRequest < Rack::Request
    include Responses

    delegate :has_scope?, :to => :authorization

    def token
      token_from_param || token_from_header
    end

    def has_token?
      !token.nil?
    end

    def token_from_param
      params["oauth_token"]
    end

    def token_from_header
      if authorization_header.provided?
        authorization_header.params
      end
    end

    def authorization_header
      @authorization_header ||= Rack::Auth::AbstractRequest.new(env)
    end

    def authenticate_request!(options, &block)
      if authenticated?
        if options[:scope].nil? || has_scope?(options[:scope])
          yield
        else
          insufficient_scope!
        end
      else
        authentication_required!
      end
    end

    def authorization
      validate_token!
      @authorization
    end

    def authenticated?
      authorization.present?
    end

    def resource_owner
      authorization && authorization.resource_owner
    end

    def validate_token!
      if has_token? && @token_validated.nil?
        @token_validated = true
        block_invalid_request
        block_invalid_token
      end
    end

    def block_invalid_request
      if token_from_param && token_from_header && (token_from_param != token_from_header)
        invalid_request! 'both authorization header and oauth_token provided, with conflicting tokens'
      end
    end

    def block_invalid_token
      access_token = OAuth2::Provider.access_token_class.find_by_access_token(token)
      @authorization = access_token.authorization if access_token
      authentication_required! 'invalid_token' if access_token.nil? || access_token.expired?
    end
  end
end