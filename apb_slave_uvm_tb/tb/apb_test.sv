//   It is responsible for:

// The test class constructs the verification environment, configures test
// parameters, and triggers the transaction sequence on the sequencer.
class apb_test extends uvm_test;

  `uvm_component_utils(apb_test)

  apb_env env;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_test", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

    // Run Phase: main simulation execution loop handling active driving or passive monitoring
  task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "  APB Slave UVM Test Starting", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)

    #100;

    begin
      apb_write_read_seq seq;
      seq = apb_write_read_seq::type_id::create("seq");
      seq.start(env.agent.sqr);
    end

    #100;

    `uvm_info("TEST", "========================================", UVM_LOW)
    `uvm_info("TEST", "  APB Slave UVM Test Complete", UVM_LOW)
    `uvm_info("TEST", "========================================", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass
