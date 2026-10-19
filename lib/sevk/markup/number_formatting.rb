# frozen_string_literal: true

module Sevk
  module Markup
    module NumberFormatting
      def js_number(value)
        return '0' if value.zero?
        return value.to_s unless value.finite?

        digits, point = decimal_digits(value.abs)
        text = if point.between?(digits.length, 21)
                 digits + ('0' * (point - digits.length))
               elsif point.positive? && point <= 21
                 "#{digits[0...point]}.#{digits[point..]}"
               elsif point > -6 && point <= 0
                 "0.#{'0' * -point}#{digits}"
               else
                 exponent_notation(digits, point - 1)
               end
        value.negative? ? "-#{text}" : text
      end

      private

      def decimal_digits(magnitude)
        mantissa, exponent = magnitude.to_s.split('e')
        integer_part, fraction_part = mantissa.split('.')
        digits = integer_part + fraction_part.to_s.sub(/0+\z/, '')
        leading_zeros = digits[/\A0*/].length
        [digits[leading_zeros..], integer_part.length + exponent.to_i - leading_zeros]
      end

      def exponent_notation(digits, power)
        sign = power.negative? ? '-' : '+'
        mantissa = digits.length == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
        "#{mantissa}e#{sign}#{power.abs}"
      end
    end
  end
end
