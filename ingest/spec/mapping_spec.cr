require "./spec_helper"

describe Mapping do
  it "should be able to store basic binding mappings" do
    value = JSON.parse("{\"value\": 67}")

    m = Mapping.new(
      system: "sys-1234",
      driver: "Display",
      state: "power",
      key: nil,
      bookable: true,
      capacity: 45,
      index: 1
    )

    m.subkey.should eq(nil)
    m.previous_value.should eq(nil)

    time = Time.now
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    m.subkey.should eq(nil)
    m.previous_value.should eq(67)

    point_value.to_s.should eq(
      "power,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=67 #{time.epoch_ms}"
    )
  end

  it "should be able to store complex binding mappings" do
    value = JSON.parse("{\"value\": {\"sub\": {\"key\": \"value\"}}}")

    m = Mapping.new(
      system: "sys-1234",
      driver: "Display",
      state: "input",
      key: "sub.key",
      bookable: true,
      capacity: 45,
      index: 1
    )

    m.subkey.should eq(["sub", "key"])
    m.previous_value.should eq(nil)

    time = Time.now
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    m.subkey.should eq(["sub", "key"])
    m.previous_value.should eq("value")

    point_value.to_s.should eq(
      "input,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=\"value\" #{time.epoch_ms}"
    )
  end

  it "should update values" do
    value = JSON.parse("{\"value\": {\"sub\": {\"key\": \"value\"}}}")

    m = Mapping.new(
      system: "sys-1234",
      driver: "Display",
      state: "input",
      key: "sub.key",
      bookable: true,
      capacity: 45,
      index: 1
    )

    time = Time.now
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    point_value.to_s.should eq(
      "input,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=\"value\" #{time.epoch_ms}"
    )

    # check values updates
    value = JSON.parse("{\"value\": {\"sub\": {\"key\": \"other\"}}}")
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    m.previous_value.should eq("other")
    point_value.to_s.should eq(
      "input,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=\"other\" #{time.epoch_ms}"
    )

    # check value doesn't change
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    point_value.should eq(nil)
  end

  it "should not fail when subkey isn't available" do
    value = JSON.parse("{\"value\": {\"sub\": null}}")

    m = Mapping.new(
      system: "sys-1234",
      driver: "Display",
      state: "input",
      key: "sub.key",
      bookable: true,
      capacity: 45,
      index: 1
    )

    time = Time.now
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)

    point_value.should eq(nil)
  end
end
