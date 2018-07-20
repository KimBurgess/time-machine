require "json/any"

# Design document:
# https://docs.google.com/document/d/1qEofwXg0LTWVCWUA38YY2hLPKm7aMzpJhr6lFR_y4UU/edit?usp=sharing

class Mapping
  getter subkey : Array(String)?
  getter previous_value : Bool | Float64 | Int64 | String | Array(String) | Nil

  def initialize(@system : String, @driver : String, @state : String, key : String?, @bookable : Bool?, @capacity : Int32?, @index : Int32)
    @previous_value = nil
    if key && !key.empty?
      @subkey = key.split(".")
    end
  end

  def update(tags : InfluxDB::Tags, value : JSON::Any, timestamp : Time) : Array(InfluxDB::PointValue)
    # Grab the sub key value as required
    if subkey = @subkey
      begin
        subkey.each { |key| value = value[key] }
      rescue
        # Don't write value if subkey doesn't exist
        return [] of InfluxDB::PointValue
      end
    end

    # Ignore unacceptable values and re-cast
    check = value.raw
    case check
    when Bool
      value = value.as_bool
    when Float64
      value = value.as_f
    when Int64
      value = value.as_i64
    when String
      value = value.as_s
    when Array(JSON::Any)
      # Holy shit crystal lang type system is awesome.
      value = value.as_a.map(&.to_s)
    else
      return [] of InfluxDB::PointValue
    end

    previous = @previous_value
    return [] of InfluxDB::PointValue if previous == value
    @previous_value = value

    # Create the tags list
    tags["bookable"] = !!@bookable
    tags["class"] = @driver

    # Create the fields list
    fields = InfluxDB::Fields.new
    capacity = @capacity
    fields["capacity"] = capacity if capacity
    fields["index"] = @index
    fields["system"] = @system

    # Treat the existance of values in the array as booleans
    if value.is_a?(Array(String))
      values = {} of String => Bool

      if previous.is_a?(Array(String))
        # new entries
        value.reject { |s| previous.includes?(s) }.each { |s| values[s] = true }

        # removed entries
        previous.reject { |s| value.includes?(s) }.each { |s| values[s] = false }
      else
        # all values are true if there are no previous
        value.each { |s| values[s] = true }
      end

      values.map do |value, exists|
        fields = fields.dup
        fields["term"] = value
        fields["value"] = exists
        InfluxDB::PointValue.new @state, fields, tags, timestamp
      end
    else
      fields["value"] = value
      [InfluxDB::PointValue.new(@state, fields, tags, timestamp)]
    end
  end
end

class Binding
  def initialize(@system : String, @driver : String, @index : Int32, @state : String, @bookable : Bool?, @capacity : Int32?)
    @mappings = {} of String => Mapping
  end

  def store(driver, state, key)
    lookup = (key && !key.empty?) ? "#{driver}.#{state}.#{key}" : "#{driver}.#{state}"
    @mappings[lookup] ||= Mapping.new(@system, driver, state, key, @bookable, @capacity, @index)
  end

  def bind_request(id : Int32)
    {
      id:    id,
      cmd:   "bind",
      sys:   @system,
      mod:   @driver,
      index: @index,
      name:  @state,
    }
  end

  def unbind_request(id : Int32)
    {
      id:    id,
      cmd:   "unbind",
      sys:   @system,
      mod:   @driver,
      index: @index,
      name:  @state,
    }
  end

  def to_s
    "#{@system}[#{@driver}_#{@index}].#{@state}\n\t#{@mappings.keys.join("\n\t")}"
  end

  # returns an array of updates to be pushed to the database
  # tags here
  def update(tags : InfluxDB::Tags, value : JSON::Any, timestamp : Time)
    updates = [] of InfluxDB::PointValue
    @mappings.values.each { |mapping|
      updates.concat(mapping.update(tags, value, timestamp))
    }
    updates
  end
end

class Binder
  def initialize
    @bindings = {} of String => Binding

    # system_id => zone tags
    @tags = {} of String => InfluxDB::Tags
  end

  def bind_to(bookable, capacity, system, driver, index, state, key = nil, driver_alias = nil, state_alias = nil)
    # Grab or create the binding
    lookup = "#{system}\e#{driver}\e#{index}\e#{state}"
    binding = @bindings[lookup] ||= Binding.new(system, driver, index, state, bookable, capacity)

    # Store the mapping
    binding.store(driver_alias || driver, state_alias || state, key)
  end

  def bindings
    @bindings.values
  end

  def []=(system, tags)
    @tags[system] = tags
  end

  def [](system)
    # NOTE:: we .dup these tags for calling Binding#update
    # as Binding#update will modify the hash
    @tags[system].dup
  end
end
