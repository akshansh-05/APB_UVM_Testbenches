//   It is responsible for:

class apb_test extends uvm_test;

  `uvm_component_utils(apb_test)

  apb_env env;

  function new(string name = "apb_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

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
