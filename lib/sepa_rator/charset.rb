# frozen_string_literal: true

module SEPA
  # Out-of-repertoire characters follow EPC217-08: §6.2 replacements, then
  # one-to-one transliteration, else dropped.
  class Charset
    CONTROL_SPACES = /[\r\n\t]+/
    CONTROLS = /[\x00-\x1F\x7F]/
    MARKS = /\p{Mn}/

    EPC_REPLACEMENTS = { '€' => 'E', '@' => '(at)', '_' => '-', '&' => '+', "\u00A0" => ' ' }.freeze

    TRANSLITERATIONS = {
      'ß' => 's', 'Æ' => 'A', 'æ' => 'a', 'Œ' => 'O', 'œ' => 'o', 'Ø' => 'O', 'ø' => 'o',
      'Ł' => 'L', 'ł' => 'l', 'Đ' => 'D', 'đ' => 'd', 'Þ' => 'T', 'þ' => 't', 'Ð' => 'D', 'ð' => 'd', 'ı' => 'i'
    }.freeze

    IDENTIFIER_BODY = "A-Za-z0-9+?/:().,' -"
    EPC_BODY = "A-Za-z0-9/?:().,'+ -"
    DK_BODY = "ÄäÖöÜüß&*$%#{EPC_BODY}".freeze
    AT_BODY = %q{A-Za-z0-9+/?:().,'äöüßÄÖÜ&><"|€$§%!=#~;*{}\[\]@\\\\_°\^ -}
    SPS_BODY = "\u0020-\u007E\u00A0-\u00AC\u00AE-\u017F\u0218-\u021B\u20AC"

    class Alphabet
      def initialize(body)
        @accepted = /\A[#{body}]*\z/
        @rejected = /[^#{body}]/
        freeze
      end

      def fit(value)
        return value if value.match?(@accepted)

        value.gsub(@rejected) { |char| replacement(char) }.strip
      end

      private

      def replacement(char)
        [EPC_REPLACEMENTS[char], TRANSLITERATIONS[char]].find { |candidate| candidate&.match?(@accepted) } ||
          char.unicode_normalize(:nfd).gsub(MARKS, '').then { |base| base.match?(@accepted) ? base : '' }
      end
    end
    private_constant :Alphabet

    attr_reader :id

    def self.sanitize(value)
      return if value.nil?

      value.to_s
           .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
           .scrub('')
           .gsub(CONTROL_SPACES, ' ')
           .gsub(CONTROLS, '')
           .strip
    end

    def initialize(charset_id, text_body)
      @id = charset_id
      @text = text_body && Alphabet.new(text_body)
      @identifier = text_body && Alphabet.new(IDENTIFIER_BODY)
      freeze
    end

    def text(value)
      fit(@text, value)
    end

    def identifier(value)
      fit(@identifier, value)
    end

    ISO = new(:iso, nil)
    EPC = new(:epc, EPC_BODY)
    DK = new(:dk, DK_BODY)
    AT = new(:at, AT_BODY)
    SPS = new(:sps, SPS_BODY)

    private

    def fit(alphabet, value)
      sanitized = self.class.sanitize(value)
      alphabet && sanitized ? alphabet.fit(sanitized) : sanitized
    end
  end
end
