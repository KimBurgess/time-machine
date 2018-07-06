require "json/any"

# Design document:
# https://docs.google.com/document/d/1qEofwXg0LTWVCWUA38YY2hLPKm7aMzpJhr6lFR_y4UU/edit?usp=sharing

class Mapping
  getter subkey : Array(String)?
  getter previous_value : JSON::Any::Type

  def initialize(@system : String, @driver : String, @state : String, key : String?, @bookable : Bool, @capacity : Int32, @index : Int32)
    @previous_value = nil
    if key && !key.empty?
      @subkey = key.split(".")
    end
  end

  def update(tags : InfluxDB::Tags, value : JSON::Any, timestamp : Time)
    # Grab the sub key value as required
    if subkey = @subkey
      begin
        subkey.each { |key| value = value[key] }
      rescue
        # Don't write value if subkey doesn't exist
        return
      end
    end

    # Ignore unacceptable values
    value = value.raw
    case value
    when Array(JSON::Any), Hash(String, JSON::Any), Nil
      return
    end

    return if @previous_value == value
    @previous_value = value

    # Create the tags list
    tags["bookable"] = @bookable
    tags["class"] = @driver

    # Create the fields list
    fields = InfluxDB::Fields{
      "capacity" => @capacity,
      "index"    => @index,
      "system"   => @system,
      "value"    => value,
    }

    InfluxDB::PointValue @state, fields, tags, timestamp
  end
end

class Binding
  def initialize(@system : String, @driver : String, @index : Int32, @state : String, @bookable : Bool, @capacity : Int32)
    @mappings = {} of String => Mapping
  end

  def store(driver, state, key)
    lookup = "#{driver}\e#{state}\e#{key}"
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

  # returns an array of updates to be pushed to the database
  # tags here
  def update(tags : InfluxDB::Tags, value : JSON::Any, timestamp : Time)
    @mappings.values.collect { |mapping|
      mapping.update(tags, value, timestamp)
    }.compact
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

  def set_tags(system, tags)
    @tags[system] = tags
  end

  def get_tags(system)
    # NOTE:: remember to .dup these tags before calling Binding#update
    @tags[system]
  end
end
