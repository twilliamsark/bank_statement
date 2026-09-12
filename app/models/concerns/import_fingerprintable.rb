# frozen_string_literal: true

module ImportFingerprintable
  extend ActiveSupport::Concern

  class_methods do
    def import_fingerprint_for(date:, description:, amount_cents:)
      payload = [ date.to_s, description.to_s[0, 21], amount_cents.to_i ].join("|")
      Digest::MD5.hexdigest(payload)
    end

    def category_match_prefix(description)
      description.to_s[0, 21]
    end
  end

  included do
    before_validation :assign_import_fingerprint, if: -> { import_fingerprint.blank? }
  end

  private

  def assign_import_fingerprint
    return if date.blank? || description.blank? || amount_cents.nil?

    self.import_fingerprint = self.class.import_fingerprint_for(
      date: date,
      description: description,
      amount_cents: amount_cents
    )
  end
end
