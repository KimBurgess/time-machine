require "./spec_helper"

describe Binding do
  it "should be able to store a binding" do
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
  end
end
