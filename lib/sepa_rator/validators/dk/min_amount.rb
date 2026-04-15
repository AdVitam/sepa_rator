# frozen_string_literal: true

module SEPA
  module Validators
    module DK
      # Alias to the shared MinAmount validator.  DK was the first profile to
      # require a minimum amount; the logic has been extracted to
      # `Validators::MinAmount` so AT (and future profiles) can reuse it.
      MinAmount = Validators::MinAmount
    end
  end
end
