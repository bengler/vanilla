module Vanilla
  module Utils

    # Fix bad Unicode strings.
    def self.fix_encoding(value)
      case value
        when Hash
          Hash[*value.stringify_keys.entries.flat_map { |key, value|
            [fix_encoding(key.to_s), fix_encoding(value)]
          }]
        when String
          if value.respond_to?(:valid_encoding?) and not value.valid_encoding?
            value.encode('utf-8', 'binary', undef: :replace)
          else
            value
          end
        when Array
          value.map { |v| fix_encoding(v) }
        else
          value
      end
    end

  end
end