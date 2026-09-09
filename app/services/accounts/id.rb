# frozen_string_literal: true

require "base64"

module Accounts
  # URL-safe encode/decode for BoA account numbers that may contain spaces.
  module Id
    class Error < StandardError; end

    module_function

    def encode(account_number)
      raise Error, "account_number required" if account_number.blank?

      Base64.urlsafe_encode64(account_number.to_s, padding: false)
    end

    def decode(token)
      raise Error, "account id required" if token.blank?

      Base64.urlsafe_decode64(token.to_s)
    rescue ArgumentError
      raise Error, "Invalid account id"
    end

    def normalize(account_number)
      account_number.to_s.gsub(/\s+/, "")
    end
  end
end
