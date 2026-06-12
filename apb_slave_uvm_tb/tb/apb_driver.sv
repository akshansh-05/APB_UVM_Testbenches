`include "uvm_macros.svh"
import uvm_pkg::*;

//     - Assert PSEL = 1
//     - Drive PADDR, PWDATA, PWRITE
//     - Keep PENABLE = 0
//   Cycle 2 (ACCESS phase):
//     - Assert PENABLE = 1

// The driver converts sequence items into APB signal wiggles (Setup and Access phases)
// to exercise the Slave DUT.
class apb_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_driver)

  virtual apb_if.driver vif;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

    // Run Phase: main simulation execution loop handling active driving or passive monitoring
  task run_phase(uvm_phase phase);

    vif.driver_cb.PSEL    <= 0;
    vif.driver_cb.PENABLE <= 0;
    vif.driver_cb.PADDR   <= 0;
    vif.driver_cb.PWDATA  <= 0;
    vif.driver_cb.PWRITE  <= 0;

    forever begin // Infinite loop to fetch items as long as sequences are running
      apb_seq_item item;

      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM)

      // APB Protocol Phase Transitions:
      // 1. SETUP Phase: Assert PSEL, drive address/controls, keep PENABLE low.
      @(vif.driver_cb);
      vif.driver_cb.PSEL    <= 1;
      vif.driver_cb.PENABLE <= 0;
      vif.driver_cb.PADDR   <= item.addr;
      vif.driver_cb.PWRITE  <= item.write;
      if (item.write)
        vif.driver_cb.PWDATA <= item.wdata;

      // 2. ACCESS Phase: Assert PENABLE high on the next clock cycle.
      @(vif.driver_cb);
      vif.driver_cb.PENABLE <= 1;

      // 3. Wait states: Loop and wait until PREADY is sampled high from the slave.
      @(vif.driver_cb);
      while (!vif.driver_cb.PREADY) begin
        @(vif.driver_cb);
      end

      if (!item.write) begin
        item.rdata = vif.driver_cb.PRDATA1;
      end

      vif.driver_cb.PSEL    <= 0;
      vif.driver_cb.PENABLE <= 0;

      seq_item_port.item_done();
    end
  endtask

endclass
