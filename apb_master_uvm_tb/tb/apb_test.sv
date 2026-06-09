// The test class constructs the verification environment, configures test
// parameters, and triggers the transaction sequence on the sequencer.
class test_apb_base extends uvm_test;

  `uvm_component_utils(test_apb_base)

  apb_env env;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "test_apb_base", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

endclass

class apb_master_test extends test_apb_base;

  `uvm_component_utils(apb_master_test)

  function new(string name = "apb_master_test", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Run Phase: main simulation execution loop handling active driving or passive monitoring
  task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    #100ns;

    seq = apb_write_read_seq::type_id::create("seq");
    seq.start(env.sys_agent.sqr);

    #100ns;

    `uvm_info("TEST", "================================================", UVM_LOW)
    `uvm_info("TEST", "  APB Master Bridge UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "================================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass
