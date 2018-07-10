require "./spec_helper"

describe Binder do
  it "should be able to store bindings" do
    b = Binder.new
    b.bind_to(
      bookable: true,
      capacity: 12,
      system: "sys-test-123",
      driver: "Display",
      index: 1,
      state: "power"
    )
    binds = b.bindings
    binds.size.should eq(1)
    binds[0].to_s.should eq("sys-test-123[Display_1].power\n\tDisplay.power")

    b.bind_to(
      bookable: true,
      capacity: 12,
      system: "sys-test-123",
      driver: "Display",
      index: 1,
      state: "power",
      state_alias: "online"
    )
    binds = b.bindings
    binds.size.should eq(1)
    binds[0].to_s.should eq("sys-test-123[Display_1].power\n\tDisplay.power\n\tDisplay.online")

    b.bind_to(
      bookable: true,
      capacity: 12,
      system: "sys-test-123",
      driver: "Display",
      index: 2,
      state: "power",
      state_alias: "online"
    )
    binds = b.bindings
    binds.size.should eq(2)
    binds[1].to_s.should eq("sys-test-123[Display_2].power\n\tDisplay.online")
  end
end
