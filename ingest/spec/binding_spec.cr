require "./spec_helper"

describe Binding do
  it "should be able to store a binding and generate requests" do
    b = Binding.new(
      system: "sys-1234",
      driver: "Display",
      state: "power",
      bookable: true,
      capacity: 45,
      index: 1
    )

    bind = b.bind_request(2)
    bind.should eq({
      id:    2,
      cmd:   "bind",
      sys:   "sys-1234",
      mod:   "Display",
      index: 1,
      name:  "power",
    })

    unbind = b.unbind_request(3)
    unbind.should eq({
      id:    3,
      cmd:   "unbind",
      sys:   "sys-1234",
      mod:   "Display",
      index: 1,
      name:  "power",
    })
  end

  it "should be able to store mappings" do
    b = Binding.new(
      system: "sys-1234",
      driver: "Display",
      state: "power",
      bookable: true,
      capacity: 45,
      index: 1
    )

    b.store("Display", "power", nil)
    b.store("Projector", "state", nil)
    b.store("Display", "power", nil)

    value = JSON.parse("{\"value\": 67}")
    time = Time.now
    point_values = b.update(InfluxDB::Tags.new, value["value"], time)

    point_values.size.should eq(2)
    point_values[0].to_s.should eq("power,bookable=true,class=Projector capacity=45,index=1,system=\"sys-1234\",value=67 #{time.epoch_ms}")
    point_values[1].to_s.should eq("state,bookable=true,class=Projector capacity=45,index=1,system=\"sys-1234\",value=67 #{time.epoch_ms}")
  end

  it "should print mappings for debugging" do
    b = Binding.new(
      system: "sys-1234",
      driver: "Display",
      state: "power",
      bookable: true,
      capacity: 45,
      index: 1
    )

    b.store("Display", "power", nil)
    b.store("Projector", "state", "")
    b.store("Display", "power", "with.sub.key")

    b.to_s.should eq("sys-1234[Display_1].power\n\tDisplay.power\n\tProjector.state\n\tDisplay.power.with.sub.key")
  end
end
