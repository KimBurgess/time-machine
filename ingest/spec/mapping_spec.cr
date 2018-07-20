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
    }, value["value"], time)[0]

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
    }, value["value"], time)[0]

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
    }, value["value"], time)[0]

    point_value.to_s.should eq(
      "input,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=\"value\" #{time.epoch_ms}"
    )

    # check values updates
    value = JSON.parse("{\"value\": {\"sub\": {\"key\": \"other\"}}}")
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)[0]

    m.previous_value.should eq("other")
    point_value.to_s.should eq(
      "input,building=zone-1234,level=zone-4567,bookable=true,class=Display " +
      "capacity=45,index=1,system=\"sys-1234\",value=\"other\" #{time.epoch_ms}"
    )

    # check value doesn't change
    point_value = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["value"], time)[0]?

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
    }, value["value"], time)[0]?

    point_value.should eq(nil)
  end

  it "should work with array values" do
    value = JSON.parse("{\"level1\": [\"desk1\",\"desk2\",\"desk3\"]}")

    m = Mapping.new(
      system: "sys-1234",
      driver: "DeskManager",
      state: "level1",
      key: nil,
      bookable: true,
      capacity: nil,
      index: 1
    )

    time = Time.now
    point_values = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["level1"], time)

    point_values.size.should eq(3)
    point_values[0].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk1\",value=true #{time.epoch_ms}"
    )

    point_values[1].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk2\",value=true #{time.epoch_ms}"
    )

    # Update the array, removing a value
    value = JSON.parse("{\"level1\": [\"desk1\",\"desk2\"]}")
    time = Time.now
    point_values = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["level1"], time)

    point_values.size.should eq(1)
    point_values[0].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk3\",value=false #{time.epoch_ms}"
    )

    # Update the array, adding a value
    value = JSON.parse("{\"level1\": [\"desk1\",\"desk2\",\"desk5\"]}")
    time = Time.now
    point_values = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["level1"], time)

    point_values.size.should eq(1)
    point_values[0].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk5\",value=true #{time.epoch_ms}"
    )

    # Update the array, adding and removing a value
    value = JSON.parse("{\"level1\": [\"desk1\",\"desk2\",\"desk4\"]}")
    time = Time.now
    point_values = m.update(InfluxDB::Tags{
      "building" => "zone-1234",
      "level" => "zone-4567",
    }, value["level1"], time)

    point_values.size.should eq(2)
    point_values[0].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk4\",value=true #{time.epoch_ms}"
    )
    point_values[1].to_s.should eq(
      "level1,building=zone-1234,level=zone-4567,bookable=true,class=DeskManager " +
      "index=1,system=\"sys-1234\",term=\"desk5\",value=false #{time.epoch_ms}"
    )
  end
end
