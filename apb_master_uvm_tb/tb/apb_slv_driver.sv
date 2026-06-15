`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_slv_driver)

  virtual apb_if vif;
  protected bit [7:0] slave_mem [bit [8:0]];

  function new(string name = "apb_slv_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    `uvm_info("SLV_DRV", "run_phase started, waiting for reset release...", UVM_LOW)
    wait(vif.PRESETn === 1'b1);
    `uvm_info("SLV_DRV", "Reset released, initializing signals...", UVM_LOW)

    @(vif.slave_cb);
    vif.slave_cb.PREADY <= 1'b0;
    vif.slave_cb.PRDATA <= 8'h00;

    forever begin
      @(vif.slave_cb);

      // DEBUG: print what slv_driver sees every cycle
      `uvm_info("SLV_DRV", $sformatf("CYCLE: PSEL1=%0b PSEL2=%0b PENABLE=%0b PSLVERR=%0b",
                vif.slave_cb.PSEL1, vif.slave_cb.PSEL2, vif.slave_cb.PENABLE, vif.PSLVERR), UVM_LOW)

      if (vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) begin

        // ---- SETUP PHASE ----
        if (!vif.slave_cb.PENABLE) begin
          `uvm_info("SLV_DRV", "======== DUT Signals Received (SETUP Phase) ========", UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PADDR   = 0x%03h", vif.slave_cb.PADDR),   UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PWDATA  = 0x%02h", vif.slave_cb.PWDATA),   UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PWRITE  = %0b",    vif.slave_cb.PWRITE),   UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PSEL1   = %0b",    vif.slave_cb.PSEL1),    UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PSEL2   = %0b",    vif.slave_cb.PSEL2),    UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PENABLE = %0b (expected 0 in SETUP)", vif.slave_cb.PENABLE), UVM_LOW)
          `uvm_info("SLV_DRV", "====================================================", UVM_LOW)

          vif.slave_cb.PREADY <= 1'b1;  // Must assert PREADY or handshake hangs

          if (!vif.slave_cb.PWRITE) begin
            if (slave_mem.exists(vif.slave_cb.PADDR))
              vif.slave_cb.PRDATA <= slave_mem[vif.slave_cb.PADDR];
            else
              vif.slave_cb.PRDATA <= vif.slave_cb.PADDR[7:0] ^ 8'hA5;
          end
        end

        // ---- ACCESS PHASE ----
        else if (vif.slave_cb.PENABLE && vif.PREADY) begin
          `uvm_info("SLV_DRV", "======== DUT Signals Received (ACCESS Phase) =======", UVM_LOW)
          `uvm_info("SLV_DRV", $sformatf("  PENABLE = %0b, PREADY = %0b --> Handshake Complete!", vif.slave_cb.PENABLE, vif.PREADY), UVM_LOW)
          `uvm_info("SLV_DRV", "====================================================", UVM_LOW)

          if (vif.slave_cb.PWRITE)
            slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA;

          vif.slave_cb.PREADY <= 1'b0;
        end
      end
      else begin
        vif.slave_cb.PREADY <= 1'b0;
      end
    end
  endtask

endclass
