# frozen_string_literal: true

module FEEL
  class SerializationError < ArgumentError; end

  #
  # Conversion of FEEL values (results of FEEL.evaluate, variables) to JSON.
  #
  # `as_json` gives plain JSON (temporal values as ISO 8601 strings, like the
  # FEEL function `to json()`). The types of the values are lost.
  #
  # `serialize` / `deserialize` keep the types: values that JSON can't
  # represent are tagged with the key "$feel", e.g.
  #
  #   { "$feel" => "date", "value" => "2020-01-01" }
  #   { "$feel" => "date and time", "value" => "2020-01-01T10:30:00@Europe/Berlin" }
  #   { "$feel" => "duration", "value" => "P1DT2H" }
  #
  # so that `deserialize(serialize(value)) == value`. A context that contains
  # the key "$feel" itself is escaped as { "$feel" => "context", "value" => ... }.
  #
  module Serialization
    TAG = "$feel"

    module_function

    # A JSON-compatible structure of the value with ISO 8601 temporal values.
    def as_json(value)
      Builtins::ConversionFormat.to_json_value(Numbers.normalize(value))
    end

    # A JSON-compatible structure of the value that keeps the FEEL types.
    def serialize(value)
      value = Temporal.normalize(value)
      case value
      when nil, true, false, String, Integer then value
      when Float, BigDecimal, Rational
        number = Numbers.normalize(value)
        raise SerializationError, "can't serialize the number #{value}" if number.nil?

        number
      when Array then value.map { |item| serialize(item) }
      when Hash, Scope then serialize_context(value)
      when ZonedTime
        tagged = { TAG => "time", "value" => value.iso8601 }
        value.zone ? tagged.merge("zone" => value.zone) : tagged
      when Time
        tagged = { TAG => "date and time", "value" => Temporal.format_value(value) }
        # the offset selects the instant of a local time that exists twice in
        # the zone (at the end of the daylight saving time)
        Temporal.zoned?(value) ? tagged.merge("offset" => Temporal.format_offset(value.utc_offset)) : tagged
      when Date, LocalTime, LocalDateTime, Duration
        { TAG => type_name(value), "value" => Temporal.format_value(value) }
      when FEEL::Range then serialize_range(value)
      else
        raise SerializationError, "can't serialize #{value.inspect} (#{value.class})"
      end
    end

    # The value of a serialized structure (or of its JSON string) with the
    # FEEL types restored.
    def deserialize(data)
      data = JSON.parse(data) if data.is_a?(String)
      restore(data)
    end

    def restore(data)
      case data
      when Array then data.map { |item| restore(item) }
      when Hash
        data.key?(TAG) ? restore_tagged(data) : data.to_h { |key, item| [key.to_s, restore(item)] }
      else data
      end
    end

    def serialize_context(context)
      result = context.to_h.to_h { |key, item| [key.to_s, serialize(item)] }
      result.key?(TAG) ? { TAG => "context", "value" => result } : result
    end

    def serialize_range(range)
      {
        TAG => "range",
        "start" => serialize(range.start),
        "end" => serialize(range.end),
        "start included" => range.start_included,
        "end included" => range.end_included,
      }
    end

    def type_name(value)
      case value
      when Date then value.is_a?(DateTime) ? "date and time" : "date"
      when LocalTime, ZonedTime then "time"
      when LocalDateTime, Time then "date and time"
      when Duration then "duration"
      end
    end

    def restore_tagged(data)
      type = data[TAG]
      text = data["value"]
      value = case type
      when "context" then return data["value"].to_h { |key, item| [key.to_s, restore(item)] }
      when "range" then return restore_range(data)
      when "date" then Temporal.parse_date(text)
      when "time" then restore_time(text, data["zone"])
      when "date and time" then restore_date_time(text, data["offset"])
      when "duration" then Temporal.parse_duration(text)
      else raise SerializationError, "unknown #{TAG} type: #{type.inspect}"
      end
      raise SerializationError, "invalid #{type}: #{text.inspect}" if value.nil?

      value
    end

    def restore_time(text, zone)
      time = Temporal.parse_time(text)
      zone && time.is_a?(ZonedTime) ? ZonedTime.new(time.local_time, time.offset, zone) : time
    end

    def restore_date_time(text, offset)
      time = Temporal.parse_date_time(text)
      return time unless offset && Temporal.zoned?(time)

      offset = Temporal.parse_offset(offset)
      return time if time.utc_offset == offset

      fields = [time.year, time.month, time.day, time.hour, time.min, time.sec + time.subsec]
      Temporal.offset_time(*fields, offset).getlocal(time.zone)
    end

    def restore_range(data)
      range = FEEL::Range.build(restore(data["start"]), restore(data["end"]), data["start included"], data["end included"])
      raise SerializationError, "invalid range: #{data.inspect}" if range.nil?

      range
    end
  end

  # A JSON-compatible structure of a FEEL value (e.g. a result of
  # FEEL.evaluate) with temporal values as ISO 8601 strings. The types are
  # lost; use FEEL.serialize to keep them.
  def self.as_json(value)
    Serialization.as_json(value)
  end

  # The JSON string of a FEEL value with temporal values as ISO 8601 strings.
  def self.to_json(value)
    JSON.generate(as_json(value))
  end

  # A JSON-compatible structure of a FEEL value that keeps its types (see
  # FEEL::Serialization). Raises FEEL::SerializationError for values that
  # can't be serialized (e.g. functions).
  def self.serialize(value)
    Serialization.serialize(value)
  end

  # Restores a value serialized with FEEL.serialize (the structure or its
  # JSON string). The result can be passed as variables to FEEL.evaluate.
  def self.deserialize(data)
    Serialization.deserialize(data)
  end
end
