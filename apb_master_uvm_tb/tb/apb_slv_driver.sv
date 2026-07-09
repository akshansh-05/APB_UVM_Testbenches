`include "uvm_macros.svh"
import uvm_pkg::*;

class slave_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(slave_driver)

  virtual apb_if vif;

  // Golden memory model, 9-bit address space
  logic [7:0] mem [logic [8:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Virtual interface not set for slave_driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();

    forever begin
      @(vif.slave_cb);

      // Always ready (zero-wait slave)
      vif.slave_cb.PREADY <= 1'b1;

      // Respond only when selected by the master
      if (vif.slave_cb.PSEL1 === 1'b1 || vif.slave_cb.PSEL2 === 1'b1) begin

        // ---- READ: drive PRDATA for the addressed location every cycle ----
        // Presented continuously so it is valid when ACCESS completes.
        if (vif.slave_cb.PWRITE === 1'b0) begin
          vif.slave_cb.PRDATA <= mem.exists(vif.slave_cb.PADDR) ?
                                 mem[vif.slave_cb.PADDR] : 8'h00;
        end

        // ---- WRITE: capture data at the completing edge ----
        if (vif.slave_cb.PWRITE  === 1'b1 &&
            vif.slave_cb.PENABLE === 1'b1 &&
            vif.slave_cb.PREADY  === 1'b1) begin
          mem[vif.slave_cb.PADDR] <= vif.slave_cb.PWDATA;
          `uvm_info("SLV_DRV",
            $sformatf("APB HANDSHAKE COMPLETE | WRITE addr=0x%0h data=0x%0h",
                      vif.slave_cb.PADDR, vif.slave_cb.PWDATA),
            UVM_MEDIUM)
        end

        // ---- READ completion log ----
        if (vif.slave_cb.PWRITE  === 1'b0 &&
            vif.slave_cb.PENABLE === 1'b1 &&
            vif.slave_cb.PREADY  === 1'b1) begin
          `uvm_info("SLV_DRV",
            $sformatf("APB HANDSHAKE COMPLETE | READ  addr=0x%0h data=0x%0h",
                      vif.slave_cb.PADDR,
                      mem.exists(vif.slave_cb.PADDR) ? mem[vif.slave_cb.PADDR] : 8'h00),
            UVM_MEDIUM)
        end
      end
    end
  endtask

  task reset_signals();
    vif.slave_cb.PREADY <= 1'b1;
    vif.slave_cb.PRDATA <= '0;
  endtask

endclass