class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)

  apb_slv_driver    drv;

  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = apb_slv_driver::type_id::create("drv", this);
  endfunction

endclass
